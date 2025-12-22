library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdram_controller is
    Port (
        clk           : in    STD_LOGIC;
        reset         : in    STD_LOGIC;
        
        -- User Interface
        cmd_write     : in    STD_LOGIC;
        cmd_read      : in    STD_LOGIC;
        addr          : in    STD_LOGIC_VECTOR(7 downto 0);
        data_in       : in    STD_LOGIC_VECTOR(15 downto 0);
        data_out      : out   STD_LOGIC_VECTOR(15 downto 0);
        busy          : out   STD_LOGIC;
        ready         : out   STD_LOGIC;
        
        -- DDR SDRAM Interface
        ddr_clk       : out   STD_LOGIC;
        ddr_clk_n     : out   STD_LOGIC;
        ddr_cke       : out   STD_LOGIC;
        ddr_cs_n      : out   STD_LOGIC;
        ddr_ras_n     : out   STD_LOGIC;
        ddr_cas_n     : out   STD_LOGIC;
        ddr_we_n      : out   STD_LOGIC;
        ddr_ba        : out   STD_LOGIC_VECTOR(1 downto 0);
        ddr_addr      : out   STD_LOGIC_VECTOR(12 downto 0);
        ddr_dq        : inout STD_LOGIC_VECTOR(15 downto 0);
        ddr_dqs       : inout STD_LOGIC_VECTOR(1 downto 0);
        ddr_dm        : out   STD_LOGIC_VECTOR(1 downto 0)
    );
end sdram_controller;

architecture Behavioral of sdram_controller is

    -- State Machine States
    type state_type is (
        INIT_WAIT,        -- Wait 200us for power stabilization
        INIT_PRECHARGE,   -- Precharge all banks
        INIT_REFRESH1,    -- First auto refresh
        INIT_REFRESH2,    -- Second auto refresh
        INIT_MODE_REG,    -- Load mode register
        IDLE,             -- Ready for commands
        ACTIVATE,         -- Open row
        WRITE_CMD,        -- Write command
        WRITE_DATA,       -- Write data
        READ_CMD,         -- Read command
        READ_WAIT,        -- Wait for CAS latency
        READ_DATA,        -- Capture read data
        PRECHARGE_CMD,    -- Close row
        REFRESH_CMD       -- Auto refresh
    );
    
    signal state, next_state : state_type := INIT_WAIT;
    
    -- Timing Counters
    signal init_counter : unsigned(15 downto 0) := (others => '0');
    signal cmd_counter  : unsigned(3 downto 0) := (others => '0');
    signal refresh_counter : unsigned(11 downto 0) := (others => '0');
    
    -- Internal registers
    signal row_addr : STD_LOGIC_VECTOR(12 downto 0);
    signal col_addr : STD_LOGIC_VECTOR(9 downto 0);
    signal bank_addr : STD_LOGIC_VECTOR(1 downto 0);
    signal data_reg : STD_LOGIC_VECTOR(15 downto 0);
    signal read_data_reg : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Control signals
    signal ddr_cmd : STD_LOGIC_VECTOR(2 downto 0); -- RAS, CAS, WE
    signal dq_output_enable : STD_LOGIC := '0';
    signal dqs_output_enable : STD_LOGIC := '0';
    
    -- Constants for timing (at 50MHz, 1 cycle = 20ns)
    constant INIT_CYCLES : integer := 10000; -- 200us = 10000 cycles at 50MHz
    constant tRP : integer := 2;   -- Precharge to active (minimum 15ns)
    constant tRCD : integer := 2;  -- Active to read/write (minimum 15ns)
    constant tCAS : integer := 3;  -- CAS latency
    constant tWR : integer := 2;   -- Write recovery time
    constant REFRESH_INTERVAL : integer := 390; -- ~7.8us refresh interval

begin

    -- DDR Clock generation (same as system clock for simplicity)
    ddr_clk <= clk;
    ddr_clk_n <= not clk;
    
    -- Always enable clock
    ddr_cke <= '1';
    
    -- Chip select always active (single chip)
    ddr_cs_n <= '0';
    
    -- Command output
    ddr_ras_n <= ddr_cmd(2);
    ddr_cas_n <= ddr_cmd(1);
    ddr_we_n <= ddr_cmd(0);
    
    -- Data mask always disabled (write all bytes)
    ddr_dm <= "00";
    
    -- Status outputs
    busy <= '1' when (state /= IDLE) else '0';
    ready <= '1' when (state = IDLE) else '0';
    
    -- Address decomposition (simplified mapping)
    -- Using lower 8 bits: [7:0]
    -- Row = addr, Column = 0, Bank = 0
    row_addr <= "00000" & addr;
    col_addr <= (others => '0');
    bank_addr <= "00"; -- Always use Bank 0
    
    -------------------------------------------------------------------
    -- Bidirectional Data Bus Control
    -------------------------------------------------------------------
    ddr_dq <= data_reg when dq_output_enable = '1' else (others => 'Z');
    ddr_dqs <= "11" when dqs_output_enable = '1' else (others => 'Z');
    
    data_out <= read_data_reg;
    
    -------------------------------------------------------------------
    -- State Machine Process
    -------------------------------------------------------------------
    state_machine: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= INIT_WAIT;
                init_counter <= (others => '0');
                cmd_counter <= (others => '0');
                refresh_counter <= (others => '0');
                ddr_cmd <= "111"; -- DESELECT
                ddr_ba <= "00";
                ddr_addr <= (others => '0');
                dq_output_enable <= '0';
                dqs_output_enable <= '0';
                read_data_reg <= (others => '0');
            else
                -- Default: NOP command
                ddr_cmd <= "111";
                dq_output_enable <= '0';
                dqs_output_enable <= '0';
                
                case state is
                
                    -------------------------------------------------------------------
                    -- INITIALIZATION STATES
                    -------------------------------------------------------------------
                    when INIT_WAIT =>
                        -- Wait 200us for power and clock stabilization
                        if init_counter < INIT_CYCLES then
                            init_counter <= init_counter + 1;
                            ddr_cmd <= "111"; -- NOP
                        else
                            state <= INIT_PRECHARGE;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    when INIT_PRECHARGE =>
                        -- PRECHARGE ALL command
                        ddr_cmd <= "010"; -- RAS=0, CAS=1, WE=0
                        ddr_addr(10) <= '1'; -- A10=1 means precharge all banks
                        if cmd_counter < tRP then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= INIT_REFRESH1;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    when INIT_REFRESH1 =>
                        -- First AUTO REFRESH
                        ddr_cmd <= "001"; -- RAS=0, CAS=0, WE=1
                        if cmd_counter < 10 then -- tRFC
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= INIT_REFRESH2;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    when INIT_REFRESH2 =>
                        -- Second AUTO REFRESH
                        ddr_cmd <= "001"; -- RAS=0, CAS=0, WE=1
                        if cmd_counter < 10 then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= INIT_MODE_REG;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    when INIT_MODE_REG =>
                        -- LOAD MODE REGISTER
                        -- Mode: Burst Length=1, CAS Latency=3, Sequential
                        ddr_cmd <= "000"; -- RAS=0, CAS=0, WE=0
                        ddr_addr <= "0000000110000"; -- CL=3, BL=1
                        ddr_ba <= "00"; -- Mode register
                        if cmd_counter < 2 then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= IDLE;
                        end if;
                    
                    -------------------------------------------------------------------
                    -- IDLE STATE - Wait for commands
                    -------------------------------------------------------------------
                    when IDLE =>
                        -- Refresh counter
                        if refresh_counter < REFRESH_INTERVAL then
                            refresh_counter <= refresh_counter + 1;
                        else
                            state <= REFRESH_CMD;
                            refresh_counter <= (others => '0');
                            cmd_counter <= (others => '0');
                        end if;
                        
                        -- Check for user commands
                        if cmd_write = '1' then
                            state <= ACTIVATE;
                            cmd_counter <= (others => '0');
                            data_reg <= data_in;
                        elsif cmd_read = '1' then
                            state <= ACTIVATE;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    -------------------------------------------------------------------
                    -- ACTIVATE - Open row
                    -------------------------------------------------------------------
                    when ACTIVATE =>
                        if cmd_counter = 0 then
                            ddr_cmd <= "011"; -- ACTIVE: RAS=0, CAS=1, WE=1
                            ddr_addr <= row_addr;
                            ddr_ba <= bank_addr;
                            cmd_counter <= cmd_counter + 1;
                        elsif cmd_counter < tRCD then
                            cmd_counter <= cmd_counter + 1;
                        else
                            -- Check which operation was requested
                            if cmd_write = '1' then
                                state <= WRITE_CMD;
                            else
                                state <= READ_CMD;
                            end if;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    -------------------------------------------------------------------
                    -- WRITE Operation
                    -------------------------------------------------------------------
                    when WRITE_CMD =>
                        ddr_cmd <= "100"; -- WRITE: RAS=1, CAS=0, WE=0
                        ddr_addr <= "000" & col_addr;
                        ddr_ba <= bank_addr;
                        state <= WRITE_DATA;
                    
                    when WRITE_DATA =>
                        dq_output_enable <= '1';
                        dqs_output_enable <= '1';
                        if cmd_counter < tWR then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= PRECHARGE_CMD;
                            cmd_counter <= (others => '0');
                        end if;
                    
                    -------------------------------------------------------------------
                    -- READ Operation
                    -------------------------------------------------------------------
                    when READ_CMD =>
                        ddr_cmd <= "101"; -- READ: RAS=1, CAS=0, WE=1
                        ddr_addr <= "000" & col_addr;
                        ddr_ba <= bank_addr;
                        state <= READ_WAIT;
                        cmd_counter <= (others => '0');
                    
                    when READ_WAIT =>
                        -- Wait for CAS latency
                        if cmd_counter < tCAS then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= READ_DATA;
                        end if;
                    
                    when READ_DATA =>
                        -- Capture data from bus
                        read_data_reg <= ddr_dq;
                        state <= PRECHARGE_CMD;
                        cmd_counter <= (others => '0');
                    
                    -------------------------------------------------------------------
                    -- PRECHARGE - Close row
                    -------------------------------------------------------------------
                    when PRECHARGE_CMD =>
                        ddr_cmd <= "010"; -- PRECHARGE: RAS=0, CAS=1, WE=0
                        ddr_addr(10) <= '1'; -- Precharge all banks
                        if cmd_counter < tRP then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= IDLE;
                        end if;
                    
                    -------------------------------------------------------------------
                    -- REFRESH
                    -------------------------------------------------------------------
                    when REFRESH_CMD =>
                        ddr_cmd <= "001"; -- AUTO REFRESH: RAS=0, CAS=0, WE=1
                        if cmd_counter < 10 then
                            cmd_counter <= cmd_counter + 1;
                        else
                            state <= IDLE;
                        end if;
                    
                end case;
            end if;
        end if;
    end process;

end Behavioral;
