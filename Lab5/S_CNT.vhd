library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
entity S_CNT is
 port( clk, RST_n, EN : std_logic;
	CNTR : out std_logic_vector(7 downto 0));
end S_CNT;
architecture RTL of S_CNT is
 signal FF : std_logic_vector(7 downto 0):="00000000";
begin
 process (clk, RST_n)
 begin
  if (RST_n='0') then
   FF <= (FF'range => '0');
  elsif (clk'event and clk = '1') then
   if (EN='1') then
    FF <= FF +1;
   end if;
  end if;
 end process;
 CNTR <= FF;
end RTL;
