library IEEE;
use IEEE.std_logic_1164.all;
entity AS_CNT is
port(RST_n, a_clock : in std_logic;
     CNTR : out std_logic_vector(3 downto 0));
end AS_CNT;

architecture RTL of AS_CNT is
 component JKFF
 port( clk, RST_n, J, K : in std_logic;
      Q, Qn		: out std_logic);
 end component;
 signal FFQ : std_logic_vector(4 downto 0):="00000";
 signal FFQn: std_logic_vector(4 downto 0):="11111";
 signal VDD : std_logic:='1';
begin
 VDD <= '1'; FFQn(0) <= a_clock;
  jk0: for j in 1 to 4 generate
   uu0: JKFF port map (clk => FFQn(j-1), RST_n=>RST_n,
	J => VDD, K => VDD, Q => FFQ(j), Qn => FFQn(j));
  end generate;
  CNTR <= FFQ (4 downto 1);
end RTL;
