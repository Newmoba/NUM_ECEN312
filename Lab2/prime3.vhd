library IEEE;
use IEEE.std_logic_1164.all;

entity prime3 is
  port (N: in std_logic_vector(3 downto 0);
	F: out std_logic);
end prime3;

architecture prime2_arch_datafl of prime3 is
signal N3L_N0, N3L_N2L_N1, N2L_N1_N0, N2_N1L_N0: std_logic;
begin
 N3L_N0	    <='1' when N(3)='0' and N(0)='1' else '0';
 N3L_N2L_N1 <='1' when N(2)='0' and N(2)='0' AND N(1)='1' else '0';
 N2L_N1_N0 <= '1' when N(2)='1' and N(1)='1' AND N(1)='0' else '0';
 N2_N1L_N0 <= '1' when N(2)='1' and N(1)='0' AND N(0)='1' else '0';
 F <= N3L_N0 or N3L_N2L_N1 or N2L_N1_N0 or N2_N1L_N0;
end prime2_arch_datafl;
