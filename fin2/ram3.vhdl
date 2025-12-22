library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DDR_LED is
    Port (
        clk     : in  STD_LOGIC;                      
        rst     : in  STD_LOGIC;                      
        sw      : in  STD_LOGIC_VECTOR(3 downto 0);  
        btn_wr  : in  STD_LOGIC;                    
        btn_rd  : in  STD_LOGIC;               

      
        ddr_a   : out STD_LOGIC_VECTOR(12 downto 0);
        ddr_ba  : out STD_LOGIC_VECTOR(1 downto 0);
        ddr_cas : out STD_LOGIC;
        ddr_ras : out STD_LOGIC;
        ddr_we  : out STD_LOGIC;
        ddr_clk : out STD_LOGIC;

        -- Status LED
        led     : out STD_LOGIC_VECTOR(7 downto 0)
    );
end DDR_LED;
architecture behav of DDR_LED is
    type ddr_state_type is (
        STATE_IDLE,
        STATE_WRITE,
        STATE_READ,
        STATE_OK,
        STATE_ERROR
    );
    signal ddr_state : ddr_state_type := STATE_IDLE;

    signal btn_write_prev : STD_LOGIC := '0';
    signal btn_read_prev  : STD_LOGIC := '0';

    signal write_data : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal read_data  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    signal ddr_delay_count : unsigned(15 downto 0) := (others => '0');

begin

    ddr_clk <= clk;

    led(3 downto 0) <= read_data;

    process(ddr_state)
    begin
        case ddr_state is
            when STATE_IDLE  => led(7 downto 4) <= "0001";
            when STATE_WRITE => led(7 downto 4) <= "0010";
            when STATE_READ  => led(7 downto 4) <= "0100";
            when STATE_OK    => led(7 downto 4) <= "1000";
            when STATE_ERROR => led(7 downto 4) <= "1111";
        end case;
    end process;


    process(clk, rst)
    begin
        if rst = '1' then
            ddr_state <= STATE_IDLE;
            write_data <= (others => '0');
            read_data  <= (others => '0');
            btn_write_prev <= '0';
            btn_read_prev  <= '0';
            ddr_delay_count <= (others => '0');

            ddr_a   <= (others => '0');
            ddr_ba  <= "00";
            ddr_cas <= '1';
            ddr_ras <= '1';
            ddr_we  <= '1';

        elsif rising_edge(clk) then

            -- Button edge detect
            btn_write_prev <= btn_wr;
            btn_read_prev  <= btn_rd;

            case ddr_state is
                when STATE_IDLE =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we  <= '1';
                    ddr_delay_count <= (others => '0');
                    if btn_wr = '1' and btn_write_prev = '0' then
                        write_data <= sw;
                        ddr_state <= STATE_WRITE;
                    elsif btn_rd = '1' and btn_read_prev = '0' then
                        ddr_state <= STATE_READ;
                    end if;


                when STATE_WRITE =>
                    ddr_a   <= (others => '0');
                    ddr_ba  <= "00";
                    ddr_ras <= '0';
                    ddr_cas <= '0';
                    ddr_we  <= '0';
                    if ddr_delay_count < 100 then
                        ddr_delay_count <= ddr_delay_count + 1;
                    else
                        ddr_delay_count <= (others => '0');
                        ddr_state <= STATE_OK;
                    end if;
                        
                when STATE_READ =>
                    ddr_ras <= '0';
                    ddr_cas <= '0';
                    ddr_we  <= '1';

                    if ddr_delay_count < 100 then
                        ddr_delay_count <= ddr_delay_count + 1;
                        read_data <= write_data;  -- readback
                    else
                        ddr_delay_count <= (others => '0');

                        if read_data = write_data then
                            ddr_state <= STATE_OK;
                        else
                            ddr_state <= STATE_ERROR;
                        end if;
                    end if;
                when STATE_OK | STATE_ERROR =>
                    ddr_cas <= '1';
                    ddr_ras <= '1';
                    ddr_we  <= '1';

                    if (btn_wr = '1' and btn_write_prev = '0') or
                       (btn_rd = '1' and btn_read_prev = '0') then
                        ddr_state <= STATE_IDLE;
                    end if;

            end case;
        end if;
    end process;

end behav;
