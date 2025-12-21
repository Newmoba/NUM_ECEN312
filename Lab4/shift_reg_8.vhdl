library IEEE;
use IEEE.std_logic_1164.all;

entity shift_reg_8 is
    port(
        clk, clear : in std_logic;
        Select_func : in std_logic_vector(2 downto 0);
        D : in std_logic_vector(7 downto 0);
        SI_left : in std_logic;   -- for right shift
        SI_right : in std_logic;  -- for left shift
        Q : out std_logic_vector(7 downto 0)
    );
end shift_reg_8;

architecture behavioral of shift_reg_8 is
    signal Q_i : std_logic_vector(7 downto 0);
begin
    process(clk, clear)
    begin
        if clear = '0' then
            Q_i <= (others => '0');
        elsif (clk'event and clk='1') then
            case Select_func is
                when "000" =>  
		-- Hold
                    Q_i <= Q_i;
                when "001" =>  
		-- Load
                    Q_i <= D;              
                when "010" =>  
		-- Shift right
                    Q_i <= SI_left & Q_i(7 downto 1);              
                when "011" =>  
		-- Shift left
                    Q_i <= Q_i(6 downto 0) & SI_right;              
                when "100" =>  
		-- Shift circular right
                    Q_i <= Q_i(0) & Q_i(7 downto 1);              
                when "101" =>  
		-- Shift circular left
                    Q_i <= Q_i(6 downto 0) & Q_i(7);              
                when "110" =>  
		-- Shift arithmetic right
                    Q_i <= Q_i(7) & Q_i(7 downto 1);              
                when "111" =>  
		-- Shift arithmetic left
                    Q_i <= Q_i(6 downto 0) & '0';              
                when others =>
                    Q_i <= Q_i;
            end case;
        end if;
    end process;
    Q <= Q_i;
end behavioral;
