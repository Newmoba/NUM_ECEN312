library IEEE;
use IEEE.std_logic_1164.all;

entity memory_tb is
end memory_tb;

architecture testbench of memory_tb is
    component memory
        port(
            clk, reset : in std_logic;
            write : in std_logic;
            bus_id : in std_logic_vector(7 downto 0);
            oe, we : out std_logic;
            addr : out std_logic_vector(1 downto 0));
    end component;
    
    signal clk_tb : std_logic := '0';
    signal reset_tb : std_logic;
    signal write_tb : std_logic;
    signal bus_id_tb : std_logic_vector(7 downto 0);
    signal oe_tb, we_tb : std_logic;
    signal addr_tb : std_logic_vector(1 downto 0);
    
begin
    uut: memory
        port map(
            clk => clk_tb,
            reset => reset_tb,
            write => write_tb,
            bus_id => bus_id_tb,
            oe => oe_tb,
            we => we_tb,
            addr => addr_tb
        );
    
    --clock
    process
    begin
        clk_tb <= '0';
        wait for 20 ns;
        clk_tb <= '1';
        wait for 20 ns;
    end process;
    
    process
    begin
        -- Test 1: Reset
        reset_tb <= '0';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        -- wrong bus_id(idle)
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns; 
        
        --tohiroh bus_id(uildel/action)
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "11110011";
        wait for 20 ns;
        
        -- read1
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        --read2
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        --read3
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        --read4
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
  
        --read4 to idle
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        --idle loop
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "11110011";
        wait for 20 ns;
        
        --write
        reset_tb <= '1';
        write_tb <= '1';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        
        --write to idle
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        wait for 20 ns;
        --idle loop
        reset_tb <= '1';
        write_tb <= '0';
        bus_id_tb <= "00000000";
        
        wait;
    end process;
    
end testbench;
