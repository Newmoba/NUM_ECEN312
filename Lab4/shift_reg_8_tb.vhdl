library IEEE;
use IEEE.std_logic_1164.all;

entity shift_reg_8_tb is
end shift_reg_8_tb;

architecture testbench of shift_reg_8_tb is
    component shift_reg_8
        port(
            clk, clear : in std_logic;
            Select_func : in std_logic_vector(2 downto 0);
            D : in std_logic_vector(7 downto 0);
            SI_left : in std_logic;
            SI_right : in std_logic;
            Q : out std_logic_vector(7 downto 0)
        );
    end component;
    
    signal clk_tb : std_logic := '0';
    signal clear_tb : std_logic;
    signal Select_func_tb : std_logic_vector(2 downto 0);
    signal D_tb : std_logic_vector(7 downto 0);
    signal SI_left_tb, SI_right_tb : std_logic;
    signal Q_tb : std_logic_vector(7 downto 0);
    
begin
    uut: shift_reg_8 
        port map(
            clk => clk_tb,
            clear => clear_tb,
            Select_func => Select_func_tb,
            D => D_tb,
            SI_left => SI_left_tb,
            SI_right => SI_right_tb,
            Q => Q_tb
        );
    
    -- Clock generation
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
        --clear
        clear_tb <= '0';
        Select_func_tb <= "000";
        D_tb <= "11111111";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --load
        clear_tb <= '1';
        Select_func_tb <= "001";
        D_tb <= "10110101";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        -- hold
        clear_tb <= '1';
        Select_func_tb <= "000";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift right(SI_left=1)
        clear_tb <= '1';
        Select_func_tb <= "010";
        D_tb <= "00000000";
        SI_left_tb <= '1';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift right(SI_left=0)
        clear_tb <= '1';
        Select_func_tb <= "010";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        -- load new data
        clear_tb <= '1';
        Select_func_tb <= "001";
        D_tb <= "11001010";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift left(SI_right=1)
        clear_tb <= '1';
        Select_func_tb <= "011";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '1';
        wait for 20 ns;

         --shift left(SI_right=0)
        clear_tb <= '1';
        Select_func_tb <= "011";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift circular right
        clear_tb <= '1';
        Select_func_tb <= "100";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift circular left
        clear_tb <= '1';
        Select_func_tb <= "101";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift arithmetic right
        clear_tb <= '1';
        Select_func_tb <= "110";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait for 20 ns;
        
        --shift arithmetic left
        clear_tb <= '1';
        Select_func_tb <= "111";
        D_tb <= "00000000";
        SI_left_tb <= '0';
        SI_right_tb <= '0';
        wait;
    end process;
    
end testbench;
