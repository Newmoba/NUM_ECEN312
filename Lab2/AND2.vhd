library IEEE;
use IEEE.std_logic_1164.all;

entity AND2 is
 port (In1, In2 : in std_logic;
 	Out1	: out std_logic);
end AND2;

architecture AND2_arch of AND2 is
begin
    Out1 <= In1 and In2;
end AND2_arch;
