library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_demo_top is
    Port (
        -- On-board I/O
        clk50 : in  std_logic;
        btn   : in  std_logic_vector(1 downto 0);
        sw    : in  std_logic_vector(7 downto 0);
        led   : out std_logic_vector(7 downto 0);

        -- DDR SDRAM interface
        ddr_clk   : out std_logic;
        ddr_cke   : out std_logic;
        ddr_cs_n  : out std_logic;
        ddr_ras_n : out std_logic;
        ddr_cas_n : out std_logic;
        ddr_we_n  : out std_logic;
        ddr_ba    : out std_logic_vector(1 downto 0);
        ddr_addr  : out std_logic_vector(12 downto 0);
        ddr_dq    : inout std_logic_vector(15 downto 0);
        ddr_dqm   : out std_logic_vector(1 downto 0)
    );
end ddr_demo_top;

architecture Behavioral of ddr_demo_top is

    --------------------------------------------------------------------
    -- Clock Divider (50 MHz -> 25 MHz)
    --------------------------------------------------------------------
    signal clk25 : std_logic := '0';

    --------------------------------------------------------------------
    -- DDR Controller Signals
    --------------------------------------------------------------------
    type ddr_state_type is (
        INIT,
        IDLE,
        WRITE_CMD,
        WRITE_DATA,
        READ_CMD,
        READ_DATA
    );

    signal state    : ddr_state_type := INIT;
    signal dq_out   : std_logic_vector(15 downto 0) := (others => '0');
    signal dq_oe    : std_logic := '0';
    signal led_reg  : std_logic_vector(7 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Assign LED output
    --------------------------------------------------------------------
    led <= led_reg;

    --------------------------------------------------------------------
    -- Clock Divider Process
    --------------------------------------------------------------------
    process(clk50)
    begin
        if rising_edge(clk50) then
            clk25 <= not clk25;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Static DDR Assignments
    --------------------------------------------------------------------
    ddr_clk  <= clk25;
    ddr_cke  <= '1';
    ddr_cs_n <= '0';
    ddr_ba   <= "00";                    -- Bank 0
    ddr_addr <= (others => '0');          -- Fixed address
    ddr_dqm  <= "00";                    -- No masking

    ddr_dq <= dq_out when dq_oe = '1' else (others => 'Z');

    --------------------------------------------------------------------
    -- DDR Control State Machine
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then

            case state is

                --------------------------------------------------------
                -- INIT (very simplified)
                --------------------------------------------------------
                when INIT =>
                    ddr_ras_n <= '1';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '1';
                    dq_oe     <= '0';
                    state     <= IDLE;

                --------------------------------------------------------
                -- IDLE
                --------------------------------------------------------
                when IDLE =>
                    ddr_ras_n <= '1';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '1';
                    dq_oe     <= '0';

                    if btn(1) = '1' then        -- WRITE
                        state <= WRITE_CMD;
                    elsif btn(0) = '1' then     -- READ
                        state <= READ_CMD;
                    end if;

                --------------------------------------------------------
                -- WRITE COMMAND
                --------------------------------------------------------
                when WRITE_CMD =>
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '0';
                    state     <= WRITE_DATA;

                --------------------------------------------------------
                -- WRITE DATA
                --------------------------------------------------------
                when WRITE_DATA =>
                    dq_out <= "00000000" & sw;  -- Lower 8 bits used
                    dq_oe  <= '1';
                    ddr_ras_n <= '1';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '1';
                    state <= IDLE;

                --------------------------------------------------------
                -- READ COMMAND
                --------------------------------------------------------
                when READ_CMD =>
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '0';
                    ddr_we_n  <= '1';
                    state     <= READ_DATA;

                --------------------------------------------------------
                -- READ DATA
                --------------------------------------------------------
                when READ_DATA =>
                    led_reg <= ddr_dq(7 downto 0);
                    state   <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
