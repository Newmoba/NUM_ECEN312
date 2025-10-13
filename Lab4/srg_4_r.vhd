library IEEE;
use IEEE.std_logic_1164.all;
entity srg_4_r is 
 port(clk, RESET, SI : in std_logic;
	Q: out std_logic_vector(3 downto 0);
	SO: out std_logic);
end srg_4_r;

architecture behavioral of srg_4_r is
signal shift: std_logic_vector(3 downto 0);
begin
process (RESET, clk)
begin
 if (RESET='1') then
  shift <= "0000";
 elsif (clk'event and (clk='1')) then
  shift <= shift(2 downto 0) & SI;
 end if;
end process;
 Q <= shift;
 SO <= shift(3);
end behavioral;
--changed the CLK to clk so it can work with the other clock in one testbench
