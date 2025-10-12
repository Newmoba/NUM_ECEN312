library IEEE;
use IEEE.std_logic_1164.all;

entity prime_tb is
end prime_tb;

architecture prime_tb_arch of prime_tb is

component prime1 port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;
component prime2 port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;
component prime3 port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;
component prime4 port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;

signal NT: std_logic_vector(3 downto 0);
signal FT1, FT2, FT3, FT4: std_logic;
begin
 UU1: prime1 port map (NT, FT1);
 UU2: prime2 port map (NT, FT2);
 UU3: prime3 port map (NT, FT3);
 UU4: prime4 port map (NT, FT4);
 process
 begin
  NT <= "0000";
  wait for 10ns;
  NT <= "0001";
  wait for 10ns;
  NT <= "0010";
  wait for 10ns;
  NT <= "0011";
  wait for 10ns;
  NT <= "0100";
  wait for 10ns;
  NT <= "0101";
  wait for 10ns;
  NT <= "0110";
  wait for 10ns;
  NT <= "0111";
  wait for 10ns;
  NT <= "1000";
  wait for 10ns;
  NT <= "1001";
  wait for 10ns;
  NT <= "1010";
  wait for 10ns;
  NT <= "1011";
  wait for 10ns;
  NT <= "1100";
  wait for 10ns;
  NT <= "1101";
  wait for 10ns;
  NT <= "1110";
  wait for 10ns;
  NT <= "1111";
  wait for 10ns;
  wait;
 end process;
end prime_tb_arch;


  
