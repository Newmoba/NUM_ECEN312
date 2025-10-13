library IEEE;
use IEEE.std_logic_1164.all;

entity OR5 is
    port (In1, In2, In3, In4, In5 : in  std_logic;
        Out1     : out std_logic);
end OR5;
architecture OR5_arch of OR5 is
begin
    Out1 <= In1 OR In2 OR In3 OR In4 OR In5;
end OR5_arch;

