library IEEE;
use IEEE.std_logic_1164.all;
entity testbench is
end testbench;

architecture tb_arch of testbench is
component mux2to1
 port (A, B, S : in  std_logic;
      	Z : out std_logic);
end component;
signal AT, BT, ST, ZT : std_logic;
begin
 U1: mux2to1 port map (AT,BT,ST,ZT);
 process
  begin
    AT <= '0'; BT <= '0'; ST <= '0';
    wait for 100 ns;
    AT <= '1'; BT <= '0'; ST <= '0';
    wait for 100 ns;
    AT <= '1'; BT <= '1'; ST <= '0';
    wait for 100 ns;
    AT <= '0'; BT <= '1'; ST <= '0';
    wait for 100 ns;
    AT <= '0'; BT <= '0'; ST <= '1';
    wait for 100 ns;
    AT <= '1'; BT <= '0'; ST <= '1';
    wait for 100 ns;
    AT <= '1'; BT <= '1'; ST <= '1';
    wait for 100 ns;
    AT <= '0'; BT <= '1'; ST <= '1';
    wait;
  end process;
end tb_arch;
