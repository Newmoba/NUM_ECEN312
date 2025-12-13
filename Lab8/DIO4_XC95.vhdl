library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity DIO4_XC95 is
  Port( mlck : in std_logic;
       reset : in std_logic;
       button: in std_logic_vector(3 downto 0);
       switch: out std_logic_vector(7 downto 0);
       led   : out std_logic_vector(7 downto 0);
       ledg  : out std_logic;
       anode : out std_logic_vector(3 downto 0);
       ssg   : out std_logic_vector(6 downto 0);
       dp    : out std_logic);
  end DIO4_XC95;

  architecture Behavioral of DIO4_XC95 is
    signal digit : std_logic_vector(3 downto 0):="0000";
    signal digit1, digit2, digit3, digit4 : std_logic_vector(3 downto 0);
    signal dig   : std_logic_vector(6 downto 0);
    signal clkdiv : std_logic_vector(17 downto 0);
    signal cclk  : std_logic;
    signal button_clk :std_logic;
    signal anode_i : std_logic_vector(3 downto 0):="1110";
begin
  ledg <= '1';    --LED asaah latch-iin orolt zuvshuuruh
  led <= switch;  --tulhuuriin bairlalaar LED-iig udirdah
  dp <= switch(0); --1r tulhuureer delgetsiin 10tiin orongiin tsegiig asaah/untraah
  anode < =anode_i;

  --binary code to 7segment 
  dig <= "0111111" when digit = "0000" else
          "0000110" when digit = "0001" else
          "1011011" when digit = "0010" else
          "1001111" when digit = "0011" else
          "1100110" when digit = "0100" else
          "1101101" when digit = "0101" else
          "1111101" when digit = "0110" else
          "0000111" when digit = "0111" else
          "1111111" when digit = "1000" else
          "1101111" when digit = "1001" else
          "1110111" when digit = "1010" else
          "1111100" when digit = "1011" else
          "0111001" when digit = "1100" else
          "1011110" when digit = "1101" else
          "1111001" when digit = "1110" else
          "1110001" when digit = "1111" else
          "0001000";
  ssg <= not dig; --erunhii anodtoi uchir inverse


  --1.842MHz system clock iig huvaah, tovchluuriin daraltiig synchron-chlah
  process(mclk)
    begin
      if (mclk - '1' and mclk'event) then
          clkdiv <= clkdiv +1;
      end if;
    end process;

  process(cclk, reset)
    begin
      if reset = '1' then
        anode_i <="1110";
        digit   <="0000";
      elsif(cclk='1' and cclk'event) then
        case anode_i is
          when "1110" =>
            digit <= digit1;
            anode_i <= "1101";
          when "1101" =>
            digit <= digit2;
            anode_i <= "1011";
          when "1011" =>
            digit <= digit3;
            anode_i <= "0111";
          when "0111" =>
            digit <= digit4;
            anode_i <= "1110";
          when others =>
            digit <= "0000";
            anode_i <= "1110";
        end case;
      end if;
  end process;
end Behavioral;
