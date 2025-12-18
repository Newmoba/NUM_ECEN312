library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity stopwatch_led is
  Port (
    clk   : in  std_logic;                     -- 50 MHz
    sw    : in  std_logic;                     -- display select: 0=sec, 1=min
    btnE  : in  std_logic;                     -- START  (BTN_EAST)
    btnN  : in  std_logic;                     -- STOP   (BTN_NORTH)
    btnS  : in  std_logic;                     -- RESET  (BTN_SOUTH)
    led   : out std_logic_vector(7 downto 0)   -- BCD output
  );
end stopwatch_led;

architecture rtl of stopwatch_led is

  constant CLK_HZ      : natural := 50000000;
  constant ONE_HZ_MAX  : unsigned(25 downto 0) := to_unsigned(CLK_HZ-1, 26);

  -- 1 Hz divider
  signal sec_div   : unsigned(25 downto 0) := (others => '0');
  signal sec_tick  : std_logic := '0';

  -- running state
  signal running   : std_logic := '0';

  -- time in BCD: MM:SS
  signal sec_ones  : unsigned(3 downto 0) := (others => '0'); -- 0..9
  signal sec_tens  : unsigned(3 downto 0) := (others => '0'); -- 0..5
  signal min_ones  : unsigned(3 downto 0) := (others => '0'); -- 0..9
  signal min_tens  : unsigned(3 downto 0) := (others => '0'); -- 0..9

  -- button sync + edge detect
  signal b1, b2, bprev : std_logic_vector(2 downto 0) := (others => '0');
  signal brise         : std_logic_vector(2 downto 0);

begin
  ------------------------------------------------------------------
  -- Button synchronizer (pressed=1 with PULLDOWN constraints)
  -- If your buttons behave inverted, flip raw: raw := not raw;
  ------------------------------------------------------------------
  process(clk)
    variable raw : std_logic_vector(2 downto 0);
  begin
    if rising_edge(clk) then
      raw := btnS & btnN & btnE;  -- [2]=reset, [1]=stop, [0]=start
      b1 <= raw;
      b2 <= b1;
      bprev <= b2;
    end if;
  end process;

  brise <= b2 and (not bprev);

  ------------------------------------------------------------------
  -- 1 Hz tick generator (always runs; we reset divider when paused)
  ------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if running='0' then
        sec_div  <= (others => '0');
        sec_tick <= '0';
      else
        if sec_div = ONE_HZ_MAX then
          sec_div  <= (others => '0');
          sec_tick <= '1';
        else
          sec_div  <= sec_div + 1;
          sec_tick <= '0';
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- Stopwatch control + time counting
  -- Priority: RESET > STOP > START
  ------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then

      -- control
      if brise(2)='1' then              -- RESET (btnS)
        running  <= '0';
        sec_ones <= (others=>'0'); sec_tens <= (others=>'0');
        min_ones <= (others=>'0'); min_tens <= (others=>'0');

      else
        if brise(1)='1' then            -- STOP (btnN)
          running <= '0';
        elsif brise(0)='1' then         -- START (btnE)
          running <= '1';
        end if;

        -- tick
        if sec_tick='1' then
          -- +1 second with carry: MM:SS (00..99:59)
          if sec_ones = 9 then
            sec_ones <= (others=>'0');
            if sec_tens = 5 then
              sec_tens <= (others=>'0');
              if min_ones = 9 then
                min_ones <= (others=>'0');
                if min_tens = 9 then
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
      end if;
    end if;
  end process;

  ------------------------------------------------------------------
  -- LED display: BCD (tens on [7:4], ones on [3:0])
  ------------------------------------------------------------------
  process(sw, sec_tens, sec_ones, min_tens, min_ones)
  begin
    if sw='0' then
      led <= std_logic_vector(sec_tens) & std_logic_vector(sec_ones);
    else
      led <= std_logic_vector(min_tens) & std_logic_vector(min_ones);
    end if;
  end process;

end rtl;
