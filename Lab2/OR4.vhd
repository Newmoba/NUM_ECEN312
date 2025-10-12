library IEEE;
use IEEE.std_logic_1164.all;

entity OR4 is
 port (In1, In2, In3, In4 : in  std_logic;
	Out1		: out std_logic);
end OR4;

architecture OR4_arch of OR4 is
begin
    Out1 <= In1 or In2 or In3 or In4;
end OR4_arch;
