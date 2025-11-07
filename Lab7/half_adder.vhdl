library IEEE;
use IEEE.std_logic_1164.all;

entity half_adder is
  port(x, y: in std_logic;
       s, c: out std_logic);
end half_adder;

architecture dataflow_3 of half_adder is
  begin
    s<= x xor y;
    c<= x and y;
end dataflow_3;
