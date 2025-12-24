library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_CRCreceiver is
-- Testbench entities represent the environment and have no ports
end tb_CRCreceiver;

architecture Behavioral of tb_CRCreceiver is

    -- 1. Component Declaration (Matches your Entity)
    component CRCreceiver
        port (
            input_data : in std_logic_vector(7 downto 0);
            is_corrupt : out std_logic;
            data_valid : in std_logic;
            clk        : in std_logic
        );
    end component;

    -- 2. Signal Declarations (To connect to the Component)
    signal tb_input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tb_is_corrupt : std_logic;
    signal tb_data_valid : std_logic := '0';
    signal tb_clk        : std_logic := '0';

    -- 3. Clock Period Definition
    constant CLK_PERIOD : time := 100 ps;

begin

    -- 4. Instantiate the Device Under Test (DUT)
    uut: CRCreceiver port map (
        input_data => tb_input_data,
        is_corrupt => tb_is_corrupt,
        data_valid => tb_data_valid,
        clk        => tb_clk
    );

    -- 5. Clock Generation Process
    -- Toggles the clock every 50 ps to create a 100 ps period
    clk_process : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD/2;
        tb_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 6. Stimulus Process (Data Input)
    stim_proc: process
    begin
        -- Initialize Inputs
        tb_data_valid <= '1'; -- Requirement: Always equal to 1
        
        -- Note: We wait for CLK_PERIOD for each step to advance the simulation time
        
        -- Cycle 1: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;
        
        -- Cycle 2: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;

        -- Cycle 3: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;

        -- Cycle 4: 1111 1010 (0xFA)
        tb_input_data <= "11111010";
        wait for CLK_PERIOD;

        -- Cycle 5: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;

        -- Cycle 6: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;

        -- Cycle 7: 0000 0000
        tb_input_data <= "00000000";
        wait for CLK_PERIOD;

        -- Cycle 8: 1111 1010 (0xFA)
        tb_input_data <= "11111010";
        wait for CLK_PERIOD;

        -- Cycle 9: 1111 1010 (0xFA)
        tb_input_data <= "11111010";
        wait for CLK_PERIOD;

        -- Cycle 10: 1111 1010 (0xFA)
        tb_input_data <= "11111010";
        wait for CLK_PERIOD;

        -- Stop Simulation
        wait;
    end process;

end Behavioral;