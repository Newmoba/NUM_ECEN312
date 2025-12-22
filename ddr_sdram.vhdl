--------------------------------------------------------------------------------
-- DDR SDRAM Demonstration Project for Spartan-3E Starter Kit
-- Top Level Module
--------------------------------------------------------------------------------
-- This module connects all components together and interfaces with the board
-- Inputs: 4 switches, 4 buttons, 50MHz clock
-- Outputs: 8 LEDs, LCD display, DDR SDRAM interface
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_sdram is
    Port (
        -- Clock and Reset
        clk_50mhz    : in  STD_LOGIC;  -- 50 MHz system clock
        btn_west     : in  STD_LOGIC;  -- Reset button
        
        -- User Inputs
        sw           : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4 slide switches for data input
        btn_north    : in  STD_LOGIC;  -- Write command
        btn_south    : in  STD_LOGIC;  -- Read command
        btn_east     : in  STD_LOGIC;  -- Increment address
        
        -- User Outputs
        led          : out STD_LOGIC_VECTOR(7 downto 0);  -- 8 LEDs for data display
        lcd_e        : out STD_LOGIC;  -- LCD Enable
        lcd_rs       : out STD_LOGIC;  -- LCD Register Select
        lcd_rw       : out STD_LOGIC;  -- LCD Read/Write
        lcd_data     : out STD_LOGIC_VECTOR(3 downto 0);  -- LCD 4-bit data
        
        -- DDR SDRAM Interface (Micron MT46V32M16)
        ddr_clk      : out   STD_LOGIC;
        ddr_clk_n    : out   STD_LOGIC;
        ddr_cke      : out   STD_LOGIC;
        ddr_cs_n     : out   STD_LOGIC;
        ddr_ras_n    : out   STD_LOGIC;
        ddr_cas_n    : out   STD_LOGIC;
        ddr_we_n     : out   STD_LOGIC;
        ddr_ba       : out   STD_LOGIC_VECTOR(1 downto 0);
        ddr_addr     : out   STD_LOGIC_VECTOR(12 downto 0);
        ddr_dq       : inout STD_LOGIC_VECTOR(15 downto 0);
        ddr_dqs      : inout STD_LOGIC_VECTOR(1 downto 0);
        ddr_dm       : out   STD_LOGIC_VECTOR(1 downto 0);
        ddr_udqs     : inout STD_LOGIC;
        ddr_ldqs     : inout STD_LOGIC
    );
end ddr_sdram;

architecture Behavioral of ddr_sdram is

    -- Component Declarations
    component button_debouncer is
        Port (
            clk       : in  STD_LOGIC;
            btn_in    : in  STD_LOGIC;
            btn_out   : out STD_LOGIC
        );
    end component;
    
    component sdram_controller is
        Port (
            clk           : in    STD_LOGIC;
            reset         : in    STD_LOGIC;
            cmd_write     : in    STD_LOGIC;
            cmd_read      : in    STD_LOGIC;
            addr          : in    STD_LOGIC_VECTOR(7 downto 0);
            data_in       : in    STD_LOGIC_VECTOR(15 downto 0);
            data_out      : out   STD_LOGIC_VECTOR(15 downto 0);
            busy          : out   STD_LOGIC;
            ready         : out   STD_LOGIC;
            -- DDR Interface
            ddr_clk       : out   STD_LOGIC;
            ddr_clk_n     : out   STD_LOGIC;
            ddr_cke       : out   STD_LOGIC;
            ddr_cs_n      : out   STD_LOGIC;
            ddr_ras_n     : out   STD_LOGIC;
            ddr_cas_n     : out   STD_LOGIC;
            ddr_we_n      : out   STD_LOGIC;
            ddr_ba        : out   STD_LOGIC_VECTOR(1 downto 0);
            ddr_addr      : out   STD_LOGIC_VECTOR(12 downto 0);
            ddr_dq        : inout STD_LOGIC_VECTOR(15 downto 0);
            ddr_dqs       : inout STD_LOGIC_VECTOR(1 downto 0);
            ddr_dm        : out   STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;
    
    component lcd_controller is
        Port (
            clk       : in  STD_LOGIC;
            reset     : in  STD_LOGIC;
            address   : in  STD_LOGIC_VECTOR(7 downto 0);
            data      : in  STD_LOGIC_VECTOR(7 downto 0);
            status    : in  STD_LOGIC_VECTOR(7 downto 0);
            lcd_e     : out STD_LOGIC;
            lcd_rs    : out STD_LOGIC;
            lcd_rw    : out STD_LOGIC;
            lcd_data  : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    -- Internal Signals
    signal reset          : STD_LOGIC;
    signal btn_write_db   : STD_LOGIC;
    signal btn_read_db    : STD_LOGIC;
    signal btn_addr_db    : STD_LOGIC;
    
    signal cmd_write      : STD_LOGIC := '0';
    signal cmd_read       : STD_LOGIC := '0';
    signal cmd_addr_inc   : STD_LOGIC := '0';
    
    signal address        : unsigned(7 downto 0) := (others => '0');
    signal write_data     : STD_LOGIC_VECTOR(15 downto 0);
    signal read_data      : STD_LOGIC_VECTOR(15 downto 0);
    signal sdram_busy     : STD_LOGIC;
    signal sdram_ready    : STD_LOGIC;
    
    signal lcd_status     : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Edge detection for buttons
    signal btn_write_prev : STD_LOGIC := '0';
    signal btn_read_prev  : STD_LOGIC := '0';
    signal btn_addr_prev  : STD_LOGIC := '0';

begin

    -- Reset is active high (button pressed = '1' after debouncing)
    reset <= btn_west;
    
    -- Prepare write data from switches (extended to 16 bits)
    write_data <= "000000000000" & sw;
    
    -- Display read data on LEDs
    led <= read_data(7 downto 0);
    
    -- LCD status byte encoding
    lcd_status <= "000000" & sdram_ready & sdram_busy;
    
    -------------------------------------------------------------------
    -- Button Debouncers
    -- These clean up the mechanical button bounces to produce clean edges
    -------------------------------------------------------------------
    debounce_write: button_debouncer
        port map (
            clk     => clk_50mhz,
            btn_in  => btn_north,
            btn_out => btn_write_db
        );
    
    debounce_read: button_debouncer
        port map (
            clk     => clk_50mhz,
            btn_in  => btn_south,
            btn_out => btn_read_db
        );
    
    debounce_addr: button_debouncer
        port map (
            clk     => clk_50mhz,
            btn_in  => btn_east,
            btn_out => btn_addr_db
        );
    
    -------------------------------------------------------------------
    -- Edge Detector Process
    -- Detects rising edges on debounced buttons to generate single-cycle pulses
    -------------------------------------------------------------------
    edge_detect: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            -- Default: no commands
            cmd_write <= '0';
            cmd_read <= '0';
            cmd_addr_inc <= '0';
            
            if reset = '1' then
                btn_write_prev <= '0';
                btn_read_prev <= '0';
                btn_addr_prev <= '0';
            else
                -- Detect rising edges
                if btn_write_db = '1' and btn_write_prev = '0' then
                    cmd_write <= '1';
                end if;
                
                if btn_read_db = '1' and btn_read_prev = '0' then
                    cmd_read <= '1';
                end if;
                
                if btn_addr_db = '1' and btn_addr_prev = '0' then
                    cmd_addr_inc <= '1';
                end if;
                
                -- Store previous states
                btn_write_prev <= btn_write_db;
                btn_read_prev <= btn_read_db;
                btn_addr_prev <= btn_addr_db;
            end if;
        end if;
    end process;
    
    -------------------------------------------------------------------
    -- Address Counter
    -- Increments address when button is pressed
    -------------------------------------------------------------------
    addr_counter: process(clk_50mhz)
    begin
        if rising_edge(clk_50mhz) then
            if reset = '1' then
                address <= (others => '0');
            elsif cmd_addr_inc = '1' then
                address <= address + 1;
            end if;
        end if;
    end process;
    
    -------------------------------------------------------------------
    -- SDRAM Controller Instance
    -- Handles all DDR SDRAM initialization and read/write operations
    -------------------------------------------------------------------
    sdram_ctrl: sdram_controller
        port map (
            clk       => clk_50mhz,
            reset     => reset,
            cmd_write => cmd_write,
            cmd_read  => cmd_read,
            addr      => std_logic_vector(address),
            data_in   => write_data,
            data_out  => read_data,
            busy      => sdram_busy,
            ready     => sdram_ready,
            -- DDR pins
            ddr_clk   => ddr_clk,
            ddr_clk_n => ddr_clk_n,
            ddr_cke   => ddr_cke,
            ddr_cs_n  => ddr_cs_n,
            ddr_ras_n => ddr_ras_n,
            ddr_cas_n => ddr_cas_n,
            ddr_we_n  => ddr_we_n,
            ddr_ba    => ddr_ba,
            ddr_addr  => ddr_addr,
            ddr_dq    => ddr_dq,
            ddr_dqs   => ddr_dqs,
            ddr_dm    => ddr_dm
        );
    
    -- Connect DQS signals (upper and lower byte strobes)
    ddr_udqs <= ddr_dqs(1);
    ddr_ldqs <= ddr_dqs(0);
    
    -------------------------------------------------------------------
    -- LCD Controller Instance
    -- Displays current address and data on LCD screen
    -------------------------------------------------------------------
    lcd_ctrl: lcd_controller
        port map (
            clk      => clk_50mhz,
            reset    => reset,
            address  => std_logic_vector(address),
            data     => read_data(7 downto 0),
            status   => lcd_status,
            lcd_e    => lcd_e,
            lcd_rs   => lcd_rs,
            lcd_rw   => lcd_rw,
            lcd_data => lcd_data
        );

end Behavioral;
