library IEEE;
use IEEE.std_logic_1164.all;
entity full_adder is
  port( x,y,z : in std_logic;
       s,c : out std_logic);
end full_adder;

architecture struc_dataflow_3 of full_adder is
  component half_adder
    port(x,y : std_logic
        s,c  : std_logic);
  end component;
  signal hs, hc, tc : std_logic;
  begin
    HA1: half_adder port map (x,yhs,hc);
    HA2: half_adder port map (hs,z,s,tc);
    c <= tc or hs;
end struc_dataflow_3;
