library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =========================================================
-- DIO4 + XC95 (XC95108) TEST
--  - 8 switch -> 8 discrete LED
--  - 4 button -> 4 digit (HEX 0..F) increment
--  - 4-digit 7-seg scanning
--  - DP (decimal point) controlled by SW1 (switch(0))
-- =========================================================

entity DIO4_XC95_TEST is
  Port (
    mclk   : in  std_logic;                         -- 1.842 MHz
    reset  : in  std_logic;                         -- active-high
    button : in  std_logic_vector(3 downto 0);      -- DIO4 buttons (assumed active-high when pressed)
    switch : in  std_logic_vector(7 downto 0);      -- DIO4 switches
    led    : out std_logic_vector(7 downto 0);      -- 8 discrete LEDs
    ledg   : out std_logic;                         -- LED latch enable
    anode  : out std_logic_vector(3 downto 0);      -- 7-seg anodes (active-low)
    ssg    : out std_logic_vector(6 downto 0);      -- segments A..G cathodes (active-low), bit0=A ... bit6=G
    dp     : out std_logic                          -- decimal point cathode (active-low)
  );
end DIO4_XC95_TEST;

architecture Behavioral of DIO4_XC95_TEST is

  -- HEX(0..F) -> 7-seg (gfedcba), 1=segment ON
  function hex_to_7seg_gfedcba(x : unsigned(3 downto 0)) return std_logic_vector is
    variable s : std_logic_vector(6 downto 0);
  begin
    case to_integer(x) is
      when 0  => s := "0111111"; -- 0
      when 1  => s := "0000110"; -- 1
      when 2  => s := "1011011"; -- 2
      when 3  => s := "1001111"; -- 3
      when 4  => s := "1100110"; -- 4
      when 5  => s := "1101101"; -- 5
      when 6  => s := "1111101"; -- 6
      when 7  => s := "0000111"; -- 7
      when 8  => s := "1111111"; -- 8
      when 9  => s := "1101111"; -- 9
      when 10 => s := "1110111"; -- A
      when 11 => s := "1111100"; -- b
      when 12 => s := "0111001"; -- C
      when 13 => s := "1011110"; -- d
      when 14 => s := "1111001"; -- E
      when 15 => s := "1110001"; -- F
      when others => s := "0000000"; -- blank
    end case;
    return s;
  end function;

  signal digit   : unsigned(3 downto 0) := (others=>'0');
  signal digit1  : unsigned(3 downto 0) := (others=>'0');
  signal digit2  : unsigned(3 downto 0) := (others=>'0');
  signal digit3  : unsigned(3 downto 0) := (others=>'0');
  signal digit4  : unsigned(3 downto 0) := (others=>'0');

  signal anode_i : std_logic_vector(3 downto 0) := "1110";

  -- simple binary divider
  signal clkdiv  : unsigned(17 downto 0) := (others=>'0');
  signal cclk        : std_logic; -- ~1.8 kHz scan clock
  signal button_clk  : std_logic; -- ~7 Hz (slow sampling for buttons)

  signal seg_on  : std_logic_vector(6 downto 0);

begin

  -- LED latch enable: keep transparent
  ledg <= '1';

  -- Switches drive LEDs directly
  led <= switch;

  -- DP is active-low. Here: SW1=1 => DP ON
  dp <= not switch(0);

  -- divider
  process(mclk, reset)
  begin
    if reset='1' then
      clkdiv <= (others=>'0');
    elsif rising_edge(mclk) then
      clkdiv <= clkdiv + 1;
    end if;
  end process;

  cclk       <= std_logic(clkdiv(9));
  button_clk <= std_logic(clkdiv(17));

  -- increment digits by buttons (one-hot)
  process(button_clk, reset)
  begin
    if reset='1' then
      digit1 <= (others=>'0');
      digit2 <= (others=>'0');
      digit3 <= (others=>'0');
      digit4 <= (others=>'0');
    elsif rising_edge(button_clk) then
      if    button="0001" then digit1 <= digit1 + 1;
      elsif button="0010" then digit2 <= digit2 + 1;
      elsif button="0100" then digit3 <= digit3 + 1;
      elsif button="1000" then digit4 <= digit4 + 1;
      end if;
    end if;
  end process;

  -- scan AN1..AN4 (active-low)
  process(cclk, reset)
  begin
    if reset='1' then
      anode_i <= "1110";
      digit   <= (others=>'0');
    elsif rising_edge(cclk) then
      case anode_i is
        when "1110" => digit <= digit1; anode_i <= "1101";
        when "1101" => digit <= digit2; anode_i <= "1011";
        when "1011" => digit <= digit3; anode_i <= "0111";
        when "0111" => digit <= digit4; anode_i <= "1110";
        when others => digit <= (others=>'0'); anode_i <= "1110";
      end case;
    end if;
  end process;

  anode  <= anode_i;

  seg_on <= hex_to_7seg_gfedcba(digit);

  -- Common-anode display => cathodes are active-low
  ssg <= not seg_on;

end Behavioral;
