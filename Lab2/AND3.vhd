library IEEE;
use IEEE.std_logic_1164.all;

entity AND3 is
 port (In1, In2, In3 : in  std_logic;
	Out1	     : out std_logic);
end AND3;

architecture AND3_arch of AND3 is
begin
    Out1 <= In1 and In2 and In3;
end AND3_arch;
