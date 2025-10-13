library IEEE;
use IEEE.std_logic_1164.all;

entity AND4 is
    port (In1, In2, In3, In4 : in  std_logic;
        Out1     : out std_logic);
end AND4;
architecture AND4_arch of AND4 is
begin
    Out1 <= In1 and In2 and In3 and In4;
end AND4_arch;

