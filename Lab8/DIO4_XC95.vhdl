library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =========================================================
-- DIO4/XC95 Test Configuration (fixed)
--  - switch(7:0) -> led(7:0)
--  - button(3:0): each button increments one digit (HEX 0..F)
--  - 4-digit 7-seg scanning
--  - dp controlled by switch(0)
--  - NO "no sensitivity list" warnings
-- =========================================================

entity DIO4_XC95 is
  Port (
    mclk   : in  std_logic;                         -- system clock (1.842MHz on XC95 board)
    reset  : in  std_logic;                         -- active-high reset
    button : in  std_logic_vector(3 downto 0);      -- buttons on DIO4
    switch : in  std_logic_vector(7 downto 0);      -- switches on DIO4

    led    : out std_logic_vector(7 downto 0);      -- discrete LEDs (8)
    ledg   : out std_logic;                         -- LED latch enable
    anode  : out std_logic_vector(3 downto 0);      -- 7-seg anodes (active-low)
    ssg    : out std_logic_vector(6 downto 0);      -- 7-seg cathodes A..G (active-low)
    dp     : out std_logic                          -- decimal point cathode (active-low)
  );
end DIO4_XC95;

architecture Behavioral of DIO4_XC95 is

  -- =======================================================
  -- HEX -> 7seg (gfedcba), 1=ON
  -- =======================================================
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

  -- stored digits
  signal digit1 : unsigned(3 downto 0) := (others=>'0');
  signal digit2 : unsigned(3 downto 0) := (others=>'0');
  signal digit3 : unsigned(3 downto 0) := (others=>'0');
  signal digit4 : unsigned(3 downto 0) := (others=>'0');

  -- currently displayed digit
  signal digit  : unsigned(3 downto 0) := (others=>'0');

  -- scan/anode state (active-low)
  signal anode_i : std_logic_vector(3 downto 0) := "1110";

  -- clock divider
  signal clkdiv : unsigned(17 downto 0) := (others=>'0');
  signal cclk       : std_logic; -- scan clock
  signal button_clk : std_logic; -- slower button sampling clock

  signal seg_on : std_logic_vector(6 downto 0);

  -- optional: if you want edge detect for buttons later
  -- (not needed for the original lab code)
begin

  -- =======================================================
  -- simple outputs
  -- =======================================================
  ledg <= '1';          -- enable LED latch
  led  <= switch;       -- switches directly drive LEDs

  -- dp is active-low. Here: switch(0)=1 -> dp ON
  dp <= not switch(0);

  -- =======================================================
  -- clock divider
  -- =======================================================
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

  -- =======================================================
  -- button sampling / digit increment (slow clock)
  -- =======================================================
  process(button_clk, reset)
    variable b : std_logic_vector(3 downto 0);
  begin
    if reset='1' then
      digit1 <= (others=>'0');
      digit2 <= (others=>'0');
      digit3 <= (others=>'0');
      digit4 <= (others=>'0');

    elsif rising_edge(button_clk) then

      -- IF ACTIVE-LOW BUTTONS (pressed=0), uncomment this line and comment the next one:
      -- b := not button;
      b := button;

      if    b="0001" then digit1 <= digit1 + 1;
      elsif b="0010" then digit2 <= digit2 + 1;
      elsif b="0100" then digit3 <= digit3 + 1;
      elsif b="1000" then digit4 <= digit4 + 1;
      end if;

    end if;
  end process;

  -- =======================================================
  -- scan selector (sequential)
  -- =======================================================
  process(cclk, reset)
  begin
    if reset='1' then
      anode_i <= "1110";
      digit   <= (others=>'0');

    elsif rising_edge(cclk) then
      case anode_i is
        when "1110" =>
          digit   <= digit1;
          anode_i <= "1101";

        when "1101" =>
          digit   <= digit2;
          anode_i <= "1011";

        when "1011" =>
          digit   <= digit3;
          anode_i <= "0111";

        when "0111" =>
          digit   <= digit4;
          anode_i <= "1110";

        when others =>
          digit   <= (others=>'0');
          anode_i <= "1110";
      end case;
    end if;
  end process;

  anode <= anode_i;

  -- =======================================================
  -- 7-seg decode (combinational with sensitivity list)
  -- =======================================================
  process(digit)
  begin
    seg_on <= hex_to_7seg_gfedcba(digit);
  end process;

  -- common-anode => cathodes active-low
  ssg <= not seg_on;

end Behavioral;
