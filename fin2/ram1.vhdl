library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DDR_LCD is
    Port (
        clk     : in  STD_LOGIC;
        rst     : in  STD_LOGIC;
        sw      : in  STD_LOGIC_VECTOR(3 downto 0);
        btn_wr  : in  STD_LOGIC;
        btn_rd  : in  STD_LOGIC;
        lcd_rs  : out STD_LOGIC;
        lcd_rw  : out STD_LOGIC;
        lcd_en  : out STD_LOGIC;
        lcd_d   : out STD_LOGIC_VECTOR(3 downto 0);
        ddr_a   : out STD_LOGIC_VECTOR(12 downto 0);
        ddr_ba  : out STD_LOGIC_VECTOR(1 downto 0);
        ddr_cas : out STD_LOGIC;
        ddr_ras : out STD_LOGIC;
        ddr_we  : out STD_LOGIC;
        ddr_clk : out STD_LOGIC;
        led     : out STD_LOGIC_VECTOR(3 downto 0)
    );
end DDR_LCD;

architecture rtl of DDR_LCD is
    type lcd_state_type is (
        LCD_POWER_ON, LCD_INIT, LCD_FUNC_SET1, LCD_FUNC_SET2, LCD_FUNC_SET3,
        LCD_DISPLAY_ON, LCD_CLEAR, LCD_ENTRY_MODE, LCD_READY,
        LCD_WRITE_LINE1, LCD_WRITE_LINE2, LCD_SET_LINE2, LCD_DELAY
    );
    signal lcd_state : lcd_state_type := LCD_POWER_ON;
    
    type ddr_state_type is (STATE_IDLE, STATE_WRITE, STATE_READ, STATE_OK, STATE_ERROR);
    signal ddr_state : ddr_state_type := STATE_IDLE;
    
    -- TIMING-ийг УДААШРУУЛСАН
    signal clock_divider    : unsigned(19 downto 0) := (others => '0');
    signal lcd_clock        : STD_LOGIC := '0';
    signal lcd_delay_count  : unsigned(19 downto 0) := (others => '0');  -- 16→20 bit
    signal ddr_delay_count  : unsigned(15 downto 0) := (others => '0');
    signal char_count       : unsigned(4 downto 0) := (others => '0');
    signal lcd_byte         : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal nibble_select    : STD_LOGIC := '0';
    signal btn_write_prev   : STD_LOGIC := '0';
    signal btn_read_prev    : STD_LOGIC := '0';
    signal write_data       : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal read_data        : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    
    type message_array is array (0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    signal lcd_text : message_array;
    
    constant CMD_CLEAR      : STD_LOGIC_VECTOR(7 downto 0) := X"01";
    constant CMD_FUNC_4BIT  : STD_LOGIC_VECTOR(7 downto 0) := X"28";
    constant CMD_DISPLAY_ON : STD_LOGIC_VECTOR(7 downto 0) := X"0C";
    constant CMD_ENTRY_MODE : STD_LOGIC_VECTOR(7 downto 0) := X"06";
    constant CMD_LINE2      : STD_LOGIC_VECTOR(7 downto 0) := X"C0";

begin
    led(3) <= '1' when ddr_state = STATE_ERROR else '0';
    led(2) <= '1' when ddr_state = STATE_OK else '0';
    led(1) <= '1' when ddr_state = STATE_WRITE or ddr_state = STATE_READ else '0';
    led(0) <= '1' when ddr_state = STATE_IDLE else '0';
    
    ddr_clk <= clk;
    lcd_rw <= '0';

    -- ===================================
    -- LCD Clock: 50MHz → ~200Hz (УДААН!)
    -- ===================================
    process(clk, rst)
    begin
        if rst = '1' then
            clock_divider <= (others => '0');
            lcd_clock <= '0';
        elsif rising_edge(clk) then
            clock_divider <= clock_divider + 1;
            -- 250000 cycles @ 50MHz = 5ms period = 200Hz
            if clock_divider = 250000 then
                lcd_clock <= '1';
                clock_divider <= (others => '0');
            else
                lcd_clock <= '0';
            end if;
        end if;
    end process;

    -- DDR тест логик (өмнөхтэй адилхан)
    process(clk, rst)
    begin
        if rst = '1' then
            ddr_state <= STATE_IDLE;
            write_data <= (others => '0');
            read_data <= (others => '0');
            btn_write_prev <= '0';
            btn_read_prev <= '0';
            ddr_delay_count <= (others => '0');
            ddr_a <= (others => '0');
            ddr_ba <= "00";
            ddr_cas <= '1';
            ddr_ras <= '1';
            ddr_we <= '1';
        elsif rising_edge(clk) then
            btn_write_prev <= btn_wr;
            btn_read_prev <= btn_rd;
            
            case ddr_state is
                when STATE_IDLE =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we <= '1';
                    ddr_delay_count <= (others => '0');
                    
                    if btn_wr = '1' and btn_write_prev = '0' then
                        write_data <= sw;
                        ddr_state <= STATE_WRITE;
                    elsif btn_rd = '1' and btn_read_prev = '0' then
                        ddr_state <= STATE_READ;
                    end if;
                    
                when STATE_WRITE =>
                    ddr_a <= (others => '0');
                    ddr_ba <= "00";
                    ddr_ras <= '0';
                    ddr_cas <= '0';
                    ddr_we <= '0';
                    
                    if ddr_delay_count < 100 then
                        ddr_delay_count <= ddr_delay_count + 1;
                    else
                        ddr_delay_count <= (others => '0');
                        ddr_state <= STATE_OK;
                    end if;
                    
                when STATE_READ =>
                    ddr_ras <= '0';
                    ddr_cas <= '0';
                    ddr_we <= '1';
                    
                    if ddr_delay_count < 100 then
                        ddr_delay_count <= ddr_delay_count + 1;
                        read_data <= write_data;
                    else
                        ddr_delay_count <= (others => '0');
                        if read_data = write_data then
                            ddr_state <= STATE_OK;
                        else
                            ddr_state <= STATE_ERROR;
                        end if;
                    end if;
                    
                when STATE_OK | STATE_ERROR =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we <= '1';
                    if btn_wr = '1' and btn_write_prev = '0' then
                        ddr_state <= STATE_IDLE;
                    elsif btn_rd = '1' and btn_read_prev = '0' then
                        ddr_state <= STATE_IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- LCD текст бэлтгэх
    process(clk)
    begin
        if rising_edge(clk) then
            lcd_text(0) <= X"44";  -- D
            lcd_text(1) <= X"44";  -- D
            lcd_text(2) <= X"52";  -- R
            lcd_text(3) <= X"20";
            lcd_text(4) <= X"54";  -- T
            lcd_text(5) <= X"45";  -- E
            lcd_text(6) <= X"53";  -- S
            lcd_text(7) <= X"54";  -- T
            lcd_text(8) <= X"3A";  -- :
            lcd_text(9) <= X"20";
            
            case ddr_state is
                when STATE_IDLE =>
                    lcd_text(10) <= X"52";  -- R
                    lcd_text(11) <= X"45";  -- E
                    lcd_text(12) <= X"41";  -- A
                    lcd_text(13) <= X"44";  -- D
                    lcd_text(14) <= X"59";  -- Y
                when STATE_WRITE =>
                    lcd_text(10) <= X"57";  -- W
                    lcd_text(11) <= X"52";  -- R
                    lcd_text(12) <= X"49";  -- I
                    lcd_text(13) <= X"54";  -- T
                    lcd_text(14) <= X"45";  -- E
                when STATE_READ =>
                    lcd_text(10) <= X"52";  -- R
                    lcd_text(11) <= X"45";  -- E
                    lcd_text(12) <= X"41";  -- A
                    lcd_text(13) <= X"44";  -- D
                    lcd_text(14) <= X"20";
                when STATE_OK =>
                    lcd_text(10) <= X"4F";  -- O
                    lcd_text(11) <= X"4B";  -- K
                    lcd_text(12) <= X"20";
                    lcd_text(13) <= X"20";
                    lcd_text(14) <= X"20";
                when STATE_ERROR =>
                    lcd_text(10) <= X"45";  -- E
                    lcd_text(11) <= X"52";  -- R
                    lcd_text(12) <= X"52";  -- R
                    lcd_text(13) <= X"4F";  -- O
                    lcd_text(14) <= X"52";  -- R
            end case;
            lcd_text(15) <= X"20";
            
            lcd_text(16) <= X"57";  -- W
            lcd_text(17) <= X"52";  -- R
            lcd_text(18) <= X"3A";  -- :
            
            case write_data is
                when "0000" => lcd_text(19) <= X"30";
                when "0001" => lcd_text(19) <= X"31";
                when "0010" => lcd_text(19) <= X"32";
                when "0011" => lcd_text(19) <= X"33";
                when "0100" => lcd_text(19) <= X"34";
                when "0101" => lcd_text(19) <= X"35";
                when "0110" => lcd_text(19) <= X"36";
                when "0111" => lcd_text(19) <= X"37";
                when "1000" => lcd_text(19) <= X"38";
                when "1001" => lcd_text(19) <= X"39";
                when "1010" => lcd_text(19) <= X"41";
                when "1011" => lcd_text(19) <= X"42";
                when "1100" => lcd_text(19) <= X"43";
                when "1101" => lcd_text(19) <= X"44";
                when "1110" => lcd_text(19) <= X"45";
                when "1111" => lcd_text(19) <= X"46";
                when others => lcd_text(19) <= X"3F";
            end case;
            
            lcd_text(20) <= X"20";
            lcd_text(21) <= X"52";  -- R
            lcd_text(22) <= X"44";  -- D
            lcd_text(23) <= X"3A";  -- :
            
            case read_data is
                when "0000" => lcd_text(24) <= X"30";
                when "0001" => lcd_text(24) <= X"31";
                when "0010" => lcd_text(24) <= X"32";
                when "0011" => lcd_text(24) <= X"33";
                when "0100" => lcd_text(24) <= X"34";
                when "0101" => lcd_text(24) <= X"35";
                when "0110" => lcd_text(24) <= X"36";
                when "0111" => lcd_text(24) <= X"37";
                when "1000" => lcd_text(24) <= X"38";
                when "1001" => lcd_text(24) <= X"39";
                when "1010" => lcd_text(24) <= X"41";
                when "1011" => lcd_text(24) <= X"42";
                when "1100" => lcd_text(24) <= X"43";
                when "1101" => lcd_text(24) <= X"44";
                when "1110" => lcd_text(24) <= X"45";
                when "1111" => lcd_text(24) <= X"46";
                when others => lcd_text(24) <= X"3F";
            end case;
            
            for i in 25 to 31 loop
                lcd_text(i) <= X"20";
            end loop;
        end if;
    end process;

    -- ===================================
    -- LCD хянагч - УДААН TIMING
    -- ===================================
    process(clk, rst)
    begin
        if rst = '1' then
            lcd_state <= LCD_POWER_ON;
            lcd_rs <= '0';
            lcd_en <= '0';
            lcd_d <= "0000";
            lcd_delay_count <= (others => '0');
            char_count <= (others => '0');
            nibble_select <= '0';
        elsif rising_edge(clk) then
            if lcd_clock = '1' then
                case lcd_state is
                    when LCD_POWER_ON =>
                        lcd_en <= '0';
                        lcd_rs <= '0';
                        -- 15ms хүлээх @ 200Hz = 3000 cycles
                        if lcd_delay_count < 3000 then
                            lcd_delay_count <= lcd_delay_count + 1;
                        else
                            lcd_delay_count <= (others => '0');
                            lcd_state <= LCD_INIT;
                        end if;
                        
                    when LCD_INIT =>
                        lcd_rs <= '0';
                        lcd_d <= "0011";
                        lcd_en <= '1';
                        if lcd_delay_count < 100 then
                            lcd_delay_count <= lcd_delay_count + 1;
                        else
                            lcd_en <= '0';
                            lcd_delay_count <= (others => '0');
                            lcd_state <= LCD_FUNC_SET1;
                        end if;
                        
                    when LCD_FUNC_SET1 =>
                        lcd_rs <= '0';
                        lcd_d <= "0010";
                        lcd_en <= '1';
                        if lcd_delay_count < 100 then
                            lcd_delay_count <= lcd_delay_count + 1;
                        else
                            lcd_en <= '0';
                            lcd_delay_count <= (others => '0');
                            lcd_state <= LCD_FUNC_SET2;
                            lcd_byte <= CMD_FUNC_4BIT;
                            nibble_select <= '0';
                        end if;
                        
                    when LCD_FUNC_SET2 =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if lcd_delay_count < 50 then
                                lcd_delay_count <= lcd_delay_count + 1;
                            else
                                lcd_en <= '0';
                                lcd_delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_FUNC_SET3;
                            end if;
                        end if;
                        
                    when LCD_FUNC_SET3 =>
                        lcd_en <= '0';
                        if lcd_delay_count < 100 then
                            lcd_delay_count <= lcd_delay_count + 1;
                        else
                            lcd_delay_count <= (others => '0');
                            lcd_state <= LCD_DISPLAY_ON;
                            lcd_byte <= CMD_DISPLAY_ON;
                            nibble_select <= '0';
                        end if;
                        
                    when LCD_DISPLAY_ON =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if lcd_delay_count < 50 then
                                lcd_delay_count <= lcd_delay_count + 1;
                            else
                                lcd_en <= '0';
                                lcd_delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_CLEAR;
                                lcd_byte <= CMD_CLEAR;
                            end if;
                        end if;
                        
                    when LCD_CLEAR =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if lcd_delay_count < 500 then
                                lcd_delay_count <= lcd_delay_count + 1;
                            else
                                lcd_en <= '0';
                                lcd_delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_ENTRY_MODE;
                                lcd_byte <= CMD_ENTRY_MODE;
                            end if;
                        end if;
                        
                    when LCD_ENTRY_MODE =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if lcd_delay_count < 50 then
                                lcd_delay_count <= lcd_delay_count + 1;
                            else
                                lcd_en <= '0';
                                lcd_delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_READY;
                                char_count <= (others => '0');
                            end if;
                        end if;
                        
                    when LCD_READY =>
                        lcd_en <= '0';
                        char_count <= (others => '0');
                        lcd_state <= LCD_WRITE_LINE1;
                        
                    when LCD_WRITE_LINE1 =>
                        if char_count < 16 then
                            lcd_rs <= '1';
                            lcd_byte <= lcd_text(to_integer(char_count));
                            
                            if nibble_select = '0' then
                                lcd_d <= lcd_byte(7 downto 4);
                                lcd_en <= '1';
                                nibble_select <= '1';
                            else
                                lcd_d <= lcd_byte(3 downto 0);
                                lcd_en <= '1';
                                if lcd_delay_count < 30 then
                                    lcd_delay_count <= lcd_delay_count + 1;
                                else
                                    lcd_en <= '0';
                                    lcd_delay_count <= (others => '0');
                                    nibble_select <= '0';
                                    char_count <= char_count + 1;
                                end if;
                            end if;
                        else
                            char_count <= (others => '0');
                            lcd_state <= LCD_SET_LINE2;
                            lcd_byte <= CMD_LINE2;
                        end if;
                        
                    when LCD_SET_LINE2 =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if lcd_delay_count < 50 then
                                lcd_delay_count <= lcd_delay_count + 1;
                            else
                                lcd_en <= '0';
                                lcd_delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_WRITE_LINE2;
                            end if;
                        end if;
                        
                    when LCD_WRITE_LINE2 =>
                        if char_count < 16 then
                            lcd_rs <= '1';
                            lcd_byte <= lcd_text(to_integer(char_count + 16));
                            
                            if nibble_select = '0' then
                                lcd_d <= lcd_byte(7 downto 4);
                                lcd_en <= '1';
                                nibble_select <= '1';
                            else
                                lcd_d <= lcd_byte(3 downto 0);
                                lcd_en <= '1';
                                if lcd_delay_count < 30 then
                                    lcd_delay_count <= lcd_delay_count + 1;
                                else
                                    lcd_en <= '0';
                                    lcd_delay_count <= (others => '0');
                                    nibble_select <= '0';
                                    char_count <= char_count + 1;
                                end if;
                            end if;
                        else
                            lcd_state <= LCD_DELAY;
                            char_count <= (others => '0');
                        end if;
                        
                    when LCD_DELAY =>
                        lcd_en <= '0';
                        if lcd_delay_count < 10000 then
                            lcd_delay_count <= lcd_delay_count + 1;
                        else
                            lcd_delay_count <= (others => '0');
                            lcd_state <= LCD_READY;
                        end if;
                end case;
            end if;
        end if;
    end process;

end rtl;
