library IEEE;
use IEEE.std_logic_1164.all;

entity rg_8_load_tb is
end rg_8_load_tb;

architecture testbench of rg_8_load_tb is
    component rg_8_load
        port(
            clk, clear, load : in std_logic;
            D : in std_logic_vector(7 downto 0);
            Q : out std_logic_vector(7 downto 0));
    end component;

    signal clk_tb : std_logic := '0';
    signal clear_tb : std_logic := '1';
    signal load_tb : std_logic := '0';
    signal D_tb : std_logic_vector(7 downto 0) := (others => '0');
    signal Q_tb : std_logic_vector(7 downto 0);
    
    
begin
    uut: rg_8_load 
        port map(
            clk => clk_tb,
            clear => clear_tb,
            load => load_tb,
            D => D_tb,
            Q => Q_tb
        );
    
    
    clk_process: process
    begin
        clk_tb <= '0';
        wait for 20 ns;
        clk_tb <= '1';
        wait for 20 ns;
    end process;
    
    -- Stimulus process
    stim_process: process
    begin
        -- Test 1: Reset (clear='0')
        clear_tb <= '0';
        D_tb <= "11111111";
        load_tb <= '1';
        wait for 20 ns;
        
        -- Test 2: Release clear
        clear_tb <= '1';
        wait for 20 ns;
        
        -- Test 3: Load data when load='1'
        load_tb <= '1';
        D_tb <= "10101010";
        wait for 20 ns;
        
        -- Test 4: Try to load new data (load='1')
        D_tb <= "11001100";
        wait for 20 ns;
        
        -- Test 5: Disable load (load='0'), data should not change
        load_tb <= '0';
        D_tb <= "00110011";
        wait for 20 ns;
        
        -- Test 6: Enable load again
        load_tb <= '1';
        D_tb <= "01010101";
        wait for 20 ns;
        
        -- Test 7: Clear during operation
        clear_tb <= '0';
        wait for 20 ns;
        
        -- Test 8: Resume after clear
        clear_tb <= '1';
        load_tb <= '1';
        D_tb <= "11110000";
        wait for 20 ns;
        wait;
    end process;
    
end testbench;
