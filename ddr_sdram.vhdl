
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ddr_sdram is
    Port (
        -- System Clock and Reset
        CLK_50MHZ    : in  STD_LOGIC;  -- 50MHz system clock from oscillator
        BTN_SOUTH    : in  STD_LOGIC;  -- Reset button (active high)
        
        -- User Input Interface
        SW           : in  STD_LOGIC_VECTOR(3 downto 0);  -- 4 slide switches for data input
        BTN_NORTH    : in  STD_LOGIC;  -- Write button: writes SW data to DDR
        BTN_EAST     : in  STD_LOGIC;  -- Read button: reads DDR data to LEDs
        BTN_WEST     : in  STD_LOGIC;  -- Address increment button
        
        -- User Output Interface
        LED          : out STD_LOGIC_VECTOR(7 downto 0);  -- Display read data (lower 8 bits)
        
        -- LCD Display Interface (16 characters x 2 lines)
        LCD_E        : out STD_LOGIC;                      -- LCD Enable signal
        LCD_RS       : out STD_LOGIC;                      -- LCD Register Select (0=Command, 1=Data)
        LCD_RW       : out STD_LOGIC;                      -- LCD Read/Write (0=Write, 1=Read)
        LCD_DB       : out STD_LOGIC_VECTOR(7 downto 4);  -- LCD Data Bus (4-bit mode, upper nibble)
        
        -- DDR SDRAM Interface (Micron MT46V32M16 - 512Mbit, 16-bit data)
        DDR_CLK_P    : out   STD_LOGIC;                       -- DDR Clock positive
        DDR_CLK_N    : out   STD_LOGIC;                       -- DDR Clock negative (differential)
        DDR_CKE      : out   STD_LOGIC;                       -- Clock Enable
        DDR_CS_N     : out   STD_LOGIC;                       -- Chip Select (active low)
        DDR_RAS_N    : out   STD_LOGIC;                       -- Row Address Strobe (active low)
        DDR_CAS_N    : out   STD_LOGIC;                       -- Column Address Strobe (active low)
        DDR_WE_N     : out   STD_LOGIC;                       -- Write Enable (active low)
        DDR_BA       : out   STD_LOGIC_VECTOR(1 downto 0);   -- Bank Address (4 banks)
        DDR_A        : out   STD_LOGIC_VECTOR(12 downto 0);  -- Row/Column Address
        DDR_DM       : out   STD_LOGIC_VECTOR(1 downto 0);   -- Data Mask (for byte writes)
        DDR_DQS      : inout STD_LOGIC_VECTOR(1 downto 0);   -- Data Strobe (bidirectional)
        DDR_DQ       : inout STD_LOGIC_VECTOR(15 downto 0)   -- Data Bus (16-bit)
    );
end ddr_sdram;

architecture Behavioral of ddr_sdram is

    --========================================================================
    -- BUTTON DEBOUNCER SECTION
    -- Purpose: Eliminate mechanical switch bounce on button presses
    -- Debounce time: 20ms (1,000,000 clock cycles at 50MHz)
    --========================================================================
    constant DEBOUNCE_TIME : integer := 1_000_000;  -- 20ms at 50MHz
    
    -- Record type to hold debouncer state for each button
    type debounce_state is record
        counter : integer range 0 to DEBOUNCE_TIME;  -- Counts stable time
        sync : STD_LOGIC_VECTOR(1 downto 0);         -- 2-stage synchronizer (metastability protection)
        stable : STD_LOGIC;                          -- Debounced output
    end record;
    
    -- Debouncer state for each button
    signal btn_write_state : debounce_state;  -- BTN_NORTH (Write)
    signal btn_read_state : debounce_state;   -- BTN_EAST (Read)
    signal btn_addr_state : debounce_state;   -- BTN_WEST (Address increment)
    
    -- Debounced button outputs
    signal btn_write_db : STD_LOGIC;
    signal btn_read_db : STD_LOGIC;
    signal btn_addr_db : STD_LOGIC;
    
    -- Edge detection signals (detect rising edge of button press)
    signal btn_write_prev : STD_LOGIC;
    signal btn_read_prev : STD_LOGIC;
    signal btn_addr_prev : STD_LOGIC;
    signal btn_write_edge : STD_LOGIC;  -- Single-cycle pulse on button press
    signal btn_read_edge : STD_LOGIC;
    signal btn_addr_edge : STD_LOGIC;
    
    --========================================================================
    -- LCD CONTROLLER SECTION
    -- Purpose: Drive 16x2 character LCD in 4-bit mode
    -- Display Format:
    --   Line 1: "Addr:XXXX Wr/Rd"  (shows current address and operation)
    --   Line 2: "Data:XXXX      "  (shows current data value)
    --========================================================================
    
    -- LCD State Machine States
    type lcd_state_type is (
        POWER_UP,        -- Initial power-up wait (>40ms)
        INIT_1,          -- First initialization command
        INIT_2,          -- Second initialization command
        INIT_3,          -- Third initialization command
        INIT_4,          -- Switch to 4-bit mode
        FUNCTION_SET,    -- Configure: 4-bit, 2 lines, 5x8 font
        DISPLAY_ON,      -- Turn display on, cursor off
        CLEAR_DISPLAY,   -- Clear display RAM
        ENTRY_MODE,      -- Set entry mode: increment, no shift
        READY,           -- Ready to write characters
        WRITE_CHAR,      -- Writing character (2-phase: high nibble, low nibble)
        WAIT_CHAR        -- Wait between characters
    );
    signal lcd_state : lcd_state_type := POWER_UP;
    
    -- LCD control signals
    signal lcd_data : STD_LOGIC_VECTOR(7 downto 0);  -- Current byte to send
    signal lcd_rs_i : STD_LOGIC := '0';              -- Internal RS signal
    signal lcd_e_i  : STD_LOGIC := '0';              -- Internal Enable signal
    
    -- LCD timing counters
    signal lcd_init_wait_count : integer := 0;  -- For long delays (ms range)
    signal lcd_enable_count : integer := 0;     -- For enable pulse timing (us range)
    signal lcd_char_pos : integer range 0 to 31 := 0;  -- Current character position (0-15: line1, 16-31: line2)
    
    -- LCD timing constants
    constant LCD_INIT_WAIT : integer := 2_500_000;  -- 50ms at 50MHz (power-up delay)
    constant LCD_ENABLE_CYCLE : integer := 50;      -- 1us enable pulse at 50MHz
    
    -- Display buffer: stores all 32 characters (16 chars x 2 lines)
    type char_array is array (0 to 31) of STD_LOGIC_VECTOR(7 downto 0);
    signal display_buffer : char_array;
    
    --========================================================================
    -- DDR CONTROLLER SECTION
    -- Purpose: Control DDR SDRAM operations (init, refresh, read, write)
    -- Note: This is a simplified controller for educational purposes
    --       For production, use Xilinx MIG (Memory Interface Generator)
    --========================================================================
    
    -- DDR Command Encodings (RAS, CAS, WE signals)
    constant CMD_NOP       : STD_LOGIC_VECTOR(2 downto 0) := "111";  -- No operation
    constant CMD_PRECHARGE : STD_LOGIC_VECTOR(2 downto 0) := "010";  -- Precharge banks
    constant CMD_REFRESH   : STD_LOGIC_VECTOR(2 downto 0) := "001";  -- Auto-refresh
    constant CMD_LOAD_MODE : STD_LOGIC_VECTOR(2 downto 0) := "000";  -- Load mode register
    constant CMD_ACTIVE    : STD_LOGIC_VECTOR(2 downto 0) := "011";  -- Activate row
    constant CMD_WRITE     : STD_LOGIC_VECTOR(2 downto 0) := "100";  -- Write data
    constant CMD_READ      : STD_LOGIC_VECTOR(2 downto 0) := "101";  -- Read data
    
    -- DDR State Machine States
    type ddr_state_type is (
        INIT_WAIT,        -- Wait 200us after power-up for DDR to stabilize
        INIT_PRECHARGE,   -- Precharge all banks
        INIT_REFRESH_1,   -- First auto-refresh cycle
        INIT_REFRESH_2,   -- Second auto-refresh cycle
        INIT_MODE_REG,    -- Program mode register (CAS latency, burst length, etc.)
        IDLE,             -- Ready for commands, handle refresh
        ACTIVATE,         -- Activate a row (open row for read/write)
        WRITE_CMD,        -- Issue write command
        WRITE_DATA,       -- Write data phase
        READ_CMD,         -- Issue read command
        READ_DATA,        -- Read data phase (wait for CAS latency)
        PRECHARGE_CMD     -- Precharge bank after operation
    );
    signal ddr_state : ddr_state_type := INIT_WAIT;
    
    -- DDR control and timing signals
    signal ddr_init_counter : integer := 0;      -- Counts initialization delay
    signal ddr_refresh_counter : integer := 0;   -- Tracks time since last refresh
    signal ddr_cmd_counter : integer := 0;       -- Counts command timing cycles
    signal ddr_cmd_int : STD_LOGIC_VECTOR(2 downto 0);  -- Current DDR command
    signal ddr_init_done : STD_LOGIC := '0';     -- '1' when initialization complete
    signal ddr_busy : STD_LOGIC := '1';          -- '1' when controller is busy
    
    -- DDR Timing Parameters (simplified for 50MHz operation)
    -- Note: These are conservative values. Real DDR timing depends on speed grade
    constant DDR_INIT_WAIT_CYCLES : integer := 10000;  -- 200us at 50MHz
    constant DDR_REFRESH_INTERVAL : integer := 390;    -- 7.8us refresh period
    constant tRP  : integer := 2;   -- Precharge command period (row precharge time)
    constant tRCD : integer := 2;   -- RAS to CAS delay (row to column delay)
    constant tCAS : integer := 2;   -- CAS latency (column access strobe latency)
    constant tWR  : integer := 2;   -- Write recovery time
    
    -- DDR Address Decomposition
    -- Full address: [23:22]=Bank, [21:9]=Row, [8:0]=Column
    signal ddr_bank_addr : STD_LOGIC_VECTOR(1 downto 0);   -- 2-bit bank address (4 banks)
    signal ddr_row_addr : STD_LOGIC_VECTOR(12 downto 0);   -- 13-bit row address
    signal ddr_col_addr : STD_LOGIC_VECTOR(9 downto 0);    -- 10-bit column address
    
    -- DDR Data Path
    signal ddr_read_data_buf : STD_LOGIC_VECTOR(15 downto 0);   -- Buffer for read data
    signal ddr_write_data_buf : STD_LOGIC_VECTOR(15 downto 0);  -- Buffer for write data
    signal ddr_data_valid : STD_LOGIC := '0';                    -- '1' when read data is valid
    
    -- DDR Clock signals
    signal ddr_clk : STD_LOGIC;  -- DDR clock (same as system clock in this simple design)
    
    -- DDR User Interface (connects to main control FSM)
    signal ddr_user_cmd : STD_LOGIC_VECTOR(2 downto 0);      -- Command from user (000=NOP, 001=Write, 010=Read)
    signal ddr_user_cmd_valid : STD_LOGIC;                    -- Command valid strobe
    signal ddr_user_addr : STD_LOGIC_VECTOR(23 downto 0);    -- Address from user
    signal ddr_user_wr_data : STD_LOGIC_VECTOR(15 downto 0); -- Write data from user
    
    --========================================================================
    -- MAIN CONTROL SECTION
    -- Purpose: High-level control logic coordinating all operations
    --========================================================================
    signal reset : STD_LOGIC;       -- System reset
    signal clk_sys : STD_LOGIC;     -- System clock (50MHz)
    
    -- User data registers
    signal address_reg : unsigned(15 downto 0) := (others => '0');  -- Current memory address
    signal write_data_reg : STD_LOGIC_VECTOR(15 downto 0);          -- Data to write (from switches)
    signal read_data_reg : STD_LOGIC_VECTOR(15 downto 0);           -- Data read from DDR (displayed on LEDs)
    
    -- LCD display mode indicator
    signal lcd_mode : STD_LOGIC_VECTOR(1 downto 0);  -- 00=idle, 01=write, 10=read
    
    -- Main Control State Machine
    type main_state_type is (
        IDLE,        -- Waiting for button press
        WRITE_CMD,   -- Issuing write command to DDR
        WRITE_WAIT,  -- Waiting for write to complete
        READ_CMD,    -- Issuing read command to DDR
        READ_WAIT    -- Waiting for read data
    );
    signal main_state : main_state_type := IDLE;
    
    --========================================================================
    -- HELPER FUNCTIONS
    --========================================================================
    
    -- Convert 4-bit hex value to ASCII character
    -- Used for displaying hex values on LCD
    function hex_to_ascii(hex : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
        variable ascii : STD_LOGIC_VECTOR(7 downto 0);
    begin
        case hex is
            when x"0" => ascii := x"30";  -- '0'
            when x"1" => ascii := x"31";  -- '1'
            when x"2" => ascii := x"32";  -- '2'
            when x"3" => ascii := x"33";  -- '3'
            when x"4" => ascii := x"34";  -- '4'
            when x"5" => ascii := x"35";  -- '5'
            when x"6" => ascii := x"36";  -- '6'
            when x"7" => ascii := x"37";  -- '7'
            when x"8" => ascii := x"38";  -- '8'
            when x"9" => ascii := x"39";  -- '9'
            when x"A" => ascii := x"41";  -- 'A'
            when x"B" => ascii := x"42";  -- 'B'
            when x"C" => ascii := x"43";  -- 'C'
            when x"D" => ascii := x"44";  -- 'D'
            when x"E" => ascii := x"45";  -- 'E'
            when x"F" => ascii := x"46";  -- 'F'
            when others => ascii := x"3F";  -- '?'
        end case;
        return ascii;
    end function;

begin

    -- Connect system signals
    clk_sys <= CLK_50MHZ;
    reset <= BTN_SOUTH;
    
    -- Expand 4-bit switch input to 16-bit data (pad with zeros)
    write_data_reg <= x"000" & SW;
    
    --========================================================================
    -- BUTTON DEBOUNCER PROCESS - BTN_NORTH (Write Button)
    -- Implements: 2-stage synchronizer + debounce counter
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            -- Reset debouncer state
            btn_write_state.counter <= 0;
            btn_write_state.sync <= "00";
            btn_write_state.stable <= '0';
        elsif rising_edge(clk_sys) then
            -- Stage 1 & 2: Synchronize button input (metastability protection)
            btn_write_state.sync <= btn_write_state.sync(0) & BTN_NORTH;
            
            -- Debounce logic: button must be stable for DEBOUNCE_TIME cycles
            if btn_write_state.sync(1) /= btn_write_state.stable then
                -- Button state is different from stable output
                btn_write_state.counter <= btn_write_state.counter + 1;
                if btn_write_state.counter >= DEBOUNCE_TIME then
                    -- Button has been stable long enough, update output
                    btn_write_state.stable <= btn_write_state.sync(1);
                    btn_write_state.counter <= 0;
                end if;
            else
                -- Button matches stable state, reset counter
                btn_write_state.counter <= 0;
            end if;
        end if;
    end process;
    btn_write_db <= btn_write_state.stable;
    
    --========================================================================
    -- BUTTON DEBOUNCER PROCESS - BTN_EAST (Read Button)
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            btn_read_state.counter <= 0;
            btn_read_state.sync <= "00";
            btn_read_state.stable <= '0';
        elsif rising_edge(clk_sys) then
            btn_read_state.sync <= btn_read_state.sync(0) & BTN_EAST;
            if btn_read_state.sync(1) /= btn_read_state.stable then
                btn_read_state.counter <= btn_read_state.counter + 1;
                if btn_read_state.counter >= DEBOUNCE_TIME then
                    btn_read_state.stable <= btn_read_state.sync(1);
                    btn_read_state.counter <= 0;
                end if;
            else
                btn_read_state.counter <= 0;
            end if;
        end if;
    end process;
    btn_read_db <= btn_read_state.stable;
    
    --========================================================================
    -- BUTTON DEBOUNCER PROCESS - BTN_WEST (Address Increment Button)
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            btn_addr_state.counter <= 0;
            btn_addr_state.sync <= "00";
            btn_addr_state.stable <= '0';
        elsif rising_edge(clk_sys) then
            btn_addr_state.sync <= btn_addr_state.sync(0) & BTN_WEST;
            if btn_addr_state.sync(1) /= btn_addr_state.stable then
                btn_addr_state.counter <= btn_addr_state.counter + 1;
                if btn_addr_state.counter >= DEBOUNCE_TIME then
                    btn_addr_state.stable <= btn_addr_state.sync(1);
                    btn_addr_state.counter <= 0;
                end if;
            else
                btn_addr_state.counter <= 0;
            end if;
        end if;
    end process;
    btn_addr_db <= btn_addr_state.stable;
    
    --========================================================================
    -- EDGE DETECTION FOR BUTTONS
    -- Purpose: Generate single-cycle pulse on rising edge of debounced button
    -- This prevents multiple operations from a single button press
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            btn_write_prev <= '0';
            btn_read_prev <= '0';
            btn_addr_prev <= '0';
        elsif rising_edge(clk_sys) then
            -- Store previous button state
            btn_write_prev <= btn_write_db;
            btn_read_prev <= btn_read_db;
            btn_addr_prev <= btn_addr_db;
        end if;
    end process;
    
    -- Generate edge pulses: high for one clock cycle when button is pressed
    btn_write_edge <= btn_write_db and not btn_write_prev;
    btn_read_edge <= btn_read_db and not btn_read_prev;
    btn_addr_edge <= btn_addr_db and not btn_addr_prev;
    
    --========================================================================
    -- ADDRESS COUNTER
    -- Purpose: Track current memory address
    -- Increments on BTN_WEST press, wraps around at 0xFFFF
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            address_reg <= (others => '0');
        elsif rising_edge(clk_sys) then
            if btn_addr_edge = '1' then
                address_reg <= address_reg + 1;  -- Increment address
            end if;
        end if;
    end process;
    
    --========================================================================
    -- LCD DISPLAY BUFFER UPDATE
    -- Purpose: Update the 32-character display buffer with current values
    -- Buffer Layout:
    --   Positions 0-15:  Line 1 - "Addr:XXXX Wr/Rd"
    --   Positions 16-31: Line 2 - "Data:XXXX      "
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            -- Initialize display buffer with default text
            -- Line 1: "Addr:0000       "
            display_buffer(0)  <= x"41"; -- 'A'
            display_buffer(1)  <= x"64"; -- 'd'
            display_buffer(2)  <= x"64"; -- 'd'
            display_buffer(3)  <= x"72"; -- 'r'
            display_buffer(4)  <= x"3A"; -- ':'
            display_buffer(5)  <= x"30"; -- '0'
            display_buffer(6)  <= x"30"; -- '0'
            display_buffer(7)  <= x"30"; -- '0'
            display_buffer(8)  <= x"30"; -- '0'
            display_buffer(9)  <= x"20"; -- ' '
            display_buffer(10) <= x"20"; -- ' '
            display_buffer(11) <= x"20"; -- ' '
            display_buffer(12) <= x"20"; -- ' '
            display_buffer(13) <= x"20"; -- ' '
            display_buffer(14) <= x"20"; -- ' '
            display_buffer(15) <= x"20"; -- ' '
            
            -- Line 2: "Data:0000       "
            display_buffer(16) <= x"44"; -- 'D'
            display_buffer(17) <= x"61"; -- 'a'
            display_buffer(18) <= x"74"; -- 't'
            display_buffer(19) <= x"61"; -- 'a'
            display_buffer(20) <= x"3A"; -- ':'
            display_buffer(21) <= x"30"; -- '0'
            display_buffer(22) <= x"30"; -- '0'
            display_buffer(23) <= x"30"; -- '0'
            display_buffer(24) <= x"30"; -- '0'
            display_buffer(25) <= x"20"; -- ' '
            display_buffer(26) <= x"20"; -- ' '
            display_buffer(27) <= x"20"; -- ' '
            display_buffer(28) <= x"20"; -- ' '
            display_buffer(29) <= x"20"; -- ' '
            display_buffer(30) <= x"20"; -- ' '
            display_buffer(31) <= x"20"; -- ' '
        elsif rising_edge(clk_sys) then
            -- Continuously update address display (positions 5-8)
            display_buffer(5) <= hex_to_ascii(std_logic_vector(address_reg(15 downto 12)));
            display_buffer(6) <= hex_to_ascii(std_logic_vector(address_reg(11 downto 8)));
            display_buffer(7) <= hex_to_ascii(std_logic_vector(address_reg(7 downto 4)));
            display_buffer(8) <= hex_to_ascii(std_logic_vector(address_reg(3 downto 0)));
            
            -- Continuously update data display (positions 21-24)
            display_buffer(21) <= hex_to_ascii(read_data_reg(15 downto 12));
            display_buffer(22) <= hex_to_ascii(read_data_reg(11 downto 8));
            display_buffer(23) <= hex_to_ascii(read_data_reg(7 downto 4));
            display_buffer(24) <= hex_to_ascii(read_data_reg(3 downto 0));
            
            -- Update operation status indicator (positions 10-11)
            if lcd_mode = "01" then  -- Write mode
                display_buffer(10) <= x"57"; -- 'W'
                display_buffer(11) <= x"72"; -- 'r'
            elsif lcd_mode = "10" then  -- Read mode
                display_buffer(10) <= x"52"; -- 'R'
                display_buffer(11) <= x"64"; -- 'd'
            else  -- Idle mode
                display_buffer(10) <= x"20"; -- ' '
                display_buffer(11) <= x"20"; -- ' '
            end if;
        end if;
    end process;
    
    --========================================================================
    -- LCD CONTROL STATE MACHINE
    -- Purpose: Initialize and continuously update 16x2 LCD display
    -- Protocol: HD44780 in 4-bit mode
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            lcd_state <= POWER_UP;
            lcd_init_wait_count <= 0;
            lcd_enable_count <= 0;
            lcd_char_pos <= 0;
            lcd_rs_i <= '0';
            lcd_e_i <= '0';
            lcd_data <= x"00";
        elsif rising_edge(clk_sys) then
            case lcd_state is
                -- POWER_UP: Wait >40ms for LCD to stabilize after power-on
                when POWER_UP =>
                    if lcd_init_wait_count < LCD_INIT_WAIT then
                        lcd_init_wait_count <= lcd_init_wait_count + 1;
                    else
                        lcd_init_wait_count <= 0;
                        lcd_state <= INIT_1;
                        lcd_data <= x"30";  -- Function set command (8-bit interface)
                    end if;
                
                -- INIT_1: First initialization command (wait >4.1ms)
                when INIT_1 =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE then
                        lcd_enable_count <= lcd_enable_count + 1;
                        lcd_e_i <= '1';  -- Enable high
                    else
                        lcd_e_i <= '0';  -- Enable low (falling edge latches command)
                        lcd_enable_count <= 0;
                        if lcd_init_wait_count < 250_000 then  -- 5ms delay
                            lcd_init_wait_count <= lcd_init_wait_count + 1;
                        else
                            lcd_init_wait_count <= 0;
                            lcd_state <= INIT_2;
                        end if;
                    end if;
                
                -- INIT_2: Second initialization command (wait >100us)
                when INIT_2 =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE then
                        lcd_enable_count <= lcd_enable_count + 1;
                        lcd_e_i <= '1';
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        if lcd_init_wait_count < 5_000 then  -- 100us delay
                            lcd_init_wait_count <= lcd_init_wait_count + 1;
                        else
                            lcd_init_wait_count <= 0;
                            lcd_state <= INIT_3;
                        end if;
                    end if;
                
                -- INIT_3: Third initialization command
                when INIT_3 =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE then
                        lcd_enable_count <= lcd_enable_count + 1;
                        lcd_e_i <= '1';
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state <= DISPLAY_ON;
                        lcd_data <= x"0C";  -- Display ON, cursor OFF, blink OFF
                    end if;
                
                -- DISPLAY_ON: Turn on display, cursor off
                when DISPLAY_ON =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE * 2 then
                        if lcd_enable_count = 0 then
                            lcd_e_i <= '1';
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE then
                            lcd_e_i <= '0';
                            lcd_data <= lcd_data(3 downto 0) & x"0";
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE + 5 then
                            lcd_e_i <= '1';
                        end if;
                        lcd_enable_count <= lcd_enable_count + 1;
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state <= CLEAR_DISPLAY;
                        lcd_data <= x"01";  -- Clear display command
                    end if;
                
                -- CLEAR_DISPLAY: Clear all display RAM (takes ~1.6ms)
                when CLEAR_DISPLAY =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE * 2 then
                        if lcd_enable_count = 0 then
                            lcd_e_i <= '1';
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE then
                            lcd_e_i <= '0';
                            lcd_data <= lcd_data(3 downto 0) & x"0";
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE + 5 then
                            lcd_e_i <= '1';
                        end if;
                        lcd_enable_count <= lcd_enable_count + 1;
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        if lcd_init_wait_count < 100_000 then  -- 2ms delay for clear
                            lcd_init_wait_count <= lcd_init_wait_count + 1;
                        else
                            lcd_init_wait_count <= 0;
                            lcd_state <= ENTRY_MODE;
                            lcd_data <= x"06";  -- Entry mode: increment cursor, no display shift
                        end if;
                    end if;
                
                -- ENTRY_MODE: Set entry mode (cursor moves right after write)
                when ENTRY_MODE =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE * 2 then
                        if lcd_enable_count = 0 then
                            lcd_e_i <= '1';
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE then
                            lcd_e_i <= '0';
                            lcd_data <= lcd_data(3 downto 0) & x"0";
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE + 5 then
                            lcd_e_i <= '1';
                        end if;
                        lcd_enable_count <= lcd_enable_count + 1;
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state <= READY;
                        lcd_char_pos <= 0;
                    end if;
                
                -- READY: Prepare to write next character or command
                when READY =>
                    lcd_rs_i <= '1';  -- Data mode (writing characters)
                    if lcd_char_pos < 32 then
                        lcd_state <= WRITE_CHAR;
                        if lcd_char_pos = 16 then
                            -- Moving to line 2, send set DDRAM address command
                            lcd_data <= x"C0";  -- DDRAM address 0x40 (line 2 start)
                            lcd_rs_i <= '0';    -- Command mode
                        else
                            -- Write character from display buffer
                            lcd_data <= display_buffer(lcd_char_pos);
                        end if;
                    else
                        -- All characters written, return to home position
                        lcd_char_pos <= 0;
                        lcd_data <= x"80";  -- Return to home (DDRAM address 0x00)
                        lcd_rs_i <= '0';    -- Command mode
                    end if;
                
                -- WRITE_CHAR: Write character in 4-bit mode (2 nibbles)
                when WRITE_CHAR =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE * 2 then
                        if lcd_enable_count = 0 then
                            lcd_e_i <= '1';  -- High nibble enable
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE then
                            lcd_e_i <= '0';
                            lcd_data <= lcd_data(3 downto 0) & x"0";  -- Low nibble
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE + 5 then
                            lcd_e_i <= '1';  -- Low nibble enable
                        end if;
                        lcd_enable_count <= lcd_enable_count + 1;
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state <= WAIT_CHAR;
                    end if;
                
                -- WAIT_CHAR: Wait between characters (~50us)
                when WAIT_CHAR =>
                    if lcd_init_wait_count < 2500 then  -- 50us delay
                        lcd_init_wait_count <= lcd_init_wait_count + 1;
                    else
                        lcd_init_wait_count <= 0;
                        lcd_char_pos <= lcd_char_pos + 1;
                        lcd_state <= READY;
                    end if;
            end case;
        end if;
    end process;
    
    -- LCD output assignments
    LCD_E <= lcd_e_i;
    LCD_RS <= lcd_rs_i;
    LCD_RW <= '0';  -- Always write mode (never read from LCD)
    LCD_DB <= lcd_data(7 downto 4);  -- 4-bit mode: only upper nibble used
    
    --========================================================================
    -- DDR CLOCK GENERATION
    -- Note: Simple clock forwarding. For production, use DCM for phase control
    --========================================================================
    ddr_clk <= clk_sys;
    DDR_CLK_P <= ddr_clk;        -- Positive differential clock
    DDR_CLK_N <= not ddr_clk;    -- Negative differential clock (180° phase)
    
    --========================================================================
    -- DDR ADDRESS DECOMPOSITION
    -- 24-bit address → Bank(2) + Row(13) + Column(9)
    --========================================================================
    ddr_bank_addr <= ddr_user_addr(23 downto 22);  -- Bits [23:22] = Bank (4 banks: 00,01,10,11)
    ddr_row_addr <= ddr_user_addr(21 downto 9);    -- Bits [21:9]  = Row (8K rows)
    ddr_col_addr <= ddr_user_addr(8 downto 0) & '0';  -- Bits [8:0] = Column, LSB=0 (16-bit aligned)
    
    --========================================================================
    -- DDR CONTROLLER STATE MACHINE
    -- Purpose: Manage DDR SDRAM initialization and operations
    -- Protocol: Standard DDR SDRAM initialization sequence
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            -- Reset all DDR controller signals
            ddr_state <= INIT_WAIT;
            ddr_init_counter <= 0;
            ddr_refresh_counter <= 0;
            ddr_cmd_counter <= 0;
            ddr_cmd_int <= CMD_NOP;
            ddr_init_done <= '0';
            ddr_busy <= '1';
            ddr_data_valid <= '0';
            DDR_CKE <= '0';          -- Clock disabled during reset
            DDR_CS_N <= '1';         -- Chip deselected
            DDR_BA <= "00";
            DDR_A <= (others => '0');
            DDR_DM <= "00";          -- Data mask off (all bytes enabled)
        elsif rising_edge(clk_sys) then
            ddr_data_valid <= '0';  -- Default: no valid data this cycle
            
            case ddr_state is
                -- INIT_WAIT: Wait 200us after power-on for DDR to stabilize
                when INIT_WAIT =>
                    DDR_CKE <= '0';      -- Keep clock disabled
                    DDR_CS_N <= '1';     -- Chip deselected
                    ddr_cmd_int <= CMD_NOP;
                    if ddr_init_counter < DDR_INIT_WAIT_CYCLES then
                        ddr_init_counter <= ddr_init_counter + 1;
                    else
                        -- Stabilization complete, enable clock and proceed
                        DDR_CKE <= '1';
                        ddr_state <= INIT_PRECHARGE;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- INIT_PRECHARGE: Precharge all banks before initialization
                when INIT_PRECHARGE =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';              -- Select chip
                        ddr_cmd_int <= CMD_PRECHARGE;
                        DDR_A(10) <= '1';            -- A10=1 means precharge ALL banks
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < tRP then
                        -- Wait for precharge to complete (tRP cycles)
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= INIT_REFRESH_1;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- INIT_REFRESH_1: First auto-refresh cycle
                when INIT_REFRESH_1 =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_REFRESH;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < 8 then
                        -- Wait for refresh to complete (~8 cycles)
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= INIT_REFRESH_2;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- INIT_REFRESH_2: Second auto-refresh cycle
                -- (DDR spec requires at least 2 refresh cycles before mode register load)
                when INIT_REFRESH_2 =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_REFRESH;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < 8 then
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= INIT_MODE_REG;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- INIT_MODE_REG: Program mode register with operating parameters
                when INIT_MODE_REG =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_LOAD_MODE;
                        DDR_BA <= "00";  -- Mode register (not extended)
                        -- Mode Register Configuration:
                        -- Bit [12:10] = Reserved
                        -- Bit [9]     = 0 (Burst read/write)
                        -- Bit [8:7]   = 00 (Normal operation)
                        -- Bit [6:4]   = 010 (CAS Latency = 2)
                        -- Bit [3]     = 0 (Sequential burst)
                        -- Bit [2:0]   = 010 (Burst Length = 4)
                        DDR_A <= "0000000100010";  -- CAS=2, Burst=4, Sequential
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < 3 then
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        -- Initialization complete!
                        ddr_state <= IDLE;
                        ddr_init_done <= '1';  -- Signal to main controller
                        ddr_busy <= '0';       -- Ready for commands
                        ddr_refresh_counter <= 0;
                    end if;
                
                -- IDLE: Wait for user command or handle periodic refresh
                when IDLE =>
                    ddr_cmd_int <= CMD_NOP;
                    ddr_refresh_counter <= ddr_refresh_counter + 1;
                    
                    -- Check if refresh is needed (every 7.8us = 390 cycles @ 50MHz)
                    if ddr_refresh_counter >= DDR_REFRESH_INTERVAL then
                        ddr_busy <= '1';
                        ddr_state <= INIT_REFRESH_1;  -- Reuse refresh states
                        ddr_cmd_counter <= 0;
                        ddr_refresh_counter <= 0;
                    -- Check if user has issued a command
                    elsif ddr_user_cmd_valid = '1' and ddr_busy = '0' then
                        ddr_busy <= '1';
                        ddr_write_data_buf <= ddr_user_wr_data;  -- Latch write data
                        ddr_state <= ACTIVATE;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- ACTIVATE: Open a row for read or write
                when ACTIVATE =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_ACTIVE;
                        DDR_BA <= ddr_bank_addr;      -- Select bank
                        DDR_A <= ddr_row_addr;        -- Select row
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < tRCD then
                        -- Wait for row activation (tRCD = RAS to CAS delay)
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_cmd_counter <= 0;
                        -- Proceed to write or read based on user command
                        if ddr_user_cmd = "001" then
                            ddr_state <= WRITE_CMD;
                        elsif ddr_user_cmd = "010" then
                            ddr_state <= READ_CMD;
                        else
                            -- Invalid command, return to idle
                            ddr_state <= IDLE;
                            ddr_busy <= '0';
                        end if;
                    end if;
                
                -- WRITE_CMD: Issue write command with column address
                when WRITE_CMD =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_WRITE;
                        DDR_BA <= ddr_bank_addr;
                        DDR_A <= "000" & ddr_col_addr;  -- Column address
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= WRITE_DATA;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- WRITE_DATA: Data is written on DQ bus (handled by concurrent assignment below)
                when WRITE_DATA =>
                    ddr_cmd_int <= CMD_NOP;
                    if ddr_cmd_counter < tWR then
                        -- Wait for write recovery time
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= PRECHARGE_CMD;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- READ_CMD: Issue read command with column address
                when READ_CMD =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_READ;
                        DDR_BA <= ddr_bank_addr;
                        DDR_A <= "000" & ddr_col_addr;  -- Column address
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < tCAS then
                        -- Wait for CAS latency (data appears after tCAS cycles)
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= READ_DATA;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- READ_DATA: Capture data from DQ bus
                when READ_DATA =>
                    ddr_cmd_int <= CMD_NOP;
                    if ddr_cmd_counter = 0 then
                        ddr_read_data_buf <= DDR_DQ;  -- Latch read data
                        ddr_data_valid <= '1';         -- Signal valid data to user
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        ddr_state <= PRECHARGE_CMD;
                        ddr_cmd_counter <= 0;
                    end if;
                
                -- PRECHARGE_CMD: Close the active row
                when PRECHARGE_CMD =>
                    if ddr_cmd_counter = 0 then
                        DDR_CS_N <= '0';
                        ddr_cmd_int <= CMD_PRECHARGE;
                        DDR_BA <= ddr_bank_addr;
                        DDR_A(10) <= '0';  -- A10=0 means precharge single bank
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    elsif ddr_cmd_counter < tRP then
                        -- Wait for precharge to complete
                        ddr_cmd_int <= CMD_NOP;
                        ddr_cmd_counter <= ddr_cmd_counter + 1;
                    else
                        -- Operation complete, return to idle
                        ddr_state <= IDLE;
                        ddr_busy <= '0';
                    end if;
            end case;
        end if;
    end process;
    
    -- DDR Command Signal Assignments
    -- Commands are encoded as [RAS, CAS, WE]
    DDR_RAS_N <= '1' when ddr_cmd_int(2) = '1' else '0';
    DDR_CAS_N <= '1' when ddr_cmd_int(1) = '1' else '0';
    DDR_WE_N  <= '1' when ddr_cmd_int(0) = '1' else '0';
    
    -- DDR Data Bus
    -- Drive DQ during write, high-Z during read
    DDR_DQ <= ddr_write_data_buf when (ddr_state = WRITE_DATA) else (others => 'Z');
    
    -- DDR Data Strobe (DQS)
    -- Simplified: kept in high-Z. Real design requires precise DQS generation
    DDR_DQS <= "ZZ";
    
    --========================================================================
    -- MAIN CONTROL FSM
    -- Purpose: High-level state machine coordinating user operations
    -- Interfaces between button presses and DDR controller
    --========================================================================
    process(clk_sys, reset)
    begin
        if reset = '1' then
            main_state <= IDLE;
            ddr_user_cmd <= "000";          -- No command
            ddr_user_cmd_valid <= '0';
            read_data_reg <= (others => '0');
            lcd_mode <= "00";               -- Idle mode
        elsif rising_edge(clk_sys) then
            ddr_user_cmd_valid <= '0';  -- Default: no command this cycle
            
            case main_state is
                -- IDLE: Wait for button press
                when IDLE =>
                    lcd_mode <= "00";  -- Display idle status
                    if ddr_init_done = '1' then  -- Only accept commands after DDR initialized
                        if btn_write_edge = '1' then
                            -- User pressed write button
                            main_state <= WRITE_CMD;
                            lcd_mode <= "01";  -- Display "Wr" status
                        elsif btn_read_edge = '1' then
                            -- User pressed read button
                            main_state <= READ_CMD;
                            lcd_mode <= "10";  -- Display "Rd" status
                        end if;
                    end if;
                
                -- WRITE_CMD: Issue write command to DDR controller
                when WRITE_CMD =>
                    if ddr_busy = '0' then  -- Wait for DDR controller to be ready
                        ddr_user_cmd <= "001";      -- Write command
                        ddr_user_cmd_valid <= '1';  -- Command valid strobe
                        main_state <= WRITE_WAIT;
                    end if;
                
                -- WRITE_WAIT: Wait for write operation to complete
                when WRITE_WAIT =>
                    if ddr_busy = '0' then  -- DDR controller finished
                        main_state <= IDLE;
                    end if;
                
                -- READ_CMD: Issue read command to DDR controller
                when READ_CMD =>
                    if ddr_busy = '0' then  -- Wait for DDR controller to be ready
                        ddr_user_cmd <= "010";      -- Read command
                        ddr_user_cmd_valid <= '1';  -- Command valid strobe
                        main_state <= READ_WAIT;
                    end if;
                
                -- READ_WAIT: Wait for read data to become valid
                when READ_WAIT =>
                    if ddr_data_valid = '1' then  -- Data is ready
                        read_data_reg <= ddr_read_data_buf;  -- Latch data for LED display
                        main_state <= IDLE;
                    end if;
            end case;
        end if;
    end process;
    
    --========================================================================
    -- OUTPUT ASSIGNMENTS
    --========================================================================
    -- Connect user address to DDR controller (pad to 24 bits)
    ddr_user_addr <= x"00" & std_logic_vector(address_reg);
    
    -- Connect switch data to DDR write data
    ddr_user_wr_data <= write_data_reg;
    
    -- Display lower 8 bits of read data on LEDs
    LED <= read_data_reg(7 downto 0);

end Behavioral; <= INIT_4;
                        lcd_data <= x"20";  -- Switch to 4-bit mode
                    end if;
                
                -- INIT_4: Configure for 4-bit interface
                when INIT_4 =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE then
                        lcd_enable_count <= lcd_enable_count + 1;
                        lcd_e_i <= '1';
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state <= FUNCTION_SET;
                        lcd_data <= x"28";  -- 4-bit mode, 2 lines, 5x8 font
                    end if;
                
                -- FUNCTION_SET: Send function set command in 4-bit mode (2 nibbles)
                when FUNCTION_SET =>
                    if lcd_enable_count < LCD_ENABLE_CYCLE * 2 then
                        if lcd_enable_count = 0 then
                            lcd_e_i <= '1';  -- First nibble enable
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE then
                            lcd_e_i <= '0';
                            lcd_data <= lcd_data(3 downto 0) & x"0";  -- Switch to low nibble
                        elsif lcd_enable_count = LCD_ENABLE_CYCLE + 5 then
                            lcd_e_i <= '1';  -- Second nibble enable
                        end if;
                        lcd_enable_count <= lcd_enable_count + 1;
                    else
                        lcd_e_i <= '0';
                        lcd_enable_count <= 0;
                        lcd_state
