library IEEE;
use IEEE.std_logic_1164.all;

entity prime2 is
 port (N: in std_logic_vector (3 downto 0);
	F : out std_logic);
end prime2;

architecture prime1_arch_datafl of prime2 is
begin
 with N select
  F <= '1' when "0001",
	'1' when "0010",
	'1' when "0011" | "0101" | "0111",
	'1' when "1011" | "1101",
	'0' when others;
end prime1_arch_datafl;
