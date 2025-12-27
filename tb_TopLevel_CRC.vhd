library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_TopLevel_CRC is
end;

architecture sim of tb_TopLevel_CRC is

    -- Component Declaration
    component TopLevel_CRC
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        btn_tick    : in  std_logic;
        uart_rx     : in  std_logic;
        uart_tx     : out std_logic;
        data_crc    : out std_logic_vector(31 downto 0);
        is_corrupt  : out std_logic
    );
    end component;

    -- Inputs
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal btn_tick   : std_logic := '0';
    signal uart_rx    : std_logic := '1';

    -- Outputs
    signal uart_tx    : std_logic;
    signal data_crc   : std_logic_vector(31 downto 0);
    signal is_corrupt : std_logic;

    -- Constants
    constant clk_period : time := 20 ns;
    constant bit_time   : time := 5208 * clk_period;

    -- UART Send Procedure
    procedure uart_send(signal line : out std_logic; data : in std_logic_vector(7 downto 0)) is
    begin
        line <= '0'; wait for bit_time; -- Start
        for i in 0 to 7 loop
            line <= data(i); wait for bit_time; -- Data LSB
        end loop;
        line <= '1'; wait for bit_time; -- Stop
        wait for bit_time; -- Gap
    end procedure;

begin

    uut: TopLevel_CRC port map (
        clk => clk, reset => reset, btn_tick => btn_tick,
        uart_rx => uart_rx, uart_tx => uart_tx,
        data_crc => data_crc, is_corrupt => is_corrupt
    );

    clk_process :process begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;

    stim_proc: process
    begin       
        -- 1. Reset
        reset <= '1'; wait for 100 ns; reset <= '0'; wait for 100 ns;

        ------------------------------------------------------------------
        -- TEST 1: TRANSMITTER (Generate CRC)
        -- Input: "aku sayang moti"
        ------------------------------------------------------------------
        report ">>> TEST 1: Sending 'aku sayang moti'...";
        
        -- "aku"
        uart_send(uart_rx, x"61"); -- a
        uart_send(uart_rx, x"6B"); -- k
        uart_send(uart_rx, x"75"); -- u
        uart_send(uart_rx, x"20"); -- (space)
        
        -- "sayang"
        uart_send(uart_rx, x"73"); -- s
        uart_send(uart_rx, x"61"); -- a
        uart_send(uart_rx, x"79"); -- y
        uart_send(uart_rx, x"61"); -- a
        uart_send(uart_rx, x"6E"); -- n
        uart_send(uart_rx, x"67"); -- g
        uart_send(uart_rx, x"20"); -- (space)
        
        -- "moti"
        uart_send(uart_rx, x"6D"); -- m
        uart_send(uart_rx, x"6F"); -- o
        uart_send(uart_rx, x"74"); -- t
        uart_send(uart_rx, x"69"); -- i
        
        -- END
        uart_send(uart_rx, x"0D"); -- Enter
        
        wait for 1 ms;
        
        -- IMPORTANT: Check the Waveform for 'data_crc' here!
        -- Write down the result (e.g., x"12345678") to use in Test 2.
        if data_crc = x"DAC7572E" then
            report ">>> TEST 1 PASS: Valid Packet Accepted." severity note;
        else
            report ">>> TEST 1 FAIL: Packet marked Corrupt (Did you update the CRC bytes?)" severity warning;
        end if;
        ------------------------------------------------------------------
        -- SWITCH TO RECEIVER
        ------------------------------------------------------------------
        btn_tick <= '1'; wait for 100 ns; btn_tick <= '0'; wait for 1 ms; 

        ------------------------------------------------------------------
        -- TEST 2: RECEIVER (Valid Packet)
        -- Input: "aku sayang moti" + [CRC Result]
        ------------------------------------------------------------------
        report ">>> TEST 2: Checking Valid Packet...";
        
        -- Send Data "aku sayang moti" again
        uart_send(uart_rx, x"61"); uart_send(uart_rx, x"6B"); uart_send(uart_rx, x"75"); uart_send(uart_rx, x"20");
        uart_send(uart_rx, x"73"); uart_send(uart_rx, x"61"); uart_send(uart_rx, x"79"); uart_send(uart_rx, x"61");
        uart_send(uart_rx, x"6E"); uart_send(uart_rx, x"67"); uart_send(uart_rx, x"20");
        uart_send(uart_rx, x"6D"); uart_send(uart_rx, x"6F"); uart_send(uart_rx, x"74"); uart_send(uart_rx, x"69");
        
        -- -----------------------------------------------------------
        -- TODO: UPDATE THESE 4 BYTES WITH THE RESULT FROM TEST 1 !!!
        -- -----------------------------------------------------------
        -- Current placeholder (You must change this to match Test 1 output)
        uart_send(uart_rx, x"DA"); -- Byte 3 (MSB)
        uart_send(uart_rx, x"C7"); -- Byte 2
        uart_send(uart_rx, x"57"); -- Byte 1
        uart_send(uart_rx, x"2E"); -- Byte 0 (LSB)
        
        uart_send(uart_rx, x"0D"); -- Enter
        
        wait for 1 ms;
        
        if is_corrupt = '0' then
            report ">>> TEST 2 PASS: Valid Packet Accepted." severity note;
        else
            report ">>> TEST 2 FAIL: Packet marked Corrupt (Did you update the CRC bytes?)" severity warning;
        end if;

        ------------------------------------------------------------------
        -- TEST 3: RECEIVER (Corrupt Packet)
        ------------------------------------------------------------------
        report ">>> TEST 3: Checking Corrupt Packet...";
        
        -- Send Data "aku sayang moti"
        uart_send(uart_rx, x"61"); uart_send(uart_rx, x"6B"); uart_send(uart_rx, x"75"); uart_send(uart_rx, x"20");
        uart_send(uart_rx, x"73"); uart_send(uart_rx, x"61"); uart_send(uart_rx, x"79"); uart_send(uart_rx, x"61");
        uart_send(uart_rx, x"6E"); uart_send(uart_rx, x"67"); uart_send(uart_rx, x"20");
        uart_send(uart_rx, x"6D"); uart_send(uart_rx, x"6F"); uart_send(uart_rx, x"74"); uart_send(uart_rx, x"69");

        -- Send Intentionally WRONG CRC
        uart_send(uart_rx, x"DE");
        uart_send(uart_rx, x"AD");
        uart_send(uart_rx, x"BE");
        uart_send(uart_rx, x"EF");
        
        uart_send(uart_rx, x"0D");
        
        wait for 1 ms;
        
        if is_corrupt = '1' then
            report ">>> TEST 3 PASS: Corrupt Packet Detected." severity note;
        else
            report ">>> TEST 3 FAIL: Corrupt Packet Accepted!" severity error;
        end if;

        report ">>> ALL TESTS COMPLETED.";
        wait;
    end process;

end;