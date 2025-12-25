library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_corruption_test is
-- Testbench has no ports
end tb_corruption_test;

architecture Behavioral of tb_corruption_test is

    -- Component Declaration for the Unit Under Test (UUT)
    component TopLevel_CRC
    Port ( 
        clk         : in  std_logic; 
        reset       : in  std_logic; 
        btn_tick    : in  std_logic; 
        input_data  : in  std_logic_vector (7 downto 0);
        data_valid  : in  std_logic;
        data_crc    : out std_logic_vector(31 downto 0);
        is_corrupt  : out std_logic
    );
    end component;

    -- Inputs
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal btn_tick : std_logic := '0';
    signal input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';

    -- Outputs
    signal data_crc : std_logic_vector(31 downto 0);
    signal is_corrupt : std_logic;

    -- Clock period definitions
    constant clk_period : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: TopLevel_CRC PORT MAP (
        clk => clk,
        reset => reset,
        btn_tick => btn_tick,
        input_data => input_data,
        data_valid => data_valid,
        data_crc => data_crc,
        is_corrupt => is_corrupt
    );

    -- Clock process definitions
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
    begin		
        -- 1. Initialize Inputs
        reset <= '1';
        wait for 40 ns;
        reset <= '0';
        wait for 40 ns;

        ------------------------------------------------------------
        -- 2. SWITCH TO RECEIVER MODE
        ------------------------------------------------------------
        -- Pulse the button to switch state from TX (Default) to RX
        wait until rising_edge(clk);
        btn_tick <= '1';
        wait for clk_period * 2; -- Hold briefly
        btn_tick <= '0';
        wait for clk_period * 5; -- Allow state machine to settle

        ------------------------------------------------------------
        -- 3. INJECT CORRUPT DATA STREAM
        ------------------------------------------------------------
        -- Scenario: Sending Data [AA BB] + BAD CRC [FF FF FF FF]
        
        -- Byte 1: Data 0xAA
        wait until rising_edge(clk);
        input_data <= x"AA";
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4; -- Wait for processing

        -- Byte 2: Data 0xBB
        wait until rising_edge(clk);
        input_data <= x"BB";
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4;

        -- Byte 3: FAKE CRC Byte 1 (Should be valid CRC, but we send FF)
        wait until rising_edge(clk);
        input_data <= x"FF"; 
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4;

        -- Byte 4: FAKE CRC Byte 2
        wait until rising_edge(clk);
        input_data <= x"FF";
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4;

        -- Byte 5: FAKE CRC Byte 3
        wait until rising_edge(clk);
        input_data <= x"FF";
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4;

        -- Byte 6: FAKE CRC Byte 4
        wait until rising_edge(clk);
        input_data <= x"FF";
        data_valid <= '1';
        wait until rising_edge(clk);
        data_valid <= '0';
        wait for clk_period * 4;

        ------------------------------------------------------------
        -- 4. VERIFY RESULT
        ------------------------------------------------------------
        wait for 100 ns;
        
        -- At this point, the internal CRC calculation will NOT be zero.
        -- Therefore, is_corrupt should be '1'.
        
        assert is_corrupt = '1'
        report "TEST PASSED: Corruption correctly detected (is_corrupt is 1)."
        severity NOTE;
        
        if is_corrupt = '0' then
            report "TEST FAILED: Receiver thinks the bad data is valid!"
            severity ERROR;
        end if;

        wait;
    end process;

end Behavioral;