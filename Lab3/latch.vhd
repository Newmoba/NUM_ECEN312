library IEEE;
use IEEE.std_logic_1164.all;

entity latch is
port( data_in : in std_logic;
	clock : in std_logic;
	data_out: out std_logic);
end latch;

architecture latch_arch of latch is
 begin
  process (data_in, clock)
  begin
   if (clock='1') then
    data_out <= data_in;
   end if;
  end process;
end latch_arch;
