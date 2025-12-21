library IEEE;
use IEEE.std_logic_1164.all;
entity seq_rec is
	port(clk, reset, X: in std_logic;
			Z : out std_logic);
end seq_rec;
architecture process_3 of seq_rec is
	type state_type is (A,B,C,D);
	signal state, next_state : state_type;
begin
--process1: Async reset, positive front triggered state saving
 state_register: process (clk, reset)
  begin
   if (reset='1') then
    state <= A;
   elsif (clk'event and clk='1') then
    state <= next_state;
   end if;
  end process;
--process2: next_state iig X bolon state iin funkts baihaar guitsetgene
 next_state_func: process (X, state)
  begin
   case state is
    when A=>
     if X='1' then next_state <=B;
     else next_state <=A;
     end if;
    when B=>
     if X='1' then next_state <=C;
      else next_state <=A;
     end if;
    when C=>
     if X='1' then next_state <=C;
      else next_state <=D;
     end if;
    when D=>
     if X='1' then next_state <= B;
      else next_state <= A;
     end if;
    end case;
 end process;
--process3: garaltiig X orolt ba state-iin funkts baihaar
 output_func: process (X, state)
  Begin
   case state is
    when A=> Z<='0';
    when B=> Z<='0';
    when C=> Z<='0';
    when D=>
     if X='1' then Z<='1';
     else Z<='0';
     end if;
   end case;
  end process;
end;
