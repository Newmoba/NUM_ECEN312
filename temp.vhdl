library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    Port (
        clk      : in  STD_LOGIC;
        ps2_clk  : in  STD_LOGIC;
        ps2_data : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        an       : out STD_LOGIC_VECTOR (3 downto 0);
        seg      : out STD_LOGIC_VECTOR (6 downto 0)
    );
end top;

architecture Behavioral of top is
    signal shift_reg : std_logic_vector(10 downto 0);
    signal bit_cnt   : integer range 0 to 10 := 0;
    signal ps2_clk_s : std_logic_vector(2 downto 0);
    signal scancode  : std_logic_vector(7 downto 0) := (others => '0');
    signal got_code  : std_logic := '0';
    
    type state_type is (st_numA, st_op, st_numB, st_res);
    signal state : state_type := st_numA;
    signal x, y  : integer range 0 to 9 := 0; 
    signal res   : integer range -9 to 18 := 0;
    signal op_add: std_logic := '1';
    signal break : std_logic := '0';
    
    signal refresh_cnt : unsigned(19 downto 0) := (others => '0');
    signal hex_val : integer range 0 to 15;

begin

    process(clk) begin
        if rising_edge(clk) then ps2_clk_s <= ps2_clk_s(1 downto 0) & ps2_clk; end if;
    end process;

    process(clk) begin
        if rising_edge(clk) then
            got_code <= '0';
            if ps2_clk_s(2 downto 1) = "10" then -- Falling edge
                shift_reg(bit_cnt) <= ps2_data;
                if bit_cnt = 10 then 
                    bit_cnt <= 0; 
                    scancode <= shift_reg(8 downto 1); 
                    got_code <= '1';
                else 
                    bit_cnt <= bit_cnt + 1; 
                end if;
            end if;
        end if;
    end process;

    process(clk)
        variable d : integer range 0 to 15;
    begin
        if rising_edge(clk) then
            if reset = '1' then 
                state <= st_numA; x <= 0; y <= 0; res <= 0; -- Reset res as well
            elsif got_code = '1' then
                if scancode = x"F0" then break <= '1';
                elsif break = '1' then break <= '0';
                else
                    case scancode is
                        when x"45"=> d:=0; when x"16"=> d:=1; when x"1E"=> d:=2;
                        when x"26"=> d:=3; when x"25"=> d:=4; when x"2E"=> d:=5;
                        when x"36"=> d:=6; when x"3D"=> d:=7; when x"3E"=> d:=8;
                        when x"46"=> d:=9; when others=> d:=15;
                    end case;

                    case state is
                        when st_numA => 
                            if d < 10 then x <= d; state <= st_op; end if;
                        when st_op =>
                            if scancode = x"55" then op_add <= '1'; state <= st_numB; -- '+' key (optimised)
                            elsif scancode = x"4E" then op_add <= '0'; state <= st_numB; end if; -- '-' key
                        when st_numB => 
                            if d < 10 then 
                                y <= d; 
                                if op_add = '1' then res <= x + d; else res <= x - d; end if;
                                state <= st_res; 
                            end if;
                        when st_res => 
                            if d < 10 then x <= d; state <= st_op; end if;
                    end case;
                end if;
            end if;
        end if;
    end process;

    process(clk) begin
        if rising_edge(clk) then refresh_cnt <= refresh_cnt + 1; end if;
    end process;
    
    process(refresh_cnt(18 downto 17), state, x, y, res)
        variable disp_val : integer; 
        variable abs_val  : integer; 
    begin
        if state = st_numB then
            disp_val := y;
        elsif state = st_res then
            disp_val := res;
        else 
            disp_val := x;
        end if;

        abs_val := abs(disp_val);
        
  
        an <= "1111"; 
        hex_val <= 15;

        case refresh_cnt(18 downto 17) is
            when "00" => 
                an <= "1110"; 
                if abs_val >= 10 then
                    hex_val <= abs_val - 10; 
                else
                    hex_val <= abs_val;      
                end if;

            when "01" => 
              
                if disp_val < 0 then
                    an <= "1101";
                    hex_val <= 11; 
                elsif abs_val >= 10 then
                    an <= "1101";
                    hex_val <= 1;  
                else
                    an <= "1111";
                end if;
                
            when others => 
                an <= "1111";
        end case;
    end process;

    process(hex_val) begin
        case hex_val is
            when 0=>seg<="0000001"; when 1=>seg<="1001111"; when 2=>seg<="0010010";
            when 3=>seg<="0000110"; when 4=>seg<="1001100"; when 5=>seg<="0100100";
            when 6=>seg<="0100000"; when 7=>seg<="0001111"; when 8=>seg<="0000000";
            when 9=>seg<="0000100"; 
            when 11=>seg<="1111110"; 
            when others=>seg<="1111111";
        end case;
    end process;

end Behavioral;
