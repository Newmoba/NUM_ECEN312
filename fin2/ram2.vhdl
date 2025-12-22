library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DDR_WR_RD_TEST is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        sw       : in  STD_LOGIC_VECTOR(3 downto 0); -- Оролтын 4 тоо
        btn_wr   : in  STD_LOGIC;                   -- Бичих товч
        btn_rd   : in  STD_LOGIC;                   -- Унших товч
        led      : out STD_LOGIC_VECTOR(3 downto 0)  -- Гаралтын 4 LED
    );
end DDR_WR_RD_TEST;

architecture rtl of DDR_WR_RD_TEST is
    -- Дотоод санах ой (утгыг хадгалах регистр)
    signal memory_reg  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    -- Товчлуурын өмнөх төлөв (ирмэг илрүүлэхэд)
    signal btn_wr_prev : STD_LOGIC := '0';
    signal btn_rd_prev : STD_LOGIC := '0';
begin

    process(clk, rst)
    begin
        if rst = '1' then
            memory_reg <= (others => '0');
            led <= (others => '0');
            btn_wr_prev <= '0';
            btn_rd_prev <= '0';
        elsif rising_edge(clk) then
            -- 1. Товч дарагдсан эсэхийг шалгах (Edge Detection)
            btn_wr_prev <= btn_wr;
            btn_rd_prev <= btn_rd;

            -- 2. WRITE үйлдэл: Write товч дарахад Switch-ийн утгыг memory_reg-д хадгална
            if btn_wr = '1' and btn_wr_prev = '0' then
                memory_reg <= sw;
            end if;

            -- 3. READ үйлдэл: Read товч дарахад memory_reg-д байгаа утгыг LED-д гаргана
            if btn_rd = '1' and btn_rd_prev = '0' then
                led <= memory_reg;
            end if;
        end if;
    end process;

end rtl;
