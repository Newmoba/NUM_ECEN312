library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DDR_SDRAM_LCD_System is
    Port (
        clk         : in  STD_LOGIC;  -- 50MHz системийн цаг
        reset       : in  STD_LOGIC;  -- Reset товч
        
        -- Switch оролтууд (8 switch)
        switches    : in  STD_LOGIC_VECTOR(7 downto 0);
        
        -- Button оролтууд
        btn_test    : in  STD_LOGIC;  -- Тест эхлүүлэх
        btn_write   : in  STD_LOGIC;  -- Бичих команд
        btn_read    : in  STD_LOGIC;  -- Унших команд
        
        -- LCD 4-bit интерфейс
        lcd_rs      : out STD_LOGIC;  -- Register Select
        lcd_rw      : out STD_LOGIC;  -- Read/Write
        lcd_en      : out STD_LOGIC;  -- Enable
        lcd_data    : out STD_LOGIC_VECTOR(3 downto 0);  -- 4-bit өгөгдөл
        
        -- DDR SDRAM интерфейс (симуляци)
        ddr_addr    : out STD_LOGIC_VECTOR(12 downto 0);
        ddr_ba      : out STD_LOGIC_VECTOR(1 downto 0);
        ddr_cas_n   : out STD_LOGIC;
        ddr_ras_n   : out STD_LOGIC;
        ddr_we_n    : out STD_LOGIC;
        ddr_clk     : out STD_LOGIC;
        
        -- LED статус
        led_status  : out STD_LOGIC_VECTOR(7 downto 0)
    );
end DDR_SDRAM_LCD_System;

architecture Behavioral of DDR_SDRAM_LCD_System is

    -- LCD хянагч төлөвүүд
    type lcd_state_type is (
        POWER_ON, INIT_START, FUNC_SET1, FUNC_SET2, FUNC_SET3,
        DISP_ON, DISP_CLEAR, ENTRY_MODE, READY,
        WRITE_CHAR1, WRITE_CHAR2, SET_ADDR, DELAY_STATE
    );
    signal lcd_state : lcd_state_type := POWER_ON;
    
    -- DDR тест төлөвүүд
    type ddr_state_type is (IDLE, WRITE_DATA, READ_DATA, VERIFY, COMPLETE, ERROR);
    signal ddr_state : ddr_state_type := IDLE;
    
    -- Дотоод сигналууд
    signal clk_div       : unsigned(19 downto 0) := (others => '0');
    signal lcd_clk       : STD_LOGIC := '0';  -- ~1ms LCD цаг
    signal delay_counter : unsigned(15 downto 0) := (others => '0');
    signal char_counter  : unsigned(4 downto 0) := (others => '0');
    
    -- LCD өгөгдөл
    signal lcd_data_byte : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal lcd_nibble    : STD_LOGIC := '0';  -- 0=дээд, 1=доод nibble
    
    -- Button debounce
    signal btn_test_prev  : STD_LOGIC := '0';
    signal btn_write_prev : STD_LOGIC := '0';
    signal btn_read_prev  : STD_LOGIC := '0';
    
    -- DDR тест өгөгдөл
    signal test_data      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal read_data      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal error_count    : unsigned(7 downto 0) := (others => '0');
    signal test_address   : unsigned(12 downto 0) := (others => '0');
    
    -- LCD мессеж буфер
    type message_type is array (0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    signal lcd_message : message_type;
    
    -- ASCII тогтмол утгууд
    constant CHAR_D : STD_LOGIC_VECTOR(7 downto 0) := X"44";
    constant CHAR_R : STD_LOGIC_VECTOR(7 downto 0) := X"52";
    constant CHAR_T : STD_LOGIC_VECTOR(7 downto 0) := X"54";
    constant CHAR_E : STD_LOGIC_VECTOR(7 downto 0) := X"45";
    constant CHAR_S : STD_LOGIC_VECTOR(7 downto 0) := X"53";
    constant CHAR_COLON : STD_LOGIC_VECTOR(7 downto 0) := X"3A";
    constant CHAR_SPACE : STD_LOGIC_VECTOR(7 downto 0) := X"20";
    constant CHAR_O : STD_LOGIC_VECTOR(7 downto 0) := X"4F";
    constant CHAR_K : STD_LOGIC_VECTOR(7 downto 0) := X"4B";
    constant CHAR_F : STD_LOGIC_VECTOR(7 downto 0) := X"46";
    constant CHAR_A : STD_LOGIC_VECTOR(7 downto 0) := X"41";
    constant CHAR_I : STD_LOGIC_VECTOR(7 downto 0) := X"49";
    constant CHAR_L : STD_LOGIC_VECTOR(7 downto 0) := X"4C";
    constant CHAR_W : STD_LOGIC_VECTOR(7 downto 0) := X"57";
    constant CHAR_0 : STD_LOGIC_VECTOR(7 downto 0) := X"30";
    
    -- LCD командууд
    constant LCD_CLEAR   : STD_LOGIC_VECTOR(7 downto 0) := X"01";
    constant LCD_HOME    : STD_LOGIC_VECTOR(7 downto 0) := X"02";
    constant LCD_FUNC_4B : STD_LOGIC_VECTOR(7 downto 0) := X"28";  -- 4-bit, 2 мөр
    constant LCD_DISP_ON : STD_LOGIC_VECTOR(7 downto 0) := X"0C";  -- Дэлгэц асаах
    constant LCD_ENTRY   : STD_LOGIC_VECTOR(7 downto 0) := X"06";  -- Entry mode
    constant LCD_LINE2   : STD_LOGIC_VECTOR(7 downto 0) := X"C0";  -- 2-р мөр

begin

    -- LED статус индикатор
    led_status(7 downto 5) <= "000";
    led_status(4) <= '1' when ddr_state = COMPLETE else '0';
    led_status(3) <= '1' when ddr_state = ERROR else '0';
    led_status(2) <= '1' when ddr_state = WRITE_DATA or ddr_state = READ_DATA else '0';
    led_status(1) <= '1' when lcd_state = READY else '0';
    led_status(0) <= lcd_clk;
    
    -- DDR симуляци сигналууд
    ddr_clk <= clk;
    lcd_rw <= '0';  -- Зөвхөн бичих горим

    -- Цагийн хуваагч (LCD-д зориулж)
    process(clk, reset)
    begin
        if reset = '1' then
            clk_div <= (others => '0');
            lcd_clk <= '0';
        elsif rising_edge(clk) then
            clk_div <= clk_div + 1;
            if clk_div = 50000 then  -- ~1ms @ 50MHz
                lcd_clk <= '1';
                clk_div <= (others => '0');
            else
                lcd_clk <= '0';
            end if;
        end if;
    end process;

    -- DDR SDRAM тест логик
    process(clk, reset)
    begin
        if reset = '1' then
            ddr_state <= IDLE;
            test_data <= (others => '0');
            read_data <= (others => '0');
            error_count <= (others => '0');
            test_address <= (others => '0');
            btn_test_prev <= '0';
            btn_write_prev <= '0';
            btn_read_prev <= '0';
            ddr_addr <= (others => '0');
            ddr_ba <= "00";
            ddr_cas_n <= '1';
            ddr_ras_n <= '1';
            ddr_we_n <= '1';
        elsif rising_edge(clk) then
            btn_test_prev <= btn_test;
            btn_write_prev <= btn_write;
            btn_read_prev <= btn_read;
            
            case ddr_state is
                when IDLE =>
                    ddr_cas_n <= '1';
                    ddr_ras_n <= '1';
                    ddr_we_n <= '1';
                    
                    if btn_test = '1' and btn_test_prev = '0' then
                        test_data <= switches;
                        test_address <= (others => '0');
                        error_count <= (others => '0');
                        ddr_state <= WRITE_DATA;
                    end if;
                    
                when WRITE_DATA =>
                    -- DDR бичих команд симуляци
                    ddr_addr <= std_logic_vector(test_address);
                    ddr_ba <= "00";
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '0';
                    ddr_we_n <= '0';
                    
                    if delay_counter < 100 then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= (others => '0');
                        ddr_state <= READ_DATA;
                    end if;
                    
                when READ_DATA =>
                    -- DDR унших команд симуляци
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '0';
                    ddr_we_n <= '1';
                    
                    if delay_counter < 100 then
                        delay_counter <= delay_counter + 1;
                        -- Симуляцид буцаах өгөгдөл
                        read_data <= test_data;
                    else
                        delay_counter <= (others => '0');
                        ddr_state <= VERIFY;
                    end if;
                    
                when VERIFY =>
                    if read_data = test_data then
                        ddr_state <= COMPLETE;
                    else
                        error_count <= error_count + 1;
                        ddr_state <= ERROR;
                    end if;
                    
                when COMPLETE =>
                    ddr_cas_n <= '1';
                    ddr_ras_n <= '1';
                    ddr_we_n <= '1';
                    -- IDLE төлөвт буцах
                    if btn_test = '1' and btn_test_prev = '0' then
                        ddr_state <= IDLE;
                    end if;
                    
                when ERROR =>
                    ddr_cas_n <= '1';
                    ddr_ras_n <= '1';
                    ddr_we_n <= '1';
                    if btn_test = '1' and btn_test_prev = '0' then
                        ddr_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- LCD мессеж бэлтгэх
    process(clk)
    begin
        if rising_edge(clk) then
            -- 1-р мөр: "DDR TEST: "
            lcd_message(0) <= CHAR_D;
            lcd_message(1) <= CHAR_D;
            lcd_message(2) <= CHAR_R;
            lcd_message(3) <= CHAR_SPACE;
            lcd_message(4) <= CHAR_T;
            lcd_message(5) <= CHAR_E;
            lcd_message(6) <= CHAR_S;
            lcd_message(7) <= CHAR_T;
            lcd_message(8) <= CHAR_COLON;
            lcd_message(9) <= CHAR_SPACE;
            
            -- Төлөв харуулах
            case ddr_state is
                when IDLE =>
                    lcd_message(10) <= CHAR_I;
                    lcd_message(11) <= CHAR_D;
                    lcd_message(12) <= CHAR_L;
                    lcd_message(13) <= CHAR_E;
                when WRITE_DATA =>
                    lcd_message(10) <= CHAR_W;
                    lcd_message(11) <= CHAR_R;
                    lcd_message(12) <= CHAR_I;
                    lcd_message(13) <= CHAR_T;
                    lcd_message(14) <= CHAR_E;
                when READ_DATA =>
                    lcd_message(10) <= CHAR_R;
                    lcd_message(11) <= CHAR_E;
                    lcd_message(12) <= CHAR_A;
                    lcd_message(13) <= CHAR_D;
                when COMPLETE =>
                    lcd_message(10) <= CHAR_O;
                    lcd_message(11) <= CHAR_K;
                    lcd_message(12) <= CHAR_SPACE;
                    lcd_message(13) <= CHAR_SPACE;
                when ERROR =>
                    lcd_message(10) <= CHAR_F;
                    lcd_message(11) <= CHAR_A;
                    lcd_message(12) <= CHAR_I;
                    lcd_message(13) <= CHAR_L;
                when others =>
                    lcd_message(10) <= CHAR_SPACE;
            end case;
            
            -- 2-р мөр: "DATA: XX"
            lcd_message(16) <= CHAR_D;
            lcd_message(17) <= CHAR_A;
            lcd_message(18) <= CHAR_T;
            lcd_message(19) <= CHAR_A;
            lcd_message(20) <= CHAR_COLON;
            lcd_message(21) <= CHAR_SPACE;
            
            -- Switch утгыг hex форматаар
            lcd_message(22) <= std_logic_vector(to_unsigned(
                to_integer(unsigned(test_data(7 downto 4))) + 48 + 
                (7 * to_integer(unsigned'("000" & test_data(7)))), 8));
            lcd_message(23) <= std_logic_vector(to_unsigned(
                to_integer(unsigned(test_data(3 downto 0))) + 48 + 
                (7 * to_integer(unsigned'("000" & test_data(3)))), 8));
        end if;
    end process;

    -- LCD хянагч (4-bit горим)
    process(clk, reset)
    begin
        if reset = '1' then
            lcd_state <= POWER_ON;
            lcd_rs <= '0';
            lcd_en <= '0';
            lcd_data <= "0000";
            delay_counter <= (others => '0');
            char_counter <= (others => '0');
            lcd_nibble <= '0';
        elsif rising_edge(clk) then
            if lcd_clk = '1' then
                case lcd_state is
                    when POWER_ON =>
                        lcd_en <= '0';
                        lcd_rs <= '0';
                        if delay_counter < 1000 then
                            delay_counter <= delay_counter + 1;
                        else
                            delay_counter <= (others => '0');
                            lcd_state <= INIT_START;
                        end if;
                        
                    when INIT_START =>
                        -- 4-bit горим эхлүүлэх
                        lcd_rs <= '0';
                        lcd_data <= "0011";
                        lcd_en <= '1';
                        if delay_counter < 10 then
                            delay_counter <= delay_counter + 1;
                        else
                            lcd_en <= '0';
                            delay_counter <= (others => '0');
                            lcd_state <= FUNC_SET1;
                        end if;
                        
                    when FUNC_SET1 =>
                        lcd_rs <= '0';
                        lcd_data <= "0010";  -- 4-bit горим
                        lcd_en <= '1';
                        if delay_counter < 10 then
                            delay_counter <= delay_counter + 1;
                        else
                            lcd_en <= '0';
                            delay_counter <= (others => '0');
                            lcd_state <= FUNC_SET2;
                            lcd_data_byte <= LCD_FUNC_4B;
                            lcd_nibble <= '0';
                        end if;
                        
                    when FUNC_SET2 =>
                        lcd_rs <= '0';
                        if lcd_nibble = '0' then
                            lcd_data <= lcd_data_byte(7 downto 4);
                            lcd_en <= '1';
                            lcd_nibble <= '1';
                        else
                            lcd_data <= lcd_data_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_counter < 5 then
                                delay_counter <= delay_counter + 1;
                            else
                                lcd_en <= '0';
                                delay_counter <= (others => '0');
                                lcd_nibble <= '0';
                                lcd_state <= DISP_ON;
                                lcd_data_byte <= LCD_DISP_ON;
                            end if;
                        end if;
                        
                    when DISP_ON =>
                        lcd_rs <= '0';
                        if lcd_nibble = '0' then
                            lcd_data <= lcd_data_byte(7 downto 4);
                            lcd_en <= '1';
                            lcd_nibble <= '1';
                        else
                            lcd_data <= lcd_data_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_counter < 5 then
                                delay_counter <= delay_counter + 1;
                            else
                                lcd_en <= '0';
                                delay_counter <= (others => '0');
                                lcd_nibble <= '0';
                                lcd_state <= DISP_CLEAR;
                                lcd_data_byte <= LCD_CLEAR;
                            end if;
                        end if;
                        
                    when DISP_CLEAR =>
                        lcd_rs <= '0';
                        if lcd_nibble = '0' then
                            lcd_data <= lcd_data_byte(7 downto 4);
                            lcd_en <= '1';
                            lcd_nibble <= '1';
                        else
                            lcd_data <= lcd_data_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_counter < 100 then
                                delay_counter <= delay_counter + 1;
                            else
                                lcd_en <= '0';
                                delay_counter <= (others => '0');
                                lcd_nibble <= '0';
                                lcd_state <= ENTRY_MODE;
                                lcd_data_byte <= LCD_ENTRY;
                            end if;
                        end if;
                        
                    when ENTRY_MODE =>
                        lcd_rs <= '0';
                        if lcd_nibble = '0' then
                            lcd_data <= lcd_data_byte(7 downto 4);
                            lcd_en <= '1';
                            lcd_nibble <= '1';
                        else
                            lcd_data <= lcd_data_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_counter < 5 then
                                delay_counter <= delay_counter + 1;
                            else
                                lcd_en <= '0';
                                delay_counter <= (others => '0');
                                lcd_nibble <= '0';
                                lcd_state <= READY;
                                char_counter <= (others => '0');
                            end if;
                        end if;
                        
                    when READY =>
                        lcd_en <= '0';
                        char_counter <= (others => '0');
                        lcd_state <= WRITE_CHAR1;
                        
                    when WRITE_CHAR1 =>
                        -- 1-р мөр бичих
                        if char_counter < 16 then
                            lcd_rs <= '1';  -- Өгөгдөл бичих
                            lcd_data_byte <= lcd_message(to_integer(char_counter));
                            
                            if lcd_nibble = '0' then
                                lcd_data <= lcd_data_byte(7 downto 4);
                                lcd_en <= '1';
                                lcd_nibble <= '1';
                            else
                                lcd_data <= lcd_data_byte(3 downto 0);
                                lcd_en <= '1';
                                if delay_counter < 3 then
                                    delay_counter <= delay_counter + 1;
                                else
                                    lcd_en <= '0';
                                    delay_counter <= (others => '0');
                                    lcd_nibble <= '0';
                                    char_counter <= char_counter + 1;
                                end if;
                            end if;
                        else
                            char_counter <= (others => '0');
                            lcd_state <= SET_ADDR;
                            lcd_data_byte <= LCD_LINE2;
                        end if;
                        
                    when SET_ADDR =>
                        -- 2-р мөрийн хаяг тохируулах
                        lcd_rs <= '0';
                        if lcd_nibble = '0' then
                            lcd_data <= lcd_data_byte(7 downto 4);
                            lcd_en <= '1';
                            lcd_nibble <= '1';
                        else
                            lcd_data <= lcd_data_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_counter < 5 then
                                delay_counter <= delay_counter + 1;
                            else
                                lcd_en <= '0';
                                delay_counter <= (others => '0');
                                lcd_nibble <= '0';
                                lcd_state <= WRITE_CHAR2;
                            end if;
                        end if;
                        
                    when WRITE_CHAR2 =>
                        -- 2-р мөр бичих
                        if char_counter < 16 then
                            lcd_rs <= '1';
                            lcd_data_byte <= lcd_message(to_integer(char_counter + 16));
                            
                            if lcd_nibble = '0' then
                                lcd_data <= lcd_data_byte(7 downto 4);
                                lcd_en <= '1';
                                lcd_nibble <= '1';
                            else
                                lcd_data <= lcd_data_byte(3 downto 0);
                                lcd_en <= '1';
                                if delay_counter < 3 then
                                    delay_counter <= delay_counter + 1;
                                else
                                    lcd_en <= '0';
                                    delay_counter <= (others => '0');
                                    lcd_nibble <= '0';
                                    char_counter <= char_counter + 1;
                                end if;
                            end if;
                        else
                            lcd_state <= DELAY_STATE;
                            char_counter <= (others => '0');
                        end if;
                        
                    when DELAY_STATE =>
                        lcd_en <= '0';
                        if delay_counter < 5000 then  -- ~5ms шинэчлэх хугацаа
                            delay_counter <= delay_counter + 1;
                        else
                            delay_counter <= (others => '0');
                            lcd_state <= READY;
                        end if;
                end case;
            end if;
        end if;
    end process;

end Behavioral;
