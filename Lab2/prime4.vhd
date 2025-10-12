library IEEE;
use IEEE.std_logic_1164.all;

entity prime4 is
 port ( N: in std_logic_vector(3 downto 0);
	F: out std_logic);
end prime4;

architecture prime_arch_beh of prime4 is

function CONV_INTEGER (X: std_logic_vector) return INTEGER is
 variable RESULT: integer;
 begin
  RESULT:=0;
  for i in X'range loop
   RESULT := RESULT * 2;
   case X(i) is
    when '0' | 'L' => null;
    when '1' | 'H' => RESULT := RESULT + 1;
    when others => null;
   end case;
  end loop;
 return RESULT;
end CONV_INTEGER;

begin
 process(N)
  variable NI: integer;
  begin
   NI := CONV_INTEGER(N);
   if NI=1 OR NI=2 THEN F<='1';
   elsif NI=3 OR NI=5 OR NI=7 OR NI=11 OR NI=13 THEN F<='1';
   else F<='0';
   end if;
 end process;
end prime_arch_beh;
