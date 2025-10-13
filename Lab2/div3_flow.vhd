library IEEE;
use IEEE.std_logic_1164.all;

entity div3_flow is
 port ( N : in std_logic_vector(3 downto 0);
	F : out std_logic);
end div3_flow;

architecture div3_arch_datafl of div3_flow is
begin
 with N select
 F <= '1' when "0011",
	'1' when "0110",
	'1' when "1001",
	'1' when "1100",
	'1' when "1111",
	'0' when others;
end div3_arch_datafl;
