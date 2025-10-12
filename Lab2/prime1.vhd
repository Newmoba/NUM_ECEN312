library IEEE;
use IEEE.std_logic_1164.all;

entity prime1 is
 port ( N : in std_logic_vector (3 downto 0);
	F : out std_logic);
end prime1;

architecture prime_arch_struct of prime1 is
signal N3_L, N2_L, N1_L : std_logic;
signal N3L_N0, N3L_N2L_N1, N2L_N1_N0, N2_N1L_N0 : std_logic;
component INV port( In1: in std_logic; Out1: out std_logic);
end component;
component AND2 port(In1, In2: in std_logic; Out1: out std_logic);
end component;
component AND3 port(In1, In2, In3: in std_logic; Out1: out std_logic);
end component;
component OR4 port(In1,In2,In3,In4: in std_logic; Out1: out std_logic);
end component;

begin
 U1: INV port map (N(3), N3_L);
 U2: INV port map (N(2), N2_L);
 U3: INV port map (N(1), N1_L);
 U4: AND2 port map (N3_L, N(0), N3L_N0);
 U5: AND3 port map (N3_L, N2_L, N(1), N3L_N2L_N1);
 U6: AND3 port map (N2_L, N(1), N(0), N2_N1L_N0);
 U7: AND3 port map (N(2), N1_L, N(0), N2_N1L_N0);
 U8: OR4 port map (N3L_N0, N3L_N2L_N1, N2L_N1_N0, N2_N1L_N0, F);
end prime_arch_struct;
