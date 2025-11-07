library IEEE;
use IEEE.std_logic_1164.all;
entity adder_8 is
  port (B,A : in std_logic_vector (7 downto 0);
        c0 : in std_logic;
        A : out std_logic_vector (7 downto 0);
        C8 : out std_logic);
end adder_8;
architecture structural_8 of adder_8 is
  component full_adder
    port(x,y,z : in std_logic;
         s,c : out std_logic);
  end component;
  signal C: std_logic_vector(8 downto 0);
  begin
    Bit0: full_adder port map (B(0), A(0), C(0), S(0), C(1));
    Bit1: full_adder port map (B(1), A(1), C(1), S(1), C(2));
    Bit2: full_adder port map (B(2), A(2), C(2), S(2), C(3));
    Bit3: full_adder port map (B(3), A(3), C(3), S(3), C(4));
    Bit4: full_adder port map (B(4), A(4), C(4), S(4), C(5));
    Bit5: full_adder port map (B(5), A(5), C(5), S(5), C(6));
    Bit6: full_adder port map (B(6), A(6), C(6), S(6), C(7));
    Bit7: full_adder port map (B(7), A(7), C(7), S(7), C(8));
      C(0) <= C0;
      C8   <= C(8);
end structural_8;
