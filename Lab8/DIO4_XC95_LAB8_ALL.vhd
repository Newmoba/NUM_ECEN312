library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =========================================================
-- LAB8 ALL-IN-ONE
--  Task-2: 8 discrete LEDs running light (one-hot)
--          direction selected by SW1 (switch(0))
--  Task-3: 4-digit 7-seg stopwatch MM.SS
--          button(0)=START, button(1)=STOP, button(2)=RESET
--  Clock: 1.842 MHz (on XC95 board)
-- =========================================================

entity DIO4_XC95_LAB8_ALL is
  Port (
    mclk   : in  std_logic;                         -- 1.842 MHz
    reset  : in  std_logic;                         -- active-high
    button : in  std_logic_vector(3 downto 0);      -- DIO4 buttons (assumed active-high when pressed)
    switch : in  std_logic_vector(7 downto 0);      -- DIO4 switches
    led    : out std_logic_vector(7 downto 0);      -- 8 discrete LEDs
    ledg   : out std_logic;                         -- LED latch enable
    anode  : out std_logic_vector(3 downto 0);      -- 7-seg anodes (active-low)
    ssg    : out std_logic_vector(6 downto 0);      -- segments A..G cathodes (active-low)
    dp     : out std_logic                          -- decimal point cathode (active-low)
  );
end DIO4_XC95_LAB8_ALL;

architecture Behavioral of DIO4_XC95_LAB8_ALL is

  constant CLK_HZ   : natural := 1842000; -- 1.842 MHz
  constant SCAN_HZ  : natural := 1000;    -- 1 kHz scan tick (=> each digit 250 Hz)
  constant LED_HZ   : natural := 5;       -- running light speed (steps/sec)

  constant SCAN_DIV : natural := CLK_HZ / SCAN_HZ; -- 1842
  constant SEC_DIV  : natural := CLK_HZ / 1;       -- 1842000
  constant LED_DIV  : natural := CLK_HZ / LED_HZ;  -- 368400

  -- 0..F -> 7-seg (gfedcba), 1=segment ON
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

  -- ======================================================
  -- Button sync/edge (use only button(0..2))
  -- ======================================================
  signal btn_ff1  : std_logic_vector(2 downto 0) := (others=>'0');
  signal btn_ff2  : std_logic_vector(2 downto 0) := (others=>'0');
  signal btn_prev : std_logic_vector(2 downto 0) := (others=>'0');
  signal btn_rise : std_logic_vector(2 downto 0);

  -- ======================================================
  -- Stopwatch (MM:SS)
  -- ======================================================
  signal running  : std_logic := '0';

  signal sec_cnt  : unsigned(20 downto 0) := (others=>'0'); -- up to 1,842,000-1 fits in 21 bits

  signal sec_ones : unsigned(3 downto 0) := (others=>'0'); -- 0..9
  signal sec_tens : unsigned(3 downto 0) := (others=>'0'); -- 0..5
  signal min_ones : unsigned(3 downto 0) := (others=>'0'); -- 0..9
  signal min_tens : unsigned(3 downto 0) := (others=>'0'); -- 0..9

  -- ======================================================
  -- 7-seg scanning
  -- ======================================================
  signal scan_cnt : unsigned(10 downto 0) := (others=>'0'); -- up to 1841 fits in 11 bits
  signal scan_sel : unsigned(1 downto 0) := (others=>'0');

  signal cur_digit : unsigned(3 downto 0) := (others=>'0');
  signal seg_on    : std_logic_vector(6 downto 0) := (others=>'0');
  signal dp_on     : std_logic := '0'; -- 1=dot ON (will be inverted)

  -- ======================================================
  -- Running light
  -- ======================================================
  signal led_cnt  : unsigned(18 downto 0) := (others=>'0'); -- up to 368,399 fits in 19 bits
  signal led_reg  : std_logic_vector(7 downto 0) := "00000001";

begin

  -- LED latch enable: keep transparent
  ledg <= '1';
  led  <= led_reg;

  -- ======================================================
  -- Button synchronizer
  --   If your buttons are active-low, change to:
  --     btn_ff1 <= not button(2 downto 0);
  -- ======================================================
  process(mclk, reset)
  begin
    if reset='1' then
      btn_ff1  <= (others=>'0');
      btn_ff2  <= (others=>'0');
      btn_prev <= (others=>'0');
    elsif rising_edge(mclk) then
      btn_ff1  <= button(2 downto 0);
      btn_ff2  <= btn_ff1;
      btn_prev <= btn_ff2;
    end if;
  end process;

  btn_rise <= btn_ff2 and (not btn_prev);  -- one-clock pulse on rising edge

  -- ======================================================
  -- Stopwatch: Start/Stop/Reset + 1Hz tick from 1.842MHz
  -- Priority: reset_button > stop > start
  -- ======================================================
  process(mclk, reset)
    variable run_next : std_logic;
  begin
    if reset='1' then
      running  <= '0';
      sec_cnt  <= (others=>'0');
      sec_ones <= (others=>'0');
      sec_tens <= (others=>'0');
      min_ones <= (others=>'0');
      min_tens <= (others=>'0');

    elsif rising_edge(mclk) then
      run_next := running;

      -- control
      if btn_rise(2)='1' then        -- button(2)=RESET stopwatch
        run_next := '0';
        sec_cnt  <= (others=>'0');
        sec_ones <= (others=>'0');
        sec_tens <= (others=>'0');
        min_ones <= (others=>'0');
        min_tens <= (others=>'0');

      else
        if btn_rise(1)='1' then      -- button(1)=STOP
          run_next := '0';
        elsif btn_rise(0)='1' then   -- button(0)=START
          run_next := '1';
        end if;

        -- time base
        if run_next='1' then
          if sec_cnt = to_unsigned(SEC_DIV-1, sec_cnt'length) then
            sec_cnt <= (others=>'0');

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

          else
            sec_cnt <= sec_cnt + 1;
          end if;

        else
          -- paused => keep divider reset (so resume starts clean)
          sec_cnt <= (others=>'0');
        end if;

      end if;

      running <= run_next;
    end if;
  end process;

  -- ======================================================
  -- Running light (one-hot), direction by SW1 (switch(0))
  --   SW1=0 -> shift left  (LED0->LED7)
  --   SW1=1 -> shift right (LED7->LED0)
  -- ======================================================
  process(mclk, reset)
  begin
    if reset='1' then
      led_cnt <= (others=>'0');
      led_reg <= "00000001";
    elsif rising_edge(mclk) then
      if led_cnt = to_unsigned(LED_DIV-1, led_cnt'length) then
        led_cnt <= (others=>'0');

        if switch(0)='0' then
          -- shift left
          if led_reg = "10000000" then
            led_reg <= "00000001";
          else
            led_reg <= led_reg(6 downto 0) & '0';
          end if;
        else
          -- shift right
          if led_reg = "00000001" then
            led_reg <= "10000000";
          else
            led_reg <= '0' & led_reg(7 downto 1);
          end if;
        end if;

      else
        led_cnt <= led_cnt + 1;
      end if;
    end if;
  end process;

  -- ======================================================
  -- 7-seg scan tick (1kHz)
  -- ======================================================
  process(mclk, reset)
  begin
    if reset='1' then
      scan_cnt <= (others=>'0');
      scan_sel <= (others=>'0');
    elsif rising_edge(mclk) then
      if scan_cnt = to_unsigned(SCAN_DIV-1, scan_cnt'length) then
        scan_cnt <= (others=>'0');
        scan_sel <= scan_sel + 1;
      else
        scan_cnt <= scan_cnt + 1;
      end if;
    end if;
  end process;

  -- ======================================================
  -- Multiplex digits:
  --   AN1 (rightmost) = sec ones
  --   AN2             = sec tens
  --   AN3             = min ones  (DP ON here => MM.SS)
  --   AN4 (leftmost)  = min tens
  -- ======================================================
  process(scan_sel, sec_ones, sec_tens, min_ones, min_tens)
  begin
    anode     <= "1111";
    cur_digit <= (others=>'0');
    dp_on     <= '0';

    case std_logic_vector(scan_sel) is
      when "00" =>
        anode     <= "1110";  -- AN1
        cur_digit <= sec_ones;
        dp_on     <= '0';

      when "01" =>
        anode     <= "1101";  -- AN2
        cur_digit <= sec_tens;
        dp_on     <= '0';

      when "10" =>
        anode     <= "1011";  -- AN3
        cur_digit <= min_ones;
        dp_on     <= '1';     -- dot ON between minutes and seconds

      when others =>
        anode     <= "0111";  -- AN4
        cur_digit <= min_tens;
        dp_on     <= '0';
    end case;
  end process;

  seg_on <= hex_to_7seg_gfedcba(cur_digit);

  -- common-anode display => cathodes active-low
  ssg <= not seg_on;
  dp  <= not dp_on;

end Behavioral;
