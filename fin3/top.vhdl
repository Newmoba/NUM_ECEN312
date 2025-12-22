library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk     : in  std_logic;  -- 50MHz clock, pin C9
        
        -- Switches (4-bit input)
        sw      : in  std_logic_vector(3 downto 0);  -- SW3-SW0
        
        -- Buttons
        btn_north : in std_logic;  -- Write to SDRAM (example BTN_NORTH)
        btn_east  : in std_logic;  -- Read from SDRAM (example BTN_EAST)
        
        -- LCD
        lcd_rs  : out std_logic;
        lcd_rw  : out std_logic;
        lcd_e   : out std_logic;
        lcd_db  : out std_logic_vector(7 downto 4);  -- 4-bit mode, DB7-DB4
        
        -- SDRAM (simplified, real-д зөв controller хэрэгтэй)
        sdram_clk  : out std_logic;
        sdram_cke  : out std_logic;
        sdram_cs   : out std_logic;
        sdram_ras  : out std_logic;
        sdram_cas  : out std_logic;
        sdram_we   : out std_logic;
        sdram_ba   : out std_logic_vector(1 downto 0);
        sdram_a    : out std_logic_vector(12 downto 0);
        sdram_dq   : inout std_logic_vector(15 downto 0);
        sdram_dqm  : out std_logic_vector(1 downto 0)
    );
end top;

architecture Behavioral of top is

    signal data_in     : std_logic_vector(3 downto 0) := (others => '0');
    signal stored_data : std_logic_vector(3 downto 0) := (others => '0');
    signal write_btn   : std_logic := '0';
    signal read_btn    : std_logic := '0';
    signal mode        : std_logic := '0';  -- 0: current input, 1: stored
    
    -- Debounce signals (simple 20ms debounce @50MHz)
    signal btn_n_db    : std_logic := '0';
    signal btn_e_db    : std_logic := '0';
    
    -- LCD signals
    signal lcd_data    : std_logic_vector(7 downto 0);
    signal lcd_rs_sig  : std_logic;
    signal lcd_enable  : std_logic;
    
    -- Clock divider for debounce
    signal cnt         : unsigned(19 downto 0) := (others => '0');
    signal slow_clk    : std_logic := '0';

begin

    -- Clock divider for debounce (~1kHz)
    process(clk)
    begin
        if rising_edge(clk) then
            if cnt = 49999 then
                cnt <= (others => '0');
                slow_clk <= not slow_clk;
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;
    
    -- Simple debounce for buttons
    debounce_n: entity work.debounce port map (clk => slow_clk, btn_in => btn_north, btn_out => btn_n_db);
    debounce_e: entity work.debounce port map (clk => slow_clk, btn_in => btn_east,  btn_out => btn_e_db);
    
    -- Button edge detect (rising edge)
    process(clk)
    begin
        if rising_edge(clk) then
            write_btn <= btn_n_db and not btn_north;  -- simplistic, better use proper edge
            read_btn  <= btn_e_db and not btn_east;
        end if;
    end process;
    
    data_in <= sw;
    
    -- Write to "SDRAM" (simple register simulation)
    process(clk)
    begin
        if rising_edge(clk) then
            if write_btn = '1' then
                stored_data <= data_in;
                mode <= '1';  -- switch to show stored
            end if;
            if read_btn = '1' then
                mode <= '1';
            end if;
        end if;
    end process;
    
    -- Display select
    process(mode, data_in, stored_data)
        variable hex_char : std_logic_vector(7 downto 0);
    begin
        if mode = '0' then
            -- Convert 4-bit to hex char
            case data_in is
                when "0000" => hex_char := x"30";  -- 0
                when "0001" => hex_char := x"31";
                when "0010" => hex_char := x"32";
                when "0011" => hex_char := x"33";
                when "0100" => hex_char := x"34";
                when "0101" => hex_char := x"35";
                when "0110" => hex_char := x"36";
                when "0111" => hex_char := x"37";
                when "1000" => hex_char := x"38";
                when "1001" => hex_char := x"39";
                when "1010" => hex_char := x"41";  -- A
                when "1011" => hex_char := x"42";
                when "1100" => hex_char := x"43";
                when "1101" => hex_char := x"44";
                when "1110" => hex_char := x"45";
                when others => hex_char := x"46";  -- F
            end case;
            lcd_data <= "Input:  " & hex_char;
        else
            -- same for stored
            case stored_data is
                -- same case
                when others => hex_char := x"30";
            end case;
            lcd_data <= "Stored: " & hex_char;
        end if;
    end process;
    
    -- LCD controller instance
    lcd_inst: entity work.lcd_controller
        port map (
            clk      => clk,
            rs       => lcd_rs_sig,
            rw       => lcd_rw,
            e        => lcd_enable,
            data     => lcd_data,
            lcd_db   => lcd_db
        );
    
    lcd_rs <= lcd_rs_sig;
    lcd_rw <= '0';  -- always write
    lcd_e  <= lcd_enable;
    
    -- Simplified SDRAM (NOT REAL, just placeholder)
    sdram_clk <= clk;
    sdram_cke <= '1';
    sdram_cs  <= '0';
    -- other signals '0' etc. Бодит controller хэрэгтэй!
    
end Behavioral;
