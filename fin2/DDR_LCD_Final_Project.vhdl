library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DDR_LCD_Final_Project is
    Port (
        clk_50mhz : in  STD_LOGIC;
        btn_write : in  STD_LOGIC;  -- BTN_SOUTH (K17)
        btn_read  : in  STD_LOGIC;  -- BTN_NORTH (V4)
        sw        : in  STD_LOGIC_VECTOR (3 downto 0); -- SW0-SW3
        
        -- LCD Pins
        lcd_rs    : out STD_LOGIC;
        lcd_rw    : out STD_LOGIC;
        lcd_e     : out STD_LOGIC;
        sf_d      : out STD_LOGIC_VECTOR (11 downto 8); -- LCD Data
        
        -- LED (Шууд хянах зориулалттай)
        led       : out STD_LOGIC_VECTOR (3 downto 0)
    );
end DDR_LCD_Final_Project;

architecture Behavioral of DDR_LCD_Final_Project is

    -- Дотоод сигналууд
    signal stored_data : std_logic_vector(3 downto 0) := "0000";
    signal read_data   : std_logic_vector(3 downto 0) := "0000";
    signal match       : std_logic := '0';
    signal state       : integer := 0; -- 0: Testing, 1: Pass, 2: Fail
    
    -- LCD удирдлагын туслах сигнал
    signal timer       : integer := 0;
    signal lcd_init_ok : std_logic := '0';

begin
    lcd_rw <= '0'; -- Үргэлж бичих горим
    led <= read_data; -- Уншсан утгаа LED дээр харуулна

    -- Үндсэн логик: Бичих болон Унших процесс
    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            -- БИЧИХ: Товчлуур дарахад Switch-ийн утгыг санах ойд (stored_data) хадгална
            if btn_write = '1' then
                stored_data <= sw;
            end if;
            
            -- УНШИХ: Товчлуур дарахад санах ойноос (stored_data) авч read_data-д хадгална
            if btn_read = '1' then
                read_data <= stored_data;
                -- Хэрэв уншсан утга анх бичсэн утгатай таарвал
                if stored_data = sw then 
                    match <= '1'; -- PASS
                else
                    match <= '0'; -- FAIL
                end if;
            end if;
        end if;
    end process;

    -- LCD Драйверын хэсэг (Маш энгийн хэлбэрээр)
    process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            timer <= timer + 1;
            
            -- LCD-ийг эхлүүлэх ба текст гаргах (Таймер дээр суурилсан)
            if timer < 1000000 then   -- 0-20ms: Хүлээх
                lcd_e <= '0';
            elsif timer < 2000000 then -- Init
                lcd_rs <= '0'; lcd_db_tmp <= "0011"; lcd_e <= '1';
            elsif timer < 3000000 then
                lcd_e <= '0';
            else
                -- Текст гаргах логик (Match-аас хамаарч өөрчлөгдөнө)
                lcd_rs <= '1';
                if match = '1' then
                    -- "PASS" гэж бичих команд (ASCII)
                    -- Энд жинхэнэ LCD Controller-ын код орох ёстой
                end if;
            end if;
        end if;
    end process;

end Behavioral;
