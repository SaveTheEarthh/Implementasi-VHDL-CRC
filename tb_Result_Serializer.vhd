library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_Result_Serializer is
end tb_Result_Serializer;

architecture Behavioral of tb_Result_Serializer is

    component Result_Serializer
        Port ( 
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            start_send  : in  STD_LOGIC;
            mode_rx     : in  STD_LOGIC;
            data_in     : in  STD_LOGIC_VECTOR (31 downto 0);
            is_corrupt  : in  STD_LOGIC;
            uart_busy   : in  STD_LOGIC;
            uart_start  : out STD_LOGIC;
            uart_data   : out STD_LOGIC_VECTOR (7 downto 0)
        );
    end component;

    -- Inputs
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal start_send : std_logic := '0';
    signal mode_rx    : std_logic := '0';
    signal data_in    : std_logic_vector(31 downto 0) := (others => '0');
    signal is_corrupt : std_logic := '0';
    signal uart_busy  : std_logic := '0';

    -- Outputs
    signal uart_start : std_logic;
    signal uart_data  : std_logic_vector(7 downto 0);

    -- Clock period definitions
    constant clk_period : time := 20 ns;

begin

    uut: Result_Serializer Port Map (
        clk => clk,
        reset => reset,
        start_send => start_send,
        mode_rx => mode_rx,
        data_in => data_in,
        is_corrupt => is_corrupt,
        uart_busy => uart_busy,
        uart_start => uart_start,
        uart_data => uart_data
    );

    -- Clock process
    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    -- UART SIMULATOR PROCESS
    -- This mimics the real UART module. When it sees 'start', it raises 'busy'.
    uart_mimic_proc: process
    begin
        wait until rising_edge(clk);
        if uart_start = '1' then
            -- 1. React to start signal
            wait for clk_period * 2; 
            uart_busy <= '1'; -- UART is now sending...
            
            -- 2. Simulate transmission time (shortened for testbench speed)
            wait for clk_period * 10; 
            
            -- 3. Finish transmission
            uart_busy <= '0';
        end if;
    end process;

    -- Stimulus process
    stim_proc: process
    begin		
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;

        ----------------------------------------------------------------
        -- TEST 1: TX MODE -> "CRC: 12345678"
        ----------------------------------------------------------------
        report ">>> TEST 1: TX Mode (Expect 'CRC: 12345678')";
        mode_rx <= '0';
        data_in <= x"12345678";
        
        start_send <= '1'; -- Trigger
        wait for clk_period;
        start_send <= '0';

        wait for 2000 ns; -- Wait for message to print

        ----------------------------------------------------------------
        -- TEST 2: RX MODE (VALID) -> "RX: VALID"
        ----------------------------------------------------------------
        report ">>> TEST 2: RX Mode Valid (Expect 'RX: VALID')";
        mode_rx <= '1';
        is_corrupt <= '0';
        
        start_send <= '1';
        wait for clk_period;
        start_send <= '0';

        wait for 2000 ns;

        ----------------------------------------------------------------
        -- TEST 3: RX MODE (CORRUPT) -> "RX: CORRUPT"
        ----------------------------------------------------------------
        report ">>> TEST 3: RX Mode Corrupt (Expect 'RX: CORRUPT')";
        mode_rx <= '1';
        is_corrupt <= '1';
        
        start_send <= '1';
        wait for clk_period;
        start_send <= '0';

        wait for 2000 ns;

        report ">>> SIMULATION COMPLETE";
        wait;
    end process;

end Behavioral;