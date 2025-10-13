library IEEE;
use IEEE.std_logic_1164.all;

entity div3_tb is
end div3_tb;

architecture div3_tb_arch of div3_tb is

component div3_behav port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;
component div3_flow port ( N: in std_logic_vector(3 downto 0);   
			F: out std_logic);
end component;
component div3_struc port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;
component div3_dataflow port ( N: in std_logic_vector(3 downto 0);
			F: out std_logic);
end component;


signal NT: std_logic_vector(3 downto 0);
signal FT1, FT2, FT3, FT4: std_logic;
begin
 UU1: div3_behav port map (NT, FT1);
 UU2: div3_flow port map (NT, FT2);
 UU3: div3_struc port map (NT, FT3);
 UU4: div3_dataflow port map(NT, FT4);
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
end div3_tb_arch;
