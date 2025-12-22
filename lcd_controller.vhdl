library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_controller is
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
end lcd_controller;

architecture Behavioral of lcd_controller is

    -- State machine for LCD control
    type state_type is (
        POWER_UP,
        INIT_1, INIT_2, INIT_3, INIT_4,
        FUNC_SET, FUNC_SET_WAIT,
        DISPLAY_ON, DISPLAY_ON_WAIT,
        CLEAR_DISP, CLEAR_DISP_WAIT,
        ENTRY_MODE, ENTRY_MODE_WAIT,
        WRITE_LINE1, WRITE_LINE2,
        REFRESH_WAIT
    );
    
    signal state : state_type := POWER_UP;
    
    -- Timing and control
    signal counter : unsigned(19 downto 0) := (others => '0');
    signal char_pos : integer range 0 to 20 := 0;
    signal refresh_timer : unsigned(23 downto 0) := (others => '0');
    
    -- LCD command/data
    signal lcd_data_int : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal lcd_rs_int : STD_LOGIC := '0';
    signal lcd_e_int : STD_LOGIC := '0';
    signal send_high_nibble : STD_LOGIC := '0';
    
    -- Display content (what to show on LCD)
    type string_type is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    signal line1_text : string_type;
    signal line2_text : string_type;
    
    -- Hex conversion function
    function to_hex_char(value : STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
        variable hex_char : STD_LOGIC_VECTOR(7 downto 0);
    begin
        case value is
            when "0000" => hex_char := X"30"; -- '0'
            when "0001" => hex_char := X"31"; -- '1'
            when "0010" => hex_char := X"32"; -- '2'
            when "0011" => hex_char := X"33"; -- '3'
            when "0100" => hex_char := X"34"; -- '4'
            when "0101" => hex_char := X"35"; -- '5'
            when "0110" => hex_char := X"36"; -- '6'
            when "0111" => hex_char := X"37"; -- '7'
            when "1000" => hex_char := X"38"; -- '8'
            when "1001" => hex_char := X"39"; -- '9'
            when "1010" => hex_char := X"41"; -- 'A'
            when "1011" => hex_char := X"42"; -- 'B'
            when "1100" => hex_char := X"43"; -- 'C'
            when "1101" => hex_char := X"44"; -- 'D'
            when "1110" => hex_char := X"45"; -- 'E'
            when "1111" => hex_char := X"46"; -- 'F'
            when others => hex_char := X"3F"; -- '?'
        end case;
        return hex_char;
    end function;

begin

    -- Output assignments
    lcd_rs <= lcd_rs_int;
    lcd_rw <= '0'; -- Always write mode
    lcd_e <= lcd_e_int;
    
    -- Mux between high and low nibble
    lcd_data <= lcd_data_int(7 downto 4) when send_high_nibble = '1' 
                else lcd_data_int(3 downto 0);
    
    -------------------------------------------------------------------
    -- Text Update Process
    -- Continuously updates the display text based on inputs
    -------------------------------------------------------------------
    update_text: process(clk)
    begin
        if rising_edge(clk) then
            -- Line 1: "Addr: XX        "
            line1_text(0) <= X"41";  -- 'A'
            line1_text(1) <= X"64";  -- 'd'
            line1_text(2) <= X"64";  -- 'd'
            line1_text(3) <= X"72";  -- 'r'
            line1_text(4) <= X"3A";  -- ':'
            line1_text(5) <= X"20";  -- ' '
            line1_text(6) <= to_hex_char(address(7 downto 4));
            line1_text(7) <= to_hex_char(address(3 downto 0));
            line1_text(8) <= X"20";  -- ' '
            line1_text(9) <= X"20";
            line1_text(10) <= X"20";
            line1_text(11) <= X"20";
            line1_text(12) <= X"20";
            line1_text(13) <= X"20";
            line1_text(14) <= X"20";
            line1_text(15) <= X"20";
            
            -- Line 2: "Data: XX RB     "
            line2_text(0) <= X"44";  -- 'D'
            line2_text(1) <= X"61";  -- 'a'
            line2_text(2) <= X"74";  -- 't'
            line2_text(3) <= X"61";  -- 'a'
            line2_text(4) <= X"3A";  -- ':'
            line2_text(5) <= X"20";  -- ' '
            line2_text(6) <= to_hex_char(data(7 downto 4));
            line2_text(7) <= to_hex_char(data(3 downto 0));
            line2_text(8) <= X"20";  -- ' '
            
            -- Status: R=Ready, B=Busy
            if status(0) = '1' then
                line2_text(9) <= X"42";  -- 'B' (Busy)
            else
                line2_text(9) <= X"20";  -- ' '
            end if;
            
            if status(1) = '1' then
                line2_text(10) <= X"52"; -- 'R' (Ready)
            else
                line2_text(10) <= X"20"; -- ' '
            end if;
            
            line2_text(11) <= X"20";
            line2_text(12) <= X"20";
            line2_text(13) <= X"20";
            line2_text(14) <= X"20";
            line2_text(15) <= X"20";
        end if;
    end process;
    
    -------------------------------------------------------------------
    -- LCD Control State Machine
    -------------------------------------------------------------------
    lcd_fsm: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state <= POWER_UP;
                counter <= (others => '0');
                char_pos <= 0;
                lcd_e_int <= '0';
                lcd_rs_int <= '0';
                lcd_data_int <= (others => '0');
                send_high_nibble <= '0';
                refresh_timer <= (others => '0');
            else
                
                case state is
                
                    -------------------------------------------------------------------
                    -- INITIALIZATION SEQUENCE
                    -------------------------------------------------------------------
                    when POWER_UP =>
                        -- Wait > 40ms after power on
                        lcd_e_int <= '0';
                        if counter < 2000000 then -- 40ms at 50MHz
                            counter <= counter + 1;
                        else
                            state <= INIT_1;
                            counter <= (others => '0');
                        end if;
                    
                    when INIT_1 =>
                        -- First function set (8-bit mode wake up)
                        lcd_rs_int <= '0';
                        lcd_data_int <= X"30";
                        send_high_nibble <= '1';
                        if counter < 5000 then
                            if counter = 10 then
                                lcd_e_int <= '1';
                            elsif counter = 30 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= INIT_2;
                            counter <= (others => '0');
                        end if;
                    
                    when INIT_2 =>
                        -- Second function set
                        lcd_data_int <= X"30";
                        if counter < 1000 then
                            if counter = 10 then
                                lcd_e_int <= '1';
                            elsif counter = 30 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= INIT_3;
                            counter <= (others => '0');
                        end if;
                    
                    when INIT_3 =>
                        -- Third function set
                        lcd_data_int <= X"30";
                        if counter < 1000 then
                            if counter = 10 then
                                lcd_e_int <= '1';
                            elsif counter = 30 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= INIT_4;
                            counter <= (others => '0');
                        end if;
                    
                    when INIT_4 =>
                        -- Set to 4-bit mode
                        lcd_data_int <= X"20";
                        send_high_nibble <= '1';
                        if counter < 1000 then
                            if counter = 10 then
                                lcd_e_int <= '1';
                            elsif counter = 30 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= FUNC_SET;
                            counter <= (others => '0');
                        end if;
                    
                    when FUNC_SET =>
                        -- Function Set: 4-bit, 2 lines, 5x8 font (0x28)
                        lcd_data_int <= X"28";
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= FUNC_SET_WAIT;
                            counter <= (others => '0');
                        end if;
                    
                    when FUNC_SET_WAIT =>
                        if counter < 2000 then
                            counter <= counter + 1;
                        else
                            state <= DISPLAY_ON;
                            counter <= (others => '0');
                        end if;
                    
                    when DISPLAY_ON =>
                        -- Display ON, cursor OFF, blink OFF (0x0C)
                        lcd_data_int <= X"0C";
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= DISPLAY_ON_WAIT;
                            counter <= (others => '0');
                        end if;
                    
                    when DISPLAY_ON_WAIT =>
                        if counter < 2000 then
                            counter <= counter + 1;
                        else
                            state <= CLEAR_DISP;
                            counter <= (others => '0');
                        end if;
                    
                    when CLEAR_DISP =>
                        -- Clear display (0x01)
                        lcd_data_int <= X"01";
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= CLEAR_DISP_WAIT;
                            counter <= (others => '0');
                        end if;
                    
                    when CLEAR_DISP_WAIT =>
                        if counter < 100000 then -- Clear takes longer
                            counter <= counter + 1;
                        else
                            state <= ENTRY_MODE;
                            counter <= (others => '0');
                        end if;
                    
                    when ENTRY_MODE =>
                        -- Entry mode: increment, no shift (0x06)
                        lcd_data_int <= X"06";
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            state <= ENTRY_MODE_WAIT;
                            counter <= (others => '0');
                        end if;
                    
                    when ENTRY_MODE_WAIT =>
                        if counter < 2000 then
                            counter <= counter + 1;
                        else
                            state <= WRITE_LINE1;
                            counter <= (others => '0');
                            char_pos <= 0;
                        end if;
                    
                    -------------------------------------------------------------------
                    -- WRITE LINE 1
                    -------------------------------------------------------------------
                    when WRITE_LINE1 =>
                        lcd_rs_int <= '1'; -- Data mode
                        
                        if char_pos = 0 then
                            -- Set DDRAM address to line 1 start (0x80)
                            lcd_rs_int <= '0';
                            lcd_data_int <= X"80";
                        else
                            lcd_data_int <= line1_text(char_pos - 1);
                        end if;
                        
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            counter <= (others => '0');
                            if char_pos < 16 then
                                char_pos <= char_pos + 1;
                            else
                                state <= WRITE_LINE2;
                                char_pos <= 0;
                            end if;
                        end if;
                    
                    -------------------------------------------------------------------
                    -- WRITE LINE 2
                    -------------------------------------------------------------------
                    when WRITE_LINE2 =>
                        lcd_rs_int <= '1'; -- Data mode
                        
                        if char_pos = 0 then
                            -- Set DDRAM address to line 2 start (0xC0)
                            lcd_rs_int <= '0';
                            lcd_data_int <= X"C0";
                        else
                            lcd_data_int <= line2_text(char_pos - 1);
                        end if;
                        
                        if counter < 50 then
                            if counter = 10 then
                                send_high_nibble <= '1';
                                lcd_e_int <= '1';
                            elsif counter = 20 then
                                lcd_e_int <= '0';
                            elsif counter = 30 then
                                send_high_nibble <= '0';
                                lcd_e_int <= '1';
                            elsif counter = 40 then
                                lcd_e_int <= '0';
                            end if;
                            counter <= counter + 1;
                        else
                            counter <= (others => '0');
                            if char_pos < 16 then
                                char_pos <= char_pos + 1;
                            else
                                state <= REFRESH_WAIT;
                                char_pos <= 0;
                                refresh_timer <= (others => '0');
                            end if;
                        end if;
                    
                    -------------------------------------------------------------------
                    -- REFRESH WAIT - Update display periodically
                    -------------------------------------------------------------------
                    when REFRESH_WAIT =>
                        if refresh_timer < 5000000 then -- Refresh every 100ms
                            refresh_timer <= refresh_timer + 1;
                        else
                            state <= WRITE_LINE1;
                            char_pos <= 0;
                            counter <= (others => '0');
                        end if;
                    
                end case;
            end if;
        end if;
    end process;

end Behavioral;
