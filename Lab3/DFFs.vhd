library IEEE;
use IEEE.std_logic_1164.all;

entity DFFs is
port( D, clock, reset, enable : in std_logic;
	Q1, Q2, Q3, Q4 : out std_logic);
end DFFs;

architecture dff_behav of DFFs is
 begin
  process (clock)
  begin
   if (clock'event and clock='1') then
    Q1 <= D;
   end if;
  end process;
 
  process (clock)
  begin
   if (clock'event and clock='1') then
    if reset='1' then
     Q2 <='0';
    else
     Q2 <=D;
    end if;
   end if;
  end process;

  process (clock, reset)
  begin
   if reset='1' then
    Q3 <= '0';
   elsif (clock'event and clock='1') then
    Q3 <= D;
   end if;
  end process;

  process (clock, reset)
  begin
   if reset='1' then
    Q4 <= '0';
   elsif (clock'event and clock='1') then
    if enable='1' then
     Q4 <= D;
    end if;
   end if;
  end process;
end dff_behav;


    
