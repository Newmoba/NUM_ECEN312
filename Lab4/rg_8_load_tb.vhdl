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
    process(clear_tb, clk_tb)
    begin
	--reset
        if clear_tb = '0' then
            D_tb <= "11111111";
            load_tb <= '1';
         -- rising edge shalgah
        elsif (clk_tb'event and clk_tb='1') then
            if Q_tb = "00000000" then
                -- after reset, release clear
                clear_tb <= '1';
                D_tb <= "10101010";
                load_tb <= '1';
                
            elsif Q_tb = "10101010" then
                -- new data
                D_tb <= "11001100";
                load_tb <= '1';
                
            elsif Q_tb = "11001100" then
                -- disable load(orolt orj irehgui)
                load_tb <= '0';
                D_tb <= "00110011";
                
            elsif Q_tb = "11001100" and load_tb = '0' then
                -- shineer ehluuleh
                load_tb <= '1';
                D_tb <= "01010101";
                
            elsif Q_tb = "01010101" then
                D_tb <= "11110000";
                load_tb <= '1';
                
            elsif Q_tb = "11110000" then
                clear_tb <= '0';
            end if;
        end if;
    end process;
    
    process
    begin
        clk_tb <= '0';
        wait for 20 ns;
        clk_tb <= '1';
        wait for 20 ns;
    end process;
end testbench;
