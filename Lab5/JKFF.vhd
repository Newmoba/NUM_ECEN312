library IEEE;
use IEEE.std_logic_1164.all;
entity JKFF is
port( clk, RST_n, J,K : in std_logic;
	Q, Qn 	: out std_logic);
end JKFF;
architecture RTL of JKFF is
 signal FF :std_logic:='0';
begin
 process (clk, RST_n)
  variable JK : std_logic_vector(1 downto 0);
 begin
  if (RST_n='0') then
   FF <= '0';
  elsif (clk'event and clk='1') then
   JK := J & K;
   case JK is
    when "01" => FF <= '0';
    when "10" => FF <= '1';
    when "11" => FF <= not FF;
    when others => FF <= FF;
   end case;
  end if;
 end process;
 Q <= FF after 1 ns;
 Qn <= not FF after 1ns;
end RTL; 
