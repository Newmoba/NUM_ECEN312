library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SP3E_DIO4_TEST is
  generic(
    CLK_HZ : natural := 50000000  -- <-- өөрийн Spartan-3E хавтангийн clock (ихэвчлэн 50MHz)
  );
  port(
    clk    : in  std_logic;
    reset  : in  std_logic;                       -- active-high
    button : in  std_logic_vector(3 downto 0);    -- 4 buttons (pressed=1 гэж үзсэн)
    sw     : in  std_logic_vector(7 downto 0);    -- 8 switches

    led    : out std_logic_vector(7 downto 0);    -- 8 LEDs
    an     : out std_logic_vector(3 downto 0);    -- 4-digit anodes (active-low)
    seg    : out std_logic_vector(6 downto 0);    -- segments A..G (active-low)
    dp     : out std_logic                        -- decimal point (active-low)
  );
end entity;

architecture rtl of SP3E_DIO4_TEST is

  -- HEX -> 7seg (gfedcba), 1=ON
  function hex_to_7seg_gfedcba(x : unsigned(3 downto 0)) return std_logic_vector is
    variable s : std_logic_vector(6 downto 0);
  begin
    case to_integer(x) is
      when 0  => s := "0111111";
      when 1  => s := "0000110";
      when 2  => s := "1011011";
      when 3  => s := "1001111";
      when 4  => s := "1100110";
      when 5  => s := "1101101";
      when 6  => s := "1111101";
      when 7  => s := "0000111";
      when 8  => s := "1111111";
      when 9  => s := "1101111";
      when 10 => s := "1110111";
      when 11 => s := "1111100";
      when 12 => s := "0111001";
      when 13 => s := "1011110";
      when 14 => s := "1111001";
      when 15 => s := "1110001";
      when others => s := "0000000";
    end case;
    return s;
  end function;

  -- ===== clocks: scan & button sample =====
  constant SCAN_HZ   : natural := 1000;  -- 1kHz scan tick (digit бүр ~250Hz)
  constant BTN_HZ    : natural := 20;    -- 20Hz sampling (debounce маягтай)
  constant SCAN_DIV  : natural := CLK_HZ / SCAN_HZ;
  constant BTN_DIV   : natural := CLK_HZ / BTN_HZ;

  signal scan_cnt  : unsigned(31 downto 0) := (others=>'0');
  signal btn_cnt   : unsigned(31 downto 0) := (others=>'0');
  signal scan_tick : std_logic := '0';
  signal btn_tick  : std_logic := '0';

  signal d1, d2, d3, d4 : unsigned(3 downto 0) := (others=>'0');
  signal cur_digit      : unsigned(3 downto 0) := (others=>'0');
  signal an_i           : std_logic_vector(3 downto 0) := "1110";

  signal seg_on : std_logic_vector(6 downto 0);

  -- button sync + edge
  signal b1, b2, b_prev : std_logic_vector(3 downto 0) := (others=>'0');
  signal b_rise         : std_logic_vector(3 downto 0);

begin
  led <= sw;               -- switches -> LEDs
  dp  <= not sw(0);        -- SW0=1 => DP ON

  -- ===== tick generators =====
  process(clk, reset)
  begin
    if reset='1' then
      scan_cnt  <= (others=>'0');
      btn_cnt   <= (others=>'0');
      scan_tick <= '0';
      btn_tick  <= '0';
    elsif rising_edge(clk) then
      -- scan tick
      if scan_cnt = to_unsigned(SCAN_DIV-1, scan_cnt'length) then
        scan_cnt  <= (others=>'0');
        scan_tick <= '1';
      else
        scan_cnt  <= scan_cnt + 1;
        scan_tick <= '0';
      end if;

      -- button tick
      if btn_cnt = to_unsigned(BTN_DIV-1, btn_cnt'length) then
        btn_cnt  <= (others=>'0');
        btn_tick <= '1';
      else
        btn_cnt  <= btn_cnt + 1;
        btn_tick <= '0';
      end if;
    end if;
  end process;

  -- ===== button sync & rising edge (sample on btn_tick) =====
  process(clk, reset)
  begin
    if reset='1' then
      b1 <= (others=>'0'); b2 <= (others=>'0'); b_prev <= (others=>'0');
    elsif rising_edge(clk) then
      if btn_tick='1' then
        -- Хэрвээ танай button pressed=0 (active-low) бол: b1 <= not button;
        b1     <= button;
        b2     <= b1;
        b_prev <= b2;
      end if;
    end if;
  end process;

  b_rise <= b2 and (not b_prev);

  -- ===== increment digits on rising edge =====
  process(clk, reset)
  begin
    if reset='1' then
      d1 <= (others=>'0'); d2 <= (others=>'0'); d3 <= (others=>'0'); d4 <= (others=>'0');
    elsif rising_edge(clk) then
      if btn_tick='1' then
        if    b_rise="0001" then d1 <= d1 + 1;
        elsif b_rise="0010" then d2 <= d2 + 1;
        elsif b_rise="0100" then d3 <= d3 + 1;
        elsif b_rise="1000" then d4 <= d4 + 1;
        end if;
      end if;
    end if;
  end process;

  -- ===== scan anodes =====
  process(clk, reset)
  begin
    if reset='1' then
      an_i      <= "1110";
      cur_digit <= (others=>'0');
    elsif rising_edge(clk) then
      if scan_tick='1' then
        case an_i is
          when "1110" => cur_digit <= d1; an_i <= "1101";
          when "1101" => cur_digit <= d2; an_i <= "1011";
          when "1011" => cur_digit <= d3; an_i <= "0111";
          when "0111" => cur_digit <= d4; an_i <= "1110";
          when others => cur_digit <= (others=>'0'); an_i <= "1110";
        end case;
      end if;
    end if;
  end process;

  an <= an_i;

  -- ===== seg decode (combinational, warning-гүй) =====
  process(cur_digit)
  begin
    seg_on <= hex_to_7seg_gfedcba(cur_digit);
  end process;

  seg <= not seg_on;  -- active-low

end architecture;
