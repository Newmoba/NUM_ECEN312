library IEEE;
use IEEE.std_logic_1164.all;

entity memory is
    port(
        clk, reset : in std_logic;
        write : in std_logic;
        bus_id : in std_logic_vector(7 downto 0);
        oe, we : out std_logic;
        addr : out std_logic_vector(1 downto 0));
end memory;

architecture behavioral of memory is
    type state_type is (idle, action, read1, read2, read3, read4, write_state);
    signal present_state, next_state : state_type;
    
begin
    --register state
    process(clk, reset)
    begin
        if reset = '0' then
            present_state <= idle;
        elsif (clk'event and clk='1') then
            present_state <= next_state;
        end if;
    end process;
    
    -- next state, output
    process(present_state, write, bus_id)
    begin
        -- Default outputs
        oe <= '0';
        we <= '0';
        addr <= "00";
        next_state <= present_state;
        
        case present_state is
            when idle =>
                oe <= '0';
                we <= '0';
                addr <= "00";
                if bus_id = "11110011" then
                    next_state <= action;
                else
                    next_state <= idle;
                end if;
                
            when action =>
                oe <= '0';
                we <= '0';
                addr <= "00";
                if write = '0' then
                    next_state <= read1;
                else
                    next_state <= write_state;
                end if;
                
            when read1 =>
                oe <= '1';
                we <= '0';
                addr <= "00";
                next_state <= read2;
                
            when read2 =>
                oe <= '1';
                we <= '0';
                addr <= "01";
                next_state <= read3;
                
            when read3 =>
                oe <= '1';
                we <= '0';
                addr <= "10";
                next_state <= read4;
                
            when read4 =>
                oe <= '1';
                we <= '0';
                addr <= "11";
                next_state <= idle;
                
            when write_state =>
                oe <= '0';
                we <= '1';
                addr <= "00";
                next_state <= idle;
                
            when others =>
                next_state <= idle;
        end case;
    end process;
    
end behavioral;
