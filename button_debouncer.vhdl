library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity button_debouncer is
    Generic (
        COUNTER_WIDTH : integer := 20  -- 20 bits = ~21ms at 50MHz
    );
    Port (
        clk     : in  STD_LOGIC;
        btn_in  : in  STD_LOGIC;
        btn_out : out STD_LOGIC
    );
end button_debouncer;

architecture Behavioral of button_debouncer is
    
    signal counter : unsigned(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal btn_sync : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal btn_stable : STD_LOGIC := '0';
    
begin

    -- Output the stable button state
    btn_out <= btn_stable;
    
    -------------------------------------------------------------------
    -- Synchronizer Process
    -- Two-stage synchronizer to avoid metastability from async button input
    -------------------------------------------------------------------
    sync_proc: process(clk)
    begin
        if rising_edge(clk) then
            btn_sync(0) <= btn_in;
            btn_sync(1) <= btn_sync(0);
        end if;
    end process;
    
    -------------------------------------------------------------------
    -- Debounce Process
    -- Counts up when button pressed, down when released
    -- Changes output only when counter saturates
    -------------------------------------------------------------------
    debounce_proc: process(clk)
    begin
        if rising_edge(clk) then
            
            -- If button pressed (active high)
            if btn_sync(1) = '1' then
                -- Count up towards maximum
                if counter < (2**COUNTER_WIDTH - 1) then
                    counter <= counter + 1;
                else
                    -- Counter saturated at maximum - button confirmed pressed
                    btn_stable <= '1';
                end if;
                
            -- If button released
            else
                -- Count down towards zero
                if counter > 0 then
                    counter <= counter - 1;
                else
                    -- Counter saturated at zero - button confirmed released
                    btn_stable <= '0';
                end if;
            end if;
            
        end if;
    end process;

end Behavioral;
