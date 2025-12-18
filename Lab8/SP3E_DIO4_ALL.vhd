library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =========================================================
-- Spartan-3E version of LAB8 ALL-IN-ONE
--  Task-2: 8-LED running light (one-hot), direction by sw(0)
--  Task-3: 4-digit 7-seg stopwatch MM.SS
--          button(0)=START, button(1)=STOP, button(2)=RESET
--
-- Notes:
--  - Default clock: 50MHz (set CLK_HZ generic if different)
--  - an (anodes) assumed active-low (common-anode display)
--  - seg assumed active-low
--  - If buttons are active-low, flip one line in code (marked)
-- =========================================================

entity SP3E_LAB8_ALL is
  generic(
    CLK_HZ : natural := 50000000  -- <-- set to your board clock (e.g., 50_000_000)
  );
  port(
    clk    : in  std_logic;
    reset  : in  std_logic;                       -- active-high
    button : in  std_logic_vector(3 downto 0);    -- use button(2 downto 0)
    sw     : in  std_logic_vector(7 downto 0);

    led    : out std_logic_vector(7 downto 0);
    an     : out std_logic_vector(3 downto 0);
    seg    : out std_logic_vector(6 downto 0);
    dp     : out std_logic
  );
end entity;

architecture rtl of SP3E_LAB8_ALL is

  -- ===== parameters =====
  constant SCAN_HZ : natural := 1000; -- 1kHz scan tick (digit each ~250Hz)
  constant LED_HZ  : natural := 5;    -- running light steps per second

  constant SCAN_DIV : natural := CLK_HZ / SCAN_HZ;
  constant LED_DIV  : natural := CLK_HZ / LED_HZ;
  constant SEC_DIV  : natural := CLK_HZ;          -- 1Hz tick

  -- ===== 7-seg hex decode (gfedcba), 1=ON =====
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

  -- ===== ticks =====
  signal scan_cnt  : unsigned(31 downto 0) := (others=>'0');
  signal led_cnt   : unsigned(31 downto 0) := (others=>'0');
  signal sec_cnt   : unsigned(31 downto 0) := (others=>'0');
  signal scan_tick : std_logic := '0';
  signal led_tick  : std_logic := '0';
  signal sec_tick  : std_logic := '0';

  -- ===== buttons sync + edge (use button(2:0)) =====
  signal b1, b2, b_prev : std_logic_vector(2 downto 0) := (others=>'0');
  signal b_rise         : std_logic_vector(2 downto 0);

  -- ===== running light =====
  signal led_reg : std_logic_vector(7 downto 0) := "00000001";

  -- ===== stopwatch digits =====
  signal running  : std_logic := '0';
  signal sec_ones : unsigned(3 downto 0) := (others=>'0'); -- 0..9
  signal sec_tens : unsigned(3 downto 0) := (others=>'0'); -- 0..5
  signal min_ones : unsigned(3 downto 0) := (others=>'0'); -- 0..9
  signal min_tens : unsigned(3 downto 0) := (others=>'0'); -- 0..9

  -- ===== scan mux =====
  signal scan_sel  : unsigned(1 downto 0) := (others=>'0');
  signal an_i      : std_logic_vector(3 downto 0) := "1110";
  signal cur_digit : unsigned(3 downto 0) := (others=>'0');
  signal seg_on    : std_logic_vector(6 downto 0) := (others=>'0');
  signal dp_on     : std_logic := '0';

begin
  led <= led_reg;

  -- ======================================================
  -- tick generators
  -- ======================================================
  process(clk, reset)
  begin
    if reset='1' then
      scan_cnt  <= (others=>'0');  scan_tick <= '0';
      led_cnt   <= (others=>'0');  led_tick  <= '0';
      sec_cnt   <= (others=>'0');  sec_tick  <= '0';
      scan_sel  <= (others=>'0');
    elsif rising_edge(clk) then
      -- scan tick
      if scan_cnt = to_unsigned(SCAN_DIV-1, scan_cnt'length) then
        scan_cnt  <= (others=>'0');
        scan_tick <= '1';
        scan_sel  <= scan_sel + 1;
      else
        scan_cnt  <= scan_cnt + 1;
        scan_tick <= '0';
      end if;

      -- led tick
      if led_cnt = to_unsigned(LED_DIV-1, led_cnt'length) then
        led_cnt  <= (others=>'0');
        led_tick <= '1';
      else
        led_cnt  <= led_cnt + 1;
        led_tick <= '0';
      end if;

      -- 1 second tick (only used when running)
      if sec_cnt = to_unsigned(SEC_DIV-1, sec_cnt'length) then
        sec_cnt  <= (others=>'0');
        sec_tick <= '1';
      else
        sec_cnt  <= sec_cnt + 1;
        sec_tick <= '0';
      end if;
    end if;
  end process;

  -- ======================================================
  -- button sync & rising edge (sample every clock)
  -- ======================================================
  process(clk, reset)
    variable raw : std_logic_vector(2 downto 0);
  begin
    if reset='1' then
      b1 <= (others=>'0'); b2 <= (others=>'0'); b_prev <= (others=>'0');
    elsif rising_edge(clk) then
      raw := button(2 downto 0);

      -- ACTIVE-LOW BUTTONS? (pressed=0) => uncomment next line:
      -- raw := not button(2 downto 0);

      b1     <= raw;
      b2     <= b1;
      b_prev <= b2;
    end if;
  end process;

  b_rise <= b2 and (not b_prev);

  -- ======================================================
  -- running light (one-hot), direction by sw(0)
  -- sw(0)=0: left  LED0->LED7
  -- sw(0)=1: right LED7->LED0
  -- ======================================================
  process(clk, reset)
  begin
    if reset='1' then
      led_reg <= "00000001";
    elsif rising_edge(clk) then
      if led_tick='1' then
        if sw(0)='0' then
          if led_reg="10000000" then
            led_reg <= "00000001";
          else
            led_reg <= led_reg(6 downto 0) & '0';
          end if;
        else
          if led_reg="00000001" then
            led_reg <= "10000000";
          else
            led_reg <= '0' & led_reg(7 downto 1);
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ======================================================
  -- stopwatch control + count
  -- button(0)=START, button(1)=STOP, button(2)=RESET
  -- ======================================================
  process(clk, reset)
    variable run_next : std_logic;
  begin
    if reset='1' then
      running  <= '0';
      sec_ones <= (others=>'0'); sec_tens <= (others=>'0');
      min_ones <= (others=>'0'); min_tens <= (others=>'0');
      sec_cnt  <= (others=>'0');
    elsif rising_edge(clk) then
      run_next := running;

      -- priority: reset > stop > start
      if b_rise(2)='1' then
        run_next := '0';
        sec_ones <= (others=>'0'); sec_tens <= (others=>'0');
        min_ones <= (others=>'0'); min_tens <= (others=>'0');
        sec_cnt  <= (others=>'0');
      else
        if b_rise(1)='1' then
          run_next := '0';
        elsif b_rise(0)='1' then
          run_next := '1';
        end if;

        if run_next='1' then
          if sec_tick='1' then
            -- +1 second with carry (MM:SS), wrap after 99:59
            if sec_ones = to_unsigned(9,4) then
              sec_ones <= (others=>'0');
              if sec_tens = to_unsigned(5,4) then
                sec_tens <= (others=>'0');
                if min_ones = to_unsigned(9,4) then
                  min_ones <= (others=>'0');
                  if min_tens = to_unsigned(9,4) then
                    min_tens <= (others=>'0');
                  else
                    min_tens <= min_tens + 1;
                  end if;
                else
                  min_ones <= min_ones + 1;
                end if;
              else
                sec_tens <= sec_tens + 1;
              end if;
            else
              sec_ones <= sec_ones + 1;
            end if;
          end if;
        else
          -- paused => restart second divider cleanly
          sec_cnt <= (others=>'0');
        end if;
      end if;

      running <= run_next;
    end if;
  end process;

  -- ======================================================
  -- 7-seg scan mux (MM.SS)
  -- AN1 rightmost = sec ones
  -- AN2           = sec tens
  -- AN3           = min ones  (DP ON here)
  -- AN4 leftmost  = min tens
  -- ======================================================
  process(scan_sel, sec_ones, sec_tens, min_ones, min_tens)
  begin
    an_i      <= "1111";
    cur_digit <= (others=>'0');
    dp_on     <= '0';

    case std_logic_vector(scan_sel) is
      when "00" =>
        an_i      <= "1110";  -- AN1
        cur_digit <= sec_ones;
        dp_on     <= '0';
      when "01" =>
        an_i      <= "1101";  -- AN2
        cur_digit <= sec_tens;
        dp_on     <= '0';
      when "10" =>
        an_i      <= "1011";  -- AN3
        cur_digit <= min_ones;
        dp_on     <= '1';
      when others =>
        an_i      <= "0111";  -- AN4
        cur_digit <= min_tens;
        dp_on     <= '0';
    end case;
  end process;

  an <= an_i;

  -- seg decode (combinational, warning-гүй)
  process(cur_digit)
  begin
    seg_on <= hex_to_7seg_gfedcba(cur_digit);
  end process;

  -- common-anode: cathodes active-low
  seg <= not seg_on;
  dp  <= not dp_on;

end architecture;
