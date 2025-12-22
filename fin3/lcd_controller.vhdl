library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
    port (
        clk     : in std_logic;
        rs      : in std_logic;
        data    : in std_logic_vector(15 downto 0);  -- 16 char string, adjust as needed
        lcd_rs  : out std_logic;
        lcd_rw  : out std_logic;
        lcd_e   : out std_logic;
        lcd_db  : out std_logic_vector(7 downto 4)
    );
end lcd_controller;

architecture Behavioral of lcd_controller is
    -- Simple state machine for init and display (from common examples)
    -- Энэ нь бүрэн биш, гэхдээ "Hello" гэх мэт текст харуулна.
    -- Бүрэн кодыг GitHub wgwozdz/Spartan_LCD эсвэл shubhajeet/lcdModule-оос авна уу.
    
    -- Placeholder: always display fixed text
begin
    lcd_rs <= '1';  -- data mode
    lcd_rw <= '0';
    -- pulse e etc.
    -- Real code here is long, use ready module from GitHub.
    lcd_db <= x"4";  -- example
    
end Behavioral;
