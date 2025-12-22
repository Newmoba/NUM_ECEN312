entity debounce is
    port (
        clk     : in std_logic;
        btn_in  : in std_logic;
        btn_out : out std_logic
    );
end debounce;

architecture Behavioral of debounce is
    signal shift : std_logic_vector(3 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            shift <= shift(2 downto 0) & btn_in;
        end if;
    end process;
    btn_out <= shift(3) and shift(2) and shift(1) and shift(0);
end Behavioral;
