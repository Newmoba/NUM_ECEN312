library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port ( 
        clk       : in  STD_LOGIC;                      -- 50MHz Clock
        sw        : in  STD_LOGIC_VECTOR (3 downto 0);  -- 4 Switches
        btn_write : in  STD_LOGIC;                      -- BTN_NORTH
        btn_read  : in  STD_LOGIC;                      -- BTN_SOUTH
        -- LCD Pins
        lcd_rs    : out STD_LOGIC;
        lcd_rw    : out STD_LOGIC;
        lcd_e     : out STD_LOGIC;
        sf_d      : out STD_LOGIC_VECTOR (11 downto 8);
        -- Disable other peripherals sharing the bus
        sf_ce0    : out STD_LOGIC
    );
end top_module;

architecture Behavioral of top_module is
    -- Internal signals
    signal stored_val : std_logic_vector(3 downto 0) := "0000";
    signal display_val : std_logic_vector(3 downto 0) := "0000";
    signal timer      : integer range 0 to 1000000 := 0;
    signal lcd_state  : integer range 0 to 10 := 0;
    
begin
    -- 1. Цахилгаан шугамыг чөлөөлөх (Flash-ийг идэвхгүй болгох)
    sf_ce0 <= '1'; 
    lcd_rw <= '0'; -- Үргэлж бичих горим

    -- 2. Хадгалах болон Унших логик
    process(clk)
    begin
        if rising_edge(clk) then
            if btn_write = '1' then
                stored_val <= sw; -- "SDRAM" руу бичиж байна гэж үзэх (BRAM/Register)
            end if;
            
            if btn_read = '1' then
                display_val <= stored_val; -- Хадгалсан утгыг гаргах
            end if;
        end if;
    end process;

    -- 3. LCD State Machine (Хялбаршуулсан 4-bit горим)
    -- Анхааруулга: LCD-ийг бүрэн асаахад маш нарийн тайминг хэрэгтэй.
    -- Энэ хэсэгт зөвхөн Switch-ний утгыг LCD-ийн дата руу дамжуулж байна.
    process(clk)
    begin
        if rising_edge(clk) then
            timer <= timer + 1;
            if timer = 1000000 then -- Ойролцоогоор 20ms тутамд шинэчлэх
                timer <= 0;
                
                -- Энгийн тест: Switch-ний утгыг шууд LCD-ийн LED мэт ашиглах
                -- LCD-г бүрэн ажиллуулахын тулд доорх Image-ийг харна уу.
                lcd_e <= not lcd_e; 
                lcd_rs <= '1';
                sf_d <= display_val; 
            end if;
        end if;
    end process;

end Behavioral;
