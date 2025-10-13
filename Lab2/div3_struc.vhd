library IEEE;
use IEEE.std_logic_1164.all;

entity div3_struc is
 port ( N : in std_logic_vector (3 downto 0);
	F: out std_logic);
end div3_struc;

architecture div3_struc_arch of div3_struc is
signal N0_L, N1_L, N2_L, N3_L : std_logic;
signal P1, P2, P3, P4, P5 : std_logic;
component INV port( In1: in std_logic; Out1: out std_logic);
end component;
component OR5 port(In1,In2,In3,In4,In5: in std_logic; Out1: out std_logic);
end component;
component AND4 port(In1,In2,In3,In4: in std_logic; Out1: out std_logic);
end component;

begin
 U1: INV port map (N(3), N3_L);
 U2: INV port map (N(2), N2_L);
 U3: INV port map (N(1), N1_L);
 U4: INV port map (N(0), N0_L);
 U5: AND4 port map (N(0), N(1), N2_L, N3_L, P1);
 U6: AND4 port map (N(0), N1_L, N2_L, N(3), P2);
 U7: AND4 port map (N(0),N(1),N(2), N(3), P3);
 U8: AND4 port map (N0_L, N(1),N(2),N3_L, P4);
 U9: AND4 port map (N0_l, N1_l, N(2), N(3), P5);
 U10: OR5 port map (P1,P2,P3,P4,P5, F);
end div3_struc_arch;
