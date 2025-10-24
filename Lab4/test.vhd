library ieee;
use ieee.std_logic_1164.all;

entity rg_8 is
    port(
        clk   : in std_logic;
        clear : in std_logic;
        load  : in std_logic;
        D     : in std_logic_vector(7 downto 0);
        Q     : out std_logic_vector(7 downto 0)
    );
end rg_8;

architecture behavioral of rg_8 is
    signal Q_i : std_logic_vector(7 downto 0);
begin
    process(clk, clear)
    begin
        if clear = '0' then
            Q_i <= (others => '0');
        elsif (clk'event and clk = '1') then
            if load = '1' then
                Q_i <= D;
            end if;
        end if;
    end process;

    Q <= Q_i;
end behavioral;
