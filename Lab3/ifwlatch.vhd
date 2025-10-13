library IEEE;
use IEEE.std_logic_1164.all;

entity ifwlatch is
port( input1 : in std_logic;
	input2 : in std_logic;
	input3 : in std_logic;
	input4 : in std_logic;
	selector: in std_logic_vector(1 downto 0);
	output1: out std_logic);
end ifwlatch;

architecture ifwl_arch of ifwlatch is
 signal internal : std_logic :='0';
 begin
  process(input1, input2, input3, input4, selector)
  begin
   if (selector="00") then
    internal <= input1;
   elsif (selector="01") then
    internal <= input2;
   elsif (selector="10") then
    internal <= input3;
   end if;
  end process;
  output1 <= internal;
end ifwl_arch;
