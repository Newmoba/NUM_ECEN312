library IEEE;
use IEEE.std_logic_1164.all;

entity seq_rec_tb is
end seq_rec_tb;

architecture testbench of seq_rec_tb is
    component seq_rec
        port(
            clk, reset, X : in std_logic;
            Z : out std_logic);
    end component;
    
    signal clk_tb : std_logic := '0';
    signal reset_tb : std_logic;
    signal X_tb : std_logic;
    signal Z_tb : std_logic;
    
begin
    uut: seq_rec
        port map(
            clk => clk_tb,
            reset => reset_tb,
            X => X_tb,
            Z => Z_tb);
    
    process
    begin
        clk_tb <= '0';
        wait for 20 ns;
        clk_tb <= '1';
        wait for 20 ns;
    end process;

    process
    begin
        --reset
        reset_tb <= '1';
        X_tb <= '0';
        wait for 20 ns;
        
        --state A
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;
        
        --x=0(A)
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;
        
        --x=0(B)
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;
        
        --C
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;
        
        --x=0(D)
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;
        
        --z=1(B)
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;
        
        --x=0(A)
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;
        

	--1101 tanih
        -- X=1, A->B
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns; 
        -- X=1, B->C
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;   
        --X=0, C->D
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;
        --X=1, D->B
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;
        --X=1(C)
        reset_tb <= '0';
        X_tb <= '1';
        wait for 20 ns;
        -- X=0, C->D
        reset_tb <= '0';
        X_tb <= '0';
        wait for 40 ns;
        --X=0, D->A
        reset_tb <= '0';
        X_tb <= '0';
        wait for 40 ns;
        

        reset_tb <= '1';
        X_tb <= '1';
        wait for 20 ns;
        reset_tb <= '0';
        X_tb <= '0';
        wait for 20 ns;	
        wait;
    end process;
    
end testbench;
