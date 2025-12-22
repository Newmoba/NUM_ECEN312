library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdram_test is
    Port (
        CLK_50MHZ : in STD_LOGIC;
        
        -- Switches (4-bit input)
        SW : in STD_LOGIC_VECTOR(3 downto 0);
        
        -- Buttons
        BTN_SOUTH : in STD_LOGIC;  -- Write button
        BTN_NORTH : in STD_LOGIC;  -- Read button
        
        -- LEDs (output display)
        LED : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- DDR SDRAM Interface
        SD_CK_P : out STD_LOGIC;
        SD_CK_N : out STD_LOGIC;
        SD_CKE : out STD_LOGIC;
        SD_CS : out STD_LOGIC;
        SD_RAS : out STD_LOGIC;
        SD_CAS : out STD_LOGIC;
        SD_WE : out STD_LOGIC;
        SD_BA : out STD_LOGIC_VECTOR(1 downto 0);
        SD_A : out STD_LOGIC_VECTOR(12 downto 0);
        SD_DQ : inout STD_LOGIC_VECTOR(15 downto 0);
        SD_UDM : out STD_LOGIC;
        SD_LDM : out STD_LOGIC;
        SD_UDQS : inout STD_LOGIC;
        SD_LDQS : inout STD_LOGIC
    );
end sdram_test;

architecture Behavioral of sdram_test is
    
    -- State machine
    type state_type is (INIT, IDLE, WRITE_CMD, WRITE_DATA, READ_CMD, READ_DATA, DISPLAY);
    signal state : state_type := INIT;
    
    -- Clock signals
    signal clk_sdram : STD_LOGIC;
    signal clk_counter : unsigned(1 downto 0) := (others => '0');
    
    -- Button edge detection
    signal btn_write_prev : STD_LOGIC := '0';
    signal btn_read_prev : STD_LOGIC := '0';
    signal write_trigger : STD_LOGIC := '0';
    signal read_trigger : STD_LOGIC := '0';
    
    -- Data storage
    signal data_to_write : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal data_read : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    
    -- SDRAM control signals
    signal init_counter : unsigned(15 downto 0) := (others => '0');
    signal cmd_counter : unsigned(7 downto 0) := (others => '0');
    signal init_done : STD_LOGIC := '0';
    
    -- DQ control
    signal dq_out : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal dq_oe : STD_LOGIC := '0';  -- Output enable
    
    -- SDRAM Commands
    constant CMD_NOP : STD_LOGIC_VECTOR(2 downto 0) := "111";
    constant CMD_ACTIVE : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant CMD_READ : STD_LOGIC_VECTOR(2 downto 0) := "101";
    constant CMD_WRITE : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant CMD_PRECHARGE : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant CMD_AUTO_REFRESH : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant CMD_LOAD_MODE : STD_LOGIC_VECTOR(2 downto 0) := "000";
    
    signal sdram_cmd : STD_LOGIC_VECTOR(2 downto 0) := CMD_NOP;

begin

    -- Generate SDRAM clock (25 MHz from 50 MHz)
    process(CLK_50MHZ)
    begin
        if rising_edge(CLK_50MHZ) then
            clk_counter <= clk_counter + 1;
        end if;
    end process;
    
    clk_sdram <= clk_counter(0);
    
    -- SDRAM differential clock outputs
    SD_CK_P <= clk_sdram;
    SD_CK_N <= not clk_sdram;
    
    -- Button edge detection
    process(CLK_50MHZ)
    begin
        if rising_edge(CLK_50MHZ) then
            btn_write_prev <= BTN_SOUTH;
            btn_read_prev <= BTN_NORTH;
            
            -- Detect rising edge
            if BTN_SOUTH = '1' and btn_write_prev = '0' then
                write_trigger <= '1';
                data_to_write <= SW;  -- Capture switch values
            else
                write_trigger <= '0';
            end if;
            
            if BTN_NORTH = '1' and btn_read_prev = '0' then
                read_trigger <= '1';
            else
                read_trigger <= '0';
            end if;
        end if;
    end process;
    
    -- Main SDRAM control state machine
    process(clk_sdram)
    begin
        if rising_edge(clk_sdram) then
            case state is
                when INIT =>
                    -- Simple initialization
                    LED <= "00000000";  -- All LEDs off during init
                    if init_counter < 10000 then
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_NOP;
                        SD_CKE <= '0';
                    elsif init_counter = 10000 then
                        SD_CKE <= '1';
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_PRECHARGE;
                        SD_A(10) <= '1';  -- All banks
                    elsif init_counter < 10010 then
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_NOP;
                    elsif init_counter = 10010 then
                        sdram_cmd <= CMD_AUTO_REFRESH;
                        init_counter <= init_counter + 1;
                    elsif init_counter < 10020 then
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_NOP;
                    elsif init_counter = 10020 then
                        sdram_cmd <= CMD_AUTO_REFRESH;
                        init_counter <= init_counter + 1;
                    elsif init_counter < 10030 then
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_NOP;
                    elsif init_counter = 10030 then
                        sdram_cmd <= CMD_LOAD_MODE;
                        SD_BA <= "00";
                        SD_A <= "0000000100000";  -- CAS=2, Burst=1
                        init_counter <= init_counter + 1;
                    elsif init_counter < 10040 then
                        init_counter <= init_counter + 1;
                        sdram_cmd <= CMD_NOP;
                    else
                        init_done <= '1';
                        state <= IDLE;
                        sdram_cmd <= CMD_NOP;
                    end if;
                    
                    dq_oe <= '0';
                    
                when IDLE =>
                    sdram_cmd <= CMD_NOP;
                    dq_oe <= '0';
                    
                    -- Keep LED state in IDLE
                    LED(4) <= '0';
                    LED(5) <= '0';
                    
                    if write_trigger = '1' then
                        state <= WRITE_CMD;
                        cmd_counter <= (others => '0');
                    elsif read_trigger = '1' then
                        state <= READ_CMD;
                        cmd_counter <= (others => '0');
                    end if;
                    
                when WRITE_CMD =>
                    -- Activate row
                    if cmd_counter = 0 then
                        sdram_cmd <= CMD_ACTIVE;
                        SD_BA <= "00";
                        SD_A <= "0000000000000";  -- Row 0
                        cmd_counter <= cmd_counter + 1;
                    elsif cmd_counter < 3 then
                        sdram_cmd <= CMD_NOP;
                        cmd_counter <= cmd_counter + 1;
                    else
                        state <= WRITE_DATA;
                        cmd_counter <= (others => '0');
                    end if;
                    
                when WRITE_DATA =>
                    if cmd_counter = 0 then
                        sdram_cmd <= CMD_WRITE;
                        SD_BA <= "00";
                        SD_A <= "0000000000000";  -- Column 0
                        dq_out <= "000000000000" & data_to_write;
                        dq_oe <= '1';
                        cmd_counter <= cmd_counter + 1;
                    elsif cmd_counter < 5 then
                        sdram_cmd <= CMD_NOP;
                        dq_oe <= '0';
                        cmd_counter <= cmd_counter + 1;
                    else
                        state <= IDLE;
                        LED(3 downto 0) <= data_to_write;  -- Show written data
                        LED(4) <= '0';
                        LED(5) <= '0';
                        LED(6) <= '0';
                        LED(7) <= '1';  -- Indicate write complete
                    end if;
                    
                when READ_CMD =>
                    -- Activate row
                    if cmd_counter = 0 then
                        sdram_cmd <= CMD_ACTIVE;
                        SD_BA <= "00";
                        SD_A <= "0000000000000";  -- Row 0
                        cmd_counter <= cmd_counter + 1;
                    elsif cmd_counter < 3 then
                        sdram_cmd <= CMD_NOP;
                        cmd_counter <= cmd_counter + 1;
                    else
                        state <= READ_DATA;
                        cmd_counter <= (others => '0');
                    end if;
                    
                when READ_DATA =>
                    if cmd_counter = 0 then
                        sdram_cmd <= CMD_READ;
                        SD_BA <= "00";
                        SD_A <= "0000000000000";  -- Column 0
                        dq_oe <= '0';
                        cmd_counter <= cmd_counter + 1;
                    elsif cmd_counter = 2 then
                        -- CAS latency = 2
                        data_read <= SD_DQ;
                        cmd_counter <= cmd_counter + 1;
                    elsif cmd_counter < 5 then
                        sdram_cmd <= CMD_NOP;
                        cmd_counter <= cmd_counter + 1;
                    else
                        state <= DISPLAY;
                    end if;
                    
                when DISPLAY =>
                    LED(3 downto 0) <= data_read(3 downto 0);  -- Show read data
                    LED(4) <= '0';
                    LED(5) <= '0';
                    LED(6) <= '1';  -- Indicate read complete
                    LED(7) <= '0';
                    state <= IDLE;
                    
            end case;
        end if;
    end process;
    
    -- Command outputs
    SD_RAS <= sdram_cmd(2);
    SD_CAS <= sdram_cmd(1);
    SD_WE <= sdram_cmd(0);
    
    -- Chip select always active after init
    SD_CS <= '0' when init_done = '1' else '1';
    
    -- Data mask
    SD_UDM <= '0';
    SD_LDM <= '0';
    
    -- Bidirectional data bus
    SD_DQ <= dq_out when dq_oe = '1' else (others => 'Z');
    
    -- DQS not used in simple implementation
    SD_UDQS <= 'Z';
    SD_LDQS <= 'Z';

end Behavioral;
