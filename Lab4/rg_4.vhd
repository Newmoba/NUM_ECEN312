library IEEE;
use IEEE.std_logic_1164.all;
entity rg_4 is
	port(clk, clear: in std_logic;
	D : in std_logic_vector(3 downto 0);
	Q : out std_logic_vector(3 downto 0));
end rg_4;

architecture behavioral of rg_4 is
signal Q_i : std_logic_vector(3 downto 0);
begin
 process(clk, clear)
  begin
   if clear='0' then Q_i <= (others => '0');
   elsif (clk' event and clk='1') then Q_i <=D;
   end if;
  Q <= Q_i;
 end process;
end behavioral;
