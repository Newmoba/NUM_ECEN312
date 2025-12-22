library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ======================================
-- DDR санах ой тестийн систем
-- 4 switch, 2 button, LCD дэлгэц
-- ======================================
entity DDR_LCD is
    Port (
        clk     : in  STD_LOGIC;                      -- Системийн цаг
        rst     : in  STD_LOGIC;                      -- Reset товч
        sw      : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4 switch (өгөгдөл)
        btn_wr  : in  STD_LOGIC;                      -- Write товч
        btn_rd  : in  STD_LOGIC;                      -- Read товч
        -- LCD холболт
        lcd_rs  : out STD_LOGIC;
        lcd_rw  : out STD_LOGIC;
        lcd_en  : out STD_LOGIC;
        lcd_d   : out STD_LOGIC_VECTOR(3 downto 0);
        -- DDR холболт
        ddr_a   : out STD_LOGIC_VECTOR(12 downto 0);
        ddr_ba  : out STD_LOGIC_VECTOR(1 downto 0);
        ddr_cas : out STD_LOGIC;
        ddr_ras : out STD_LOGIC;
        ddr_we  : out STD_LOGIC;
        ddr_clk : out STD_LOGIC;
        -- Төлөв LED (4 гэрэл)
        led     : out STD_LOGIC_VECTOR(3 downto 0)
    );
end DDR_LCD;

architecture rtl of DDR_LCD is
    -- ======================================
    -- LCD хянагчийн төлөвүүд
    -- ======================================
    type lcd_state_type is (
        LCD_POWER_ON,      -- Эхлүүлэх
        LCD_INIT,          -- Анхны тохиргоо
        LCD_FUNC_SET1,     -- Функц тохируулах 1
        LCD_FUNC_SET2,     -- Функц тохируулах 2
        LCD_FUNC_SET3,     -- Функц тохируулах 3
        LCD_DISPLAY_ON,    -- Дэлгэц асаах
        LCD_CLEAR,         -- Цэвэрлэх
        LCD_ENTRY_MODE,    -- Оролтын горим
        LCD_READY,         -- Бэлэн
        LCD_WRITE_LINE1,   -- 1-р мөр бичих
        LCD_WRITE_LINE2,   -- 2-р мөр бичих
        LCD_SET_LINE2,     -- 2-р мөрт шилжих
        LCD_DELAY          -- Хүлээх
    );
    signal lcd_state : lcd_state_type := LCD_POWER_ON;
    
    -- ======================================
    -- DDR тестийн төлөвүүд
    -- ======================================
    type ddr_state_type is (
        STATE_IDLE,     -- Хүлээж байна
        STATE_WRITE,    -- Бичиж байна
        STATE_READ,     -- Уншиж байна
        STATE_OK,       -- Амжилттай
        STATE_ERROR     -- Алдаатай
    );
    signal ddr_state : ddr_state_type := STATE_IDLE;
    
    -- ======================================
    -- Дотоод сигналууд
    -- ======================================
    signal clock_divider    : unsigned(19 downto 0) := (others => '0');
    signal lcd_clock        : STD_LOGIC := '0';
    signal delay_count      : unsigned(15 downto 0) := (others => '0');
    signal char_count       : unsigned(4 downto 0) := (others => '0');
    signal lcd_byte         : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal nibble_select    : STD_LOGIC := '0';  -- 0=дээд, 1=доод
    signal btn_write_prev   : STD_LOGIC := '0';
    signal btn_read_prev    : STD_LOGIC := '0';
    signal write_data       : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal read_data        : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    
    -- LCD текст буфер
    type message_array is array (0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    signal lcd_text : message_array;
    
    -- LCD командууд
    constant CMD_CLEAR      : STD_LOGIC_VECTOR(7 downto 0) := X"01";
    constant CMD_FUNC_4BIT  : STD_LOGIC_VECTOR(7 downto 0) := X"28";
    constant CMD_DISPLAY_ON : STD_LOGIC_VECTOR(7 downto 0) := X"0C";
    constant CMD_ENTRY_MODE : STD_LOGIC_VECTOR(7 downto 0) := X"06";
    constant CMD_LINE2      : STD_LOGIC_VECTOR(7 downto 0) := X"C0";

begin
    -- ======================================
    -- LED төлөв индикатор
    -- LED[3] = ERROR
    -- LED[2] = OK
    -- LED[1] = WRITE/READ идэвхтэй
    -- LED[0] = IDLE бэлэн
    -- ======================================
    led(3) <= '1' when ddr_state = STATE_ERROR else '0';
    led(2) <= '1' when ddr_state = STATE_OK else '0';
    led(1) <= '1' when ddr_state = STATE_WRITE or ddr_state = STATE_READ else '0';
    led(0) <= '1' when ddr_state = STATE_IDLE else '0';
    
    ddr_clk <= clk;
    lcd_rw <= '0';  -- Зөвхөн бичих

    -- ======================================
    -- Цагийн хуваагч - LCD-д зориулж
    -- ======================================
    process(clk, rst)
    begin
        if rst = '1' then
            clock_divider <= (others => '0');
            lcd_clock <= '0';
        elsif rising_edge(clk) then
            clock_divider <= clock_divider + 1;
            if clock_divider = 50000 then
                lcd_clock <= '1';
                clock_divider <= (others => '0');
            else
                lcd_clock <= '0';
            end if;
        end if;
    end process;

    -- ======================================
    -- DDR санах ой тест логик
    -- ======================================
    process(clk, rst)
    begin
        if rst = '1' then
            ddr_state <= STATE_IDLE;
            write_data <= (others => '0');
            read_data <= (others => '0');
            btn_write_prev <= '0';
            btn_read_prev <= '0';
            ddr_a <= (others => '0');
            ddr_ba <= "00";
            ddr_cas <= '1';
            ddr_ras <= '1';
            ddr_we <= '1';
        elsif rising_edge(clk) then
            -- Button товших илрүүлэлт
            btn_write_prev <= btn_wr;
            btn_read_prev <= btn_rd;
            
            case ddr_state is
                -- Хүлээж байна
                when STATE_IDLE =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we <= '1';
                    
                    -- Write товч дарагдсан
                    if btn_wr = '1' and btn_write_prev = '0' then
                        write_data <= sw;  -- Switch-ийн утгыг авах
                        ddr_state <= STATE_WRITE;
                    -- Read товч дарагдсан
                    elsif btn_rd = '1' and btn_read_prev = '0' then
                        ddr_state <= STATE_READ;
                    end if;
                    
                -- DDR-д бичиж байна
                when STATE_WRITE =>
                    ddr_a <= (others => '0');
                    ddr_ba <= "00";
                    ddr_ras <= '0';  -- Row Address Strobe
                    ddr_cas <= '0';  -- Column Address Strobe
                    ddr_we <= '0';   -- Write Enable
                    
                    if delay_count < 100 then
                        delay_count <= delay_count + 1;
                    else
                        delay_count <= (others => '0');
                        ddr_state <= STATE_OK;
                    end if;
                    
                -- DDR-с уншиж байна
                when STATE_READ =>
                    ddr_ras <= '0';
                    ddr_cas <= '0';
                    ddr_we <= '1';  -- Read горим
                    
                    if delay_count < 100 then
                        delay_count <= delay_count + 1;
                        read_data <= write_data;  -- Симуляцид бичсэн утгыг буцаана
                    else
                        delay_count <= (others => '0');
                        -- Бичсэн ба унших утга тааруй эсэхийг шалгах
                        if read_data = write_data then
                            ddr_state <= STATE_OK;
                        else
                            ddr_state <= STATE_ERROR;
                        end if;
                    end if;
                    
                -- Амжилттай эсвэл алдаатай
                when STATE_OK | STATE_ERROR =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we <= '1';
                    -- Дахин IDLE төлөвт буцах
                    if btn_wr = '1' and btn_write_prev = '0' then
                        ddr_state <= STATE_IDLE;
                    elsif btn_rd = '1' and btn_read_prev = '0' then
                        ddr_state <= STATE_IDLE;
                    end if;
            end case;
        end if;
    end process;

    -- ======================================
    -- LCD текст бэлтгэх
    -- ======================================
    process(clk)
        variable hex_digit : unsigned(3 downto 0);
    begin
        if rising_edge(clk) then
            -- 1-р мөр: "DDR TEST: [төлөв]"
            lcd_text(0) <= X"44";  -- D
            lcd_text(1) <= X"44";  -- D
            lcd_text(2) <= X"52";  -- R
            lcd_text(3) <= X"20";  -- хоосон зай
            lcd_text(4) <= X"54";  -- T
            lcd_text(5) <= X"45";  -- E
            lcd_text(6) <= X"53";  -- S
            lcd_text(7) <= X"54";  -- T
            lcd_text(8) <= X"3A";  -- :
            lcd_text(9) <= X"20";  -- хоосон зай
            
            -- Төлөв харуулах
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
                    lcd_text(14) <= X"20";  -- хоосон зай
                when STATE_OK =>
                    lcd_text(10) <= X"4F";  -- O
                    lcd_text(11) <= X"4B";  -- K
                    lcd_text(12) <= X"20";  -- хоосон зай
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
            
            -- 2-р мөр: "WR:X RD:Y"
            lcd_text(16) <= X"57";  -- W
            lcd_text(17) <= X"52";  -- R
            lcd_text(18) <= X"3A";  -- :
            
            -- Write утга (hex)
            hex_digit := unsigned(write_data);
            if hex_digit < 10 then
                lcd_text(19) <= std_logic_vector(X"30" + hex_digit);  -- 0-9
            else
                lcd_text(19) <= std_logic_vector(X"37" + hex_digit);  -- A-F
            end if;
            
            lcd_text(20) <= X"20";  -- хоосон зай
            lcd_text(21) <= X"52";  -- R
            lcd_text(22) <= X"44";  -- D
            lcd_text(23) <= X"3A";  -- :
            
            -- Read утга (hex)
            hex_digit := unsigned(read_data);
            if hex_digit < 10 then
                lcd_text(24) <= std_logic_vector(X"30" + hex_digit);
            else
                lcd_text(24) <= std_logic_vector(X"37" + hex_digit);
            end if;
            
            -- Үлдсэн хэсэг хоосон
            for i in 25 to 31 loop
                lcd_text(i) <= X"20";
            end loop;
        end if;
    end process;

    -- ======================================
    -- LCD хянагч (4-bit горим)
    -- ======================================
    process(clk, rst)
    begin
        if rst = '1' then
            lcd_state <= LCD_POWER_ON;
            lcd_rs <= '0';
            lcd_en <= '0';
            lcd_d <= "0000";
            delay_count <= (others => '0');
            char_count <= (others => '0');
            nibble_select <= '0';
        elsif rising_edge(clk) then
            if lcd_clock = '1' then
                case lcd_state is
                    -- Эхлүүлэх хүлээлт
                    when LCD_POWER_ON =>
                        lcd_en <= '0';
                        lcd_rs <= '0';
                        if delay_count < 1000 then
                            delay_count <= delay_count + 1;
                        else
                            delay_count <= (others => '0');
                            lcd_state <= LCD_INIT;
                        end if;
                        
                    -- Анхны тохиргоо
                    when LCD_INIT =>
                        lcd_rs <= '0';
                        lcd_d <= "0011";
                        lcd_en <= '1';
                        if delay_count < 10 then
                            delay_count <= delay_count + 1;
                        else
                            lcd_en <= '0';
                            delay_count <= (others => '0');
                            lcd_state <= LCD_FUNC_SET1;
                        end if;
                        
                    -- 4-bit горим тохируулах
                    when LCD_FUNC_SET1 =>
                        lcd_rs <= '0';
                        lcd_d <= "0010";
                        lcd_en <= '1';
                        if delay_count < 10 then
                            delay_count <= delay_count + 1;
                        else
                            lcd_en <= '0';
                            delay_count <= (others => '0');
                            lcd_state <= LCD_FUNC_SET2;
                            lcd_byte <= CMD_FUNC_4BIT;
                            nibble_select <= '0';
                        end if;
                        
                    -- Функц тохируулах команд илгээх
                    when LCD_FUNC_SET2 =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_count < 5 then
                                delay_count <= delay_count + 1;
                            else
                                lcd_en <= '0';
                                delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_FUNC_SET3;
                            end if;
                        end if;
                        
                    when LCD_FUNC_SET3 =>
                        lcd_en <= '0';
                        if delay_count < 10 then
                            delay_count <= delay_count + 1;
                        else
                            delay_count <= (others => '0');
                            lcd_state <= LCD_DISPLAY_ON;
                            lcd_byte <= CMD_DISPLAY_ON;
                            nibble_select <= '0';
                        end if;
                        
                    -- Дэлгэц асаах
                    when LCD_DISPLAY_ON =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_count < 5 then
                                delay_count <= delay_count + 1;
                            else
                                lcd_en <= '0';
                                delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_CLEAR;
                                lcd_byte <= CMD_CLEAR;
                            end if;
                        end if;
                        
                    -- Дэлгэц цэвэрлэх
                    when LCD_CLEAR =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_count < 100 then
                                delay_count <= delay_count + 1;
                            else
                                lcd_en <= '0';
                                delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_ENTRY_MODE;
                                lcd_byte <= CMD_ENTRY_MODE;
                            end if;
                        end if;
                        
                    -- Entry mode тохируулах
                    when LCD_ENTRY_MODE =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_count < 5 then
                                delay_count <= delay_count + 1;
                            else
                                lcd_en <= '0';
                                delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_READY;
                                char_count <= (others => '0');
                            end if;
                        end if;
                        
                    -- Бэлэн
                    when LCD_READY =>
                        lcd_en <= '0';
                        char_count <= (others => '0');
                        lcd_state <= LCD_WRITE_LINE1;
                        
                    -- 1-р мөр бичих
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
                                if delay_count < 3 then
                                    delay_count <= delay_count + 1;
                                else
                                    lcd_en <= '0';
                                    delay_count <= (others => '0');
                                    nibble_select <= '0';
                                    char_count <= char_count + 1;
                                end if;
                            end if;
                        else
                            char_count <= (others => '0');
                            lcd_state <= LCD_SET_LINE2;
                            lcd_byte <= CMD_LINE2;
                        end if;
                        
                    -- 2-р мөрт шилжих
                    when LCD_SET_LINE2 =>
                        lcd_rs <= '0';
                        if nibble_select = '0' then
                            lcd_d <= lcd_byte(7 downto 4);
                            lcd_en <= '1';
                            nibble_select <= '1';
                        else
                            lcd_d <= lcd_byte(3 downto 0);
                            lcd_en <= '1';
                            if delay_count < 5 then
                                delay_count <= delay_count + 1;
                            else
                                lcd_en <= '0';
                                delay_count <= (others => '0');
                                nibble_select <= '0';
                                lcd_state <= LCD_WRITE_LINE2;
                            end if;
                        end if;
                        
                    -- 2-р мөр бичих
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
                                if delay_count < 3 then
                                    delay_count <= delay_count + 1;
                                else
                                    lcd_en <= '0';
                                    delay_count <= (others => '0');
                                    nibble_select <= '0';
                                    char_count <= char_count + 1;
                                end if;
                            end if;
                        else
                            lcd_state <= LCD_DELAY;
                            char_count <= (others => '0');
                        end if;
                        
                    -- Шинэчлэх хүлээлт
                    when LCD_DELAY =>
                        lcd_en <= '0';
                        if delay_count < 5000 then
                            delay_count <= delay_count + 1;
                        else
                            delay_count <= (others => '0');
                            lcd_state <= LCD_READY;
                        end if;
                end case;
            end if;
        end if;
    end process;

end rtl;
