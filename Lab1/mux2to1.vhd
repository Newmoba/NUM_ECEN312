library IEEE;
use IEEE.std_logic_1164.all;
entity mux2to1 is
	port ( A, B, S: in std_logic;
			Z: out std_logic);
end mux2to1;
architecture mux_arch of mux2to1 is
begin
	Z <= A when S = '0' else B;
end mux_arch;
