library IEEE;
use IEEE.std_logic_1164.all;

entity INV is
 port ( In1  : in  std_logic;
        Out1 : out std_logic);
end INV;

architecture INV_arch of INV is
begin
    Out1 <= not In1;
end INV_arch;
