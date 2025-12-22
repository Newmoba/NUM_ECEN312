library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- ======================================
-- DDR Memory Test System (LED Only)
-- ======================================
entity DDR_LED is
    Port (
        clk     : in  STD_LOGIC;                      -- System clock
        rst     : in  STD_LOGIC;                      -- Reset
        sw      : in  STD_LOGIC_VECTOR(3 downto 0);  -- Data input
        btn_wr  : in  STD_LOGIC;                      -- Write button
        btn_rd  : in  STD_LOGIC;                      -- Read button

        -- DDR interface (simplified / symbolic)
        ddr_a   : out STD_LOGIC_VECTOR(12 downto 0);
        ddr_ba  : out STD_LOGIC_VECTOR(1 downto 0);
        ddr_cas : out STD_LOGIC;
        ddr_ras : out STD_LOGIC;
        ddr_we  : out STD_LOGIC;
        ddr_clk : out STD_LOGIC;

        -- Status LEDs
        led     : out STD_LOGIC_VECTOR(7 downto 0)
    );
end DDR_LED;

