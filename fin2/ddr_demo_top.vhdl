library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_lcd_demo_top is
    Port (
        clk50 : in std_logic;
        btn   : in std_logic_vector(1 downto 0);
        sw    : in std_logic_vector(7 downto 0);
        led   : out std_logic_vector(7 downto 0);

        -- DDR SDRAM
        ddr_clk   : out std_logic;
        ddr_cke   : out std_logic;
        ddr_cs_n  : out std_logic;
        ddr_ras_n : out std_logic;
        ddr_cas_n : out std_logic;
        ddr_we_n  : out std_logic;
        ddr_ba    : out std_logic_vector(1 downto 0);
        ddr_addr  : out std_logic_vector(12 downto 0);
        ddr_dq    : inout std_logic_vector(15 downto 0);
        ddr_dqm   : out std_logic_vector(1 downto 0);

        -- LCD
        lcd_rs : out std_logic;
        lcd_rw : out std_logic;
        lcd_e  : out std_logic;
        lcd_db : out std_logic_vector(3 downto 0)
    );
end ddr_lcd_demo_top;

architecture Behavioral of ddr_lcd_demo_top is

    --------------------------------------------------------------------
    -- Clock divider (50 MHz → 25 MHz)
    --------------------------------------------------------------------
    signal clk25 : std_logic := '0';

    --------------------------------------------------------------------
    -- DDR controller
    --------------------------------------------------------------------
    type ddr_state_type is (INIT, IDLE, WRITE_CMD, WRITE_DATA, READ_CMD, READ_DATA);
    signal ddr_state : ddr_state_type := INIT;

    signal dq_out  : std_logic_vector(15 downto 0);
    signal dq_oe   : std_logic := '0';
    signal data_rd : std_logic_vector(7 downto 0) := (others => '0');

    --------------------------------------------------------------------
    -- LCD controller
    --------------------------------------------------------------------
    type lcd_state_type is (
        PWR_WAIT,
        INIT1, INIT2, INIT3, INIT4, INIT5, INIT6,
        IDLE,
        SEND_HI, SEND_LO
    );

    signal lcd_state : lcd_state_type := PWR_WAIT;
    signal lcd_cnt   : integer range 0 to 2_000_000 := 0;
    signal lcd_data  : std_logic_vector(7 downto 0);
    signal lcd_rs_i  : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Clock divider
    --------------------------------------------------------------------
    process(clk50)
    begin
        if rising_edge(clk50) then
            clk25 <= not clk25;
        end if;
    end process;

    --------------------------------------------------------------------
    -- DDR static signals
    --------------------------------------------------------------------
    ddr_clk  <= clk25;
    ddr_cke  <= '1';
    ddr_cs_n <= '0';
    ddr_ba   <= "00";
    ddr_addr <= (others => '0');
    ddr_dqm  <= "00";

    ddr_dq <= dq_out when dq_oe = '1' else (others => 'Z');

    --------------------------------------------------------------------
    -- DDR FSM
    --------------------------------------------------------------------
    process(clk25)
    begin
        if rising_edge(clk25) then
            case ddr_state is

                when INIT =>
                    ddr_ras_n <= '1';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '1';
                    dq_oe <= '0';
                    ddr_state <= IDLE;

                when IDLE =>
                    dq_oe <= '0';
                    if btn(1) = '1' then
                        ddr_state <= WRITE_CMD;
                    elsif btn(0) = '1' then
                        ddr_state <= READ_CMD;
                    end if;

                when WRITE_CMD =>
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '0';
                    ddr_state <= WRITE_DATA;

                when WRITE_DATA =>
                    dq_out <= "00000000" & sw;
                    dq_oe <= '1';
                    ddr_ras_n <= '1';
                    ddr_cas_n <= '1';
                    ddr_we_n  <= '1';
                    ddr_state <= IDLE;

                when READ_CMD =>
                    ddr_ras_n <= '0';
                    ddr_cas_n <= '0';
                    ddr_we_n  <= '1';
                    ddr_state <= READ_DATA;

                when READ_DATA =>
                    data_rd <= ddr_dq(7 downto 0);
                    ddr_state <= IDLE;

            end case;
        end if;
    end process;

    led <= data_rd;

    --------------------------------------------------------------------
    -- LCD controller (HD44780, 4-bit mode)
    --------------------------------------------------------------------
    lcd_rw <= '0';
    lcd_rs <= lcd_rs_i;

    process(clk25)
    begin
        if rising_edge(clk25) then
            case lcd_state is

                when PWR_WAIT =>
                    if lcd_cnt = 750_000 then
                        lcd_cnt <= 0;
                        lcd_state <= INIT1;
                    else
                        lcd_cnt <= lcd_cnt + 1;
                    end if;

                when INIT1 => lcd_rs_i <= '0'; lcd_data <= x"33"; lcd_state <= SEND_HI;
                when INIT2 => lcd_data <= x"32"; lcd_state <= SEND_HI;
                when INIT3 => lcd_data <= x"28"; lcd_state <= SEND_HI;
                when INIT4 => lcd_data <= x"0C"; lcd_state <= SEND_HI;
                when INIT5 => lcd_data <= x"06"; lcd_state <= SEND_HI;
                when INIT6 => lcd_data <= x"01"; lcd_state <= SEND_HI;
                when IDLE  =>
                    lcd_rs_i <= '1';
                    lcd_data <= x"30" + data_rd(7 downto 4);
                    lcd_state <= SEND_HI;

                when SEND_HI =>
                    lcd_db <= lcd_data(7 downto 4);
                    lcd_e  <= '1';
                    lcd_e  <= '0';
                    lcd_state <= SEND_LO;

                when SEND_LO =>
                    lcd_db <= lcd_data(3 downto 0);
                    lcd_e  <= '1';
                    lcd_e  <= '0';
                    lcd_state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
