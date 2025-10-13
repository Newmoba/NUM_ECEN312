library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;  --integer conversion function

entity div3_behav is
 port ( N : in  std_logic_vector(3 downto 0);
        F : out std_logic);
end div3_behav;

architecture behavioral of div3_behav is
 signal NI : integer range 0 to 15;
begin
 NI <= to_integer(unsigned(N));
  process(NI)
    begin
     if (NI mod 3 = 0) then
            F <= '1';
        else
            F <= '0';
        end if;
    end process;
end behavioral;
