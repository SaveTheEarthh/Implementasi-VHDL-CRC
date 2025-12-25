library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TopLevel_CRC_tb is
-- Testbenches do not have ports
end TopLevel_CRC_tb;

architecture sim of TopLevel_CRC_tb is

    -- Signals to connect to the Unit Under Test (UUT)
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal btn_tick     : std_logic := '0';
    signal input_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid   : std_logic := '0';
    signal data_crc     : std_logic_vector(31 downto 0);
    signal is_corrupt   : std_logic;

    -- Clock period definition (50MHz = 20ns)
    constant clk_period : time := 20 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    UUT: entity work.TopLevel_CRC
        port map (
            clk        => clk,
            reset      => reset,
            btn_tick   => btn_tick,
            input_data => input_data,
            data_valid => data_valid,
            data_crc   => data_crc,
            is_corrupt => is_corrupt
        );

    -- 1. Clock Process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- 2. Stimulus Process (The Simulation Scenario)
    stim_proc: process
    begin		
        -- Initial Reset
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait for 20 ns;

        -----------------------------------------------------------
        -- PHASE 1: CRC_Transmitter Mode (Default)
        -----------------------------------------------------------
        -- In this phase, clk_tx should be toggling, clk_rx should be 0.
        input_data <= "10101010"; -- Example Data AA
        data_valid <= '1';
        wait for 100 ns;
        data_valid <= '0';
        wait for 40 ns;

        -----------------------------------------------------------
        -- PHASE 2: SWITCH TO RECEIVER
        -----------------------------------------------------------
        -- Simulate a button tick (pulse for 1 clock cycle)
        btn_tick <= '1';
        wait for clk_period;
        btn_tick <= '0';
        
        -- Now, clk_tx should flatline and clk_rx should start toggling.
        wait for 100 ns;
        
        input_data <= "11110000"; -- Different data for receiver
        data_valid <= '1';
        wait for 100 ns;
        data_valid <= '0';

        -----------------------------------------------------------
        -- PHASE 3: SWITCH BACK TO TRANSMITTER
        -----------------------------------------------------------
        wait for 40 ns;
        btn_tick <= '1';
        wait for clk_period;
        btn_tick <= '0';

        wait; -- End simulation
    end process;

end sim;