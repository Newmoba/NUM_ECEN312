library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk_50mhz : in std_logic;  -- Pin C9
        
        sw        : in std_logic_vector(3 downto 0);   -- SW3-SW0
        
        btn_south : in std_logic;  -- Write to SDRAM
        btn_east  : in std_logic;  -- Read from SDRAM
        
        ld        : out std_logic_vector(7 downto 0);  -- LD7-LD0 (LEDs)
        
        -- DDR SDRAM signals (MIG-ээс үүсгэсэн port-ууд)
        ddr_ck    : out std_logic;
        ddr_ck_n  : out std_logic;
        ddr_cke   : out std_logic;
        ddr_cs_n  : out std_logic;
        ddr_ras_n : out std_logic;
        ddr_cas_n : out std_logic;
        ddr_we_n  : out std_logic;
        ddr_ba    : out std_logic_vector(1 downto 0);
        ddr_a     : out std_logic_vector(12 downto 0);
        ddr_dq    : inout std_logic_vector(15 downto 0);
        ddr_dqs   : inout std_logic_vector(1 downto 0);
        ddr_dm    : out std_logic_vector(1 downto 0)
    );
end top;

architecture Behavioral of top is

    -- MIG user interface signals (MIG example design-ээс)
    signal app_af_cmd     : std_logic_vector(2 downto 0);
    signal app_af_addr    : std_logic_vector(30 downto 0);
    signal app_af_wdf_data: std_logic_vector(31 downto 0);  -- 32-bit write (but we use 16-bit)
    signal app_af_wdf_wren: std_logic;
    signal app_af_af      : std_logic;
    signal app_wdf_rdy    : std_logic;
    signal app_af_rdy     : std_logic;
    signal app_rd_data    : std_logic_vector(31 downto 0);
    signal app_rd_valid   : std_logic;
    signal init_done      : std_logic;  -- Calibration done
    
    signal data_to_write  : std_logic_vector(3 downto 0);
    signal read_data      : std_logic_vector(3 downto 0) := x"0";
    signal test_success   : std_logic := '0';
    
    signal write_pulse    : std_logic := '0';
    signal read_pulse     : std_logic := '0';
    
    -- Debounce
    signal btn_s_db, btn_e_db : std_logic;
    signal clk_slow : std_logic;

begin

    data_to_write <= sw;
    
    -- Simple debounce clock (~1kHz)
    process(clk_50mhz)
        variable cnt : unsigned(15 downto 0) := (others => '0');
    begin
        if rising_edge(clk_50mhz) then
            cnt := cnt + 1;
            clk_slow <= cnt(15);
        end if;
    end process;
    
    db_s: entity work.debounce port map(clk => clk_slow, btn_in => btn_south, btn_out => btn_s_db);
    db_e: entity work.debounce port map(clk => clk_slow, btn_in => btn_east,  btn_out => btn_e_db);
    
    -- Edge detect
    process(clk_50mhz)
        variable prev_s, prev_e : std_logic := '1';
    begin
        if rising_edge(clk_50mhz) then
            write_pulse <= btn_s_db and not prev_s;
            read_pulse  <= btn_e_db and not prev_e;
            prev_s := btn_s_db;
            prev_e := btn_e_db;
        end if;
    end process;
    
    -- MIG instance (таны MIG-ээс үүсгэсэн top module нэр mem_interface_top эсвэл ижил)
    mig_inst: entity work.mem_interface_top
        port map (
            cntrl0_ddr_ck    => ddr_ck,
            cntrl0_ddr_ck_n  => ddr_ck_n,
            cntrl0_ddr_cke   => ddr_cke,
            -- бусад DDR signals...
            cntrl0_rst_dqs_div_in => '0',  -- example
            clk0 => clk_50mhz,
            init_done => init_done,
            
            -- User interface
            app_af_cmd    => app_af_cmd,
            app_af_addr   => app_af_addr,
            app_af_wdf_data => app_af_wdf_data,
            app_af_wdf_wren => app_af_wdf_wren,
            app_af_af     => app_af_af,
            app_wdf_rdy   => app_wdf_rdy,
            app_af_rdy    => app_af_rdy,
            app_rd_data   => app_rd_data,
            app_rd_valid  => app_rd_valid
        );
    
    -- Simple test logic (single address 0x000000, lower 16-bit)
    process(clk_50mhz)
        type state_t is (idle, write_cmd, write_data, read_cmd, check);
        variable state : state_t := idle;
    begin
        if rising_edge(clk_50mhz) then
            if init_done = '0' then
                test_success <= '0';
                state := idle;
            else
                case state is
                    when idle =>
                        if write_pulse = '1' then
                            app_af_cmd <= "000";  -- Write command
                            app_af_addr <= (others => '0');  -- Address 0
                            app_af_wdf_data <= x"0000" & "00000000" & data_to_write & "00000000";  -- example 32-bit
                            app_af_wdf_wren <= '1';
                            app_af_af <= '1';
                            state := write_cmd;
                        elsif read_pulse = '1' then
                            app_af_cmd <= "001";  -- Read
                            app_af_addr <= (others => '0');
                            app_af_af <= '1';
                            state := read_cmd;
                        end if;
                    
                    when write_cmd =>
                        if app_af_rdy = '1' and app_wdf_rdy = '1' then
                            app_af_af <= '0';
                            app_af_wdf_wren <= '0';
                            state := idle;
                        end if;
                    
                    when read_cmd =>
                        if app_af_rdy = '1' then
                            app_af_af <= '0';
                            state := check;
                        end if;
                    
                    when check =>
                        if app_rd_valid = '1' then
                            read_data <= app_rd_data(3 downto 0);  -- adjust according to your data placement
                            if app_rd_data(3 downto 0) = data_to_write then  -- last written
                                test_success <= '1';
                            else
                                test_success <= '0';
                            end if;
                            state := idle;
                        end if;
                    
                    when others => state := idle;
                end case;
            end if;
        end if;
    end process;
    
    -- LED output
    ld(3 downto 0) <= read_data;       -- Уншсан 4-bit LD3-LD0 дээр
    ld(7) <= test_success when init_done = '1' else '0';  -- LD7: success (green if ok)
    ld(6 downto 4) <= "000";           -- Бусад унтраана

end Behavioral;
