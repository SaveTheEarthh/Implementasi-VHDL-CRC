LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY tb_TopLevel_CRC IS
END tb_TopLevel_CRC;
 
ARCHITECTURE behavior OF tb_TopLevel_CRC IS 
 
    COMPONENT TopLevel_CRC
    PORT(
         clk        : IN  std_logic;
         reset      : IN  std_logic;
         btn_tick   : IN  std_logic;
         input_data : IN  std_logic_vector(7 downto 0);
         data_valid : IN  std_logic;
         data_crc   : OUT std_logic_vector(31 downto 0);
         is_corrupt : OUT std_logic
        );
    END COMPONENT;
   
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal btn_tick   : std_logic := '0';
    signal input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal data_crc   : std_logic_vector(31 downto 0);
    signal is_corrupt : std_logic;
 
    constant clk_period : time := 10 ns;
 
    -- Procedure to send a single byte with valid signal
    procedure send_byte(signal d_in : out std_logic_vector; signal valid : out std_logic; value : in std_logic_vector) is
    begin
        d_in <= value;
        valid <= '1';
        wait for clk_period;
        valid <= '0';
        d_in <= x"00";
        -- Wait between bytes to simulate UART/Serial gaps or just processing time
        wait for clk_period * 5; 
    end procedure;
 
BEGIN
 
    uut: TopLevel_CRC PORT MAP (
          clk => clk, reset => reset, btn_tick => btn_tick,
          input_data => input_data, data_valid => data_valid,
          data_crc => data_crc, is_corrupt => is_corrupt
        );
 
    clk_process :process
    begin
        clk <= '0'; wait for clk_period/2;
        clk <= '1'; wait for clk_period/2;
    end process;
 
    stim_proc: process
    begin		
        -- Reset the system
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for clk_period * 10;

        ------------------------------------------------------------
        -- MODE 1: TRANSMITTER (CRC Generation)
        ------------------------------------------------------------
        report ">>> [MODE: TX] Sending Message 01 23 45 67 89 AB CD EF";
        
        -- Send 8 bytes of data
        send_byte(input_data, data_valid, x"01");
        send_byte(input_data, data_valid, x"23");
        send_byte(input_data, data_valid, x"45");
        send_byte(input_data, data_valid, x"67");
        send_byte(input_data, data_valid, x"89");
        send_byte(input_data, data_valid, x"AB");
        send_byte(input_data, data_valid, x"CD");
        send_byte(input_data, data_valid, x"EF");
        
        -- Wait for the calculation to finish
        wait for clk_period * 20;
        
        -- CHECK: Does the output match what your hardware produced in the last run? (60EA655F)
        if data_crc = x"60EA655F" then
            report ">>> [PASS] TX CRC matches Hardware Logic (60EA655F)" severity note;
        else
            -- We print the actual value received to help debugging
            report ">>> [FAIL] TX Expected 60EA655F, Got: " severity error;
        end if;

        ------------------------------------------------------------
        -- SWITCH TO RECEIVER MODE
        ------------------------------------------------------------
        report ">>> Pressing Button to Switch Modes...";
        btn_tick <= '1';
        wait for clk_period * 2; 
        btn_tick <= '0';
        wait for clk_period * 20; -- Give FSM time to stabilize

        ------------------------------------------------------------
        -- MODE 2: RECEIVER (CRC Checking)
        ------------------------------------------------------------
        report ">>> [MODE: RX] Sending Message + Hardware CRC (60 EA 65 5F)";
        
        -- 1. Resend the original message
        send_byte(input_data, data_valid, x"01");
        send_byte(input_data, data_valid, x"23");
        send_byte(input_data, data_valid, x"45");
        send_byte(input_data, data_valid, x"67");
        send_byte(input_data, data_valid, x"89");
        send_byte(input_data, data_valid, x"AB");
        send_byte(input_data, data_valid, x"CD");
        send_byte(input_data, data_valid, x"EF");
        
        -- 2. Send the CRC that makes the result 0 (The one TX generated)
        -- Splitting 60EA655F into bytes
        send_byte(input_data, data_valid, x"60");
        send_byte(input_data, data_valid, x"EA");
        send_byte(input_data, data_valid, x"65");
        send_byte(input_data, data_valid, x"5F");

        -- Wait for Receiver processing
        wait for clk_period * 30;

        -- CHECK: Did the receiver assert 'is_corrupt'? 
        -- If the CRC was correct, the residue should be 0, so is_corrupt should be '0'
        if is_corrupt = '0' then
            report ">>> [PASS] RX Validated Packet (Residue Zero)" severity note;
        else
            report ">>> [FAIL] RX marked valid packet as corrupt! (Residue was not zero)" severity error;
        end if;

        wait;
    end process;
END;