library IEEE;
use IEEE.std_logic_1164.all;

entity div3_dataflow is
 port ( N: in std_logic_vector(3 downto 0);
	F: out std_logic);
end div3_dataflow;

architecture div3_dataflow_arch of div3_dataflow is
signal P1, P2, P3, P4, P5: std_logic;
begin
 P1 <='1' when N(0)='1' and N(1)='1' and N(2)='0' and N(3)='0' else '0';
 P2 <='1' when N(0)='1' and N(1)='0' and N(2)='0' and N(3)='1' else '0';
 P3 <='1' when N(0)='1' and N(1)='1' and N(2)='1' and N(3)='1' else '0';
 P4 <='1' when N(0)='0' and N(1)='1' and N(2)='1' and N(3)='0' else '0';
 P5 <='1' when N(0)='0' and N(1)='0' and N(2)='1' and N(3)='1' else '0';
 F <=P1 OR P2 OR P3 OR P4 OR P5;
end div3_dataflow_arch;
