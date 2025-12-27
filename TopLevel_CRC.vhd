library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TopLevel_CRC is
    Port ( 
        clk         : in  std_logic;
        reset       : in  std_logic; 
        btn_tick    : in  std_logic;
        uart_rx     : in  std_logic;
        uart_tx     : out std_logic;
        data_crc    : out std_logic_vector(31 downto 0); 
        is_corrupt  : out std_logic
    );
end TopLevel_CRC;

architecture Behavioral of TopLevel_CRC is

    -- State Machine Definition
    type state_type is (CRC_Transmitter, CRC_Receiver);
    signal current_mode : state_type := CRC_Transmitter;

    -- TX State Machine
    type tx_state_type is (IDLE, ECHO_CHAR, WAIT_ECHO_DONE, 
                           CHECK_PADDING, INJECT_PAD, 
                           SEND_CRC_3, WAIT_CRC_3, SEND_CRC_2, WAIT_CRC_2, 
                           SEND_CRC_1, WAIT_CRC_1, SEND_CRC_0, WAIT_CRC_0,
                           SEND_STATUS, WAIT_STATUS);
    signal tx_state : tx_state_type := IDLE;

    -- Internal Signals
    signal clk_tx, clk_rx, tx_gate_enable, rx_gate_enable : std_logic;
    
    -- UART Signals
    signal uart_data_out   : std_logic_vector(7 downto 0);
    signal uart_rx_busy    : std_logic;
    signal uart_rx_busy_prev : std_logic := '0';
    signal internal_data_valid : std_logic := '0'; -- Pulse when real data arrives
    
    signal uart_tx_data    : std_logic_vector(7 downto 0);
    signal uart_tx_send    : std_logic := '0';
    signal uart_tx_busy    : std_logic;

    -- Padding Logic Signals
    signal byte_tracker    : integer range 0 to 3 := 0; 
    signal pad_zeros_active: std_logic; -- Combinatorial signal
    signal crc_input_data  : std_logic_vector(7 downto 0);
    signal crc_input_valid : std_logic;

    -- CRC Internal Results
    signal internal_crc_out : std_logic_vector(31 downto 0);
    signal internal_is_corrupt : std_logic;

    -- NEW SIGNAL for auto-resetting the CRC engine
    signal internal_reset : std_logic;
    signal btn_tick_prev : std_logic := '0';
    signal soft_reset_pulse : std_logic := '0';

    -- Component Declarations
    component uart is
        port (
            i_CLOCK     : in std_logic;
            i_DATA      : in std_logic_vector(7 downto 0);
            i_SEND      : in std_logic;
            i_DISPLAY   : in std_logic;
            o_TX        : out std_logic;
            i_RX        : in std_logic;
            i_log_ADDR  : in std_logic_vector(7 downto 0);
            o_sig_CRRP_DATA : out std_logic;
            o_sig_RX_BUSY   : out std_logic;
            o_sig_TX_BUSY   : out std_logic;
            o_DATA_OUT      : out std_logic_vector(7 downto 0);
            o_hex           : out std_logic_vector(6 downto 0)
        );
    end component;

    component CRCtransmitter is
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            crc_out    : out std_logic_vector(31 downto 0);
            reset : in std_logic;
            data_valid : in  std_logic
        );
    end component;

    component CRCreceiver is
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            is_corrupt : out std_logic;
            reset : in std_logic;
            data_valid : in  std_logic
        );
    end component;

begin

    ------------------------------------------------------------------
    -- 1. UART INSTANTIATION (Standard Component Mapping)
    ------------------------------------------------------------------
    UART_INST : uart
    port map(
        i_CLOCK     => clk,
        i_DATA      => uart_tx_data,
        i_SEND      => uart_tx_send,
        i_DISPLAY   => '0',
        o_TX        => uart_tx,
        i_RX        => uart_rx,
        i_log_ADDR  => (others => '0'),
        o_sig_CRRP_DATA => open,
        o_sig_RX_BUSY   => uart_rx_busy,
        o_sig_TX_BUSY   => uart_tx_busy,
        o_DATA_OUT      => uart_data_out,
        o_hex           => open
    );

    ------------------------------------------------------------------
    -- 2. DATA VALID DETECTION (Rising Edge of 'Ready' or Falling 'Busy')
    ------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            uart_rx_busy_prev <= uart_rx_busy;
            
            -- Detect Falling Edge of Busy (Data is ready)
            if uart_rx_busy_prev = '1' and uart_rx_busy = '0' then
                internal_data_valid <= '1';
            else
                internal_data_valid <= '0';
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 3. BYTE TRACKER (Consolidated Process)
    ------------------------------------------------------------------
    -- This fixes the "Multiple Drivers" error.
    -- We update the tracker if Real Data arrives OR if FSM is injecting padding.
    process(clk)
    begin
        if rising_edge(clk) then
            -- FIX: Reset tracker on Soft Reset (Mode switch / End of packet)
            if (reset = '1') or (soft_reset_pulse = '1') then 
                byte_tracker <= 0;
            else
                -- Condition: Real Data Pulse OR FSM Injection State
                -- FIX: Block increment if data is ENTER (0x0D) to prevent tracking it
                if (internal_data_valid = '1' and uart_data_out /= x"0D") or (tx_state = INJECT_PAD) then
                    if byte_tracker = 3 then
                        byte_tracker <= 0;
                    else
                        byte_tracker <= byte_tracker + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 4. PADDING MUX LOGIC
    ------------------------------------------------------------------
    -- Combinatorial logic to determine if we are padding
-- 4. PADDING MUX LOGIC
    pad_zeros_active <= '1' when tx_state = INJECT_PAD else '0';

    -- MUX: Feed CRC with either UART data or Zero Padding
    crc_input_data  <= x"00" when pad_zeros_active = '1' else uart_data_out;

    -- FIX: Gating Logic - Only validate input if it is NOT 'Enter' (x0D)
    crc_input_valid <= '1' when pad_zeros_active = '1' else 
                       (internal_data_valid and '1') when uart_data_out /= x"0D" else 
                       '0';

    ------------------------------------------------------------------
    -- 5. CLOCK GATING & CRC MODULES
    ------------------------------------------------------------------
    process(clk)
    begin
        if falling_edge(clk) then
            if current_mode = CRC_Transmitter then
                tx_gate_enable <= '1'; rx_gate_enable <= '0';
            else
                tx_gate_enable <= '0'; rx_gate_enable <= '1';
            end if;
        end if;
    end process;

    clk_tx <= clk and tx_gate_enable;
    clk_rx <= clk and rx_gate_enable;

    internal_reset <= reset or soft_reset_pulse;

    TX_INST : CRCtransmitter
    port map(
        clk        => clk_tx,
        input_data => crc_input_data, -- From MUX
        crc_out    => internal_crc_out,
        reset      => internal_reset, -- Use Internal Reset
        data_valid => crc_input_valid -- From MUX
    );

    RX_INST : CRCreceiver
    port map(
        clk        => clk_rx,
        input_data => crc_input_data, -- From MUX
        is_corrupt => internal_is_corrupt,
        reset      => internal_reset, -- Use Internal Reset
        data_valid => crc_input_valid -- From MUX
    );

    data_crc   <= internal_crc_out;
    is_corrupt <= internal_is_corrupt;

    ------------------------------------------------------------------
    -- 6. MAIN FSM (Control & Response)
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            tx_state <= IDLE;
            uart_tx_send <= '0';
            uart_tx_data <= (others => '0');
        elsif rising_edge(clk) then

            -- Default: Reset pulse is OFF
            soft_reset_pulse <= '0';
            
            -- Pulse Reset if Mode Button detected
            if btn_tick = '1' and btn_tick_prev = '0' then
                soft_reset_pulse <= '1';
            end if;
            
            case tx_state is
                
                when IDLE =>
                    uart_tx_send <= '0';
                    -- Check if data arrived (for Echo)
                    if internal_data_valid = '1' then
                        uart_tx_data <= uart_data_out;
                        tx_state <= ECHO_CHAR;
                    end if;

                when ECHO_CHAR =>
                    if uart_tx_busy = '0' then
                        uart_tx_send <= '1';
                        tx_state <= WAIT_ECHO_DONE;
                    end if;

                when WAIT_ECHO_DONE =>
                    uart_tx_send <= '0';
                    if uart_tx_busy = '1' then
                        -- Check for Enter Key (0x0D)
                        if uart_tx_data = x"0D" then
                            tx_state <= CHECK_PADDING;
                        else
                            tx_state <= IDLE;
                        end if;
                    end if;

                -- PADDING LOGIC
                when CHECK_PADDING =>
                    -- If tracker is 0, we have 4 bytes. Done.
                    -- If tracker != 0, we need to inject dummy bytes.
                    if byte_tracker = 0 then
                        if current_mode = CRC_Transmitter then 
                            tx_state <= SEND_CRC_3;
                        else 
                            tx_state <= SEND_STATUS; 
                        end if;
                    else
                        tx_state <= INJECT_PAD; -- Go inject a zero
                    end if;

                when INJECT_PAD =>
                    -- In this state, 'pad_zeros_active' becomes '1' (combinatorial).
                    -- The MUX sends 0x00 + Valid to CRC modules.
                    -- The 'byte_tracker' process sees this state and increments count.
                    -- We spend 1 cycle here, then go back to check if we need MORE padding.
                    tx_state <= CHECK_PADDING;

                -- SEND CRC RESULT (4 Bytes)
                when SEND_CRC_3 =>
                    if uart_tx_busy = '0' then
                        uart_tx_data <= internal_crc_out(31 downto 24);
                        uart_tx_send <= '1'; tx_state <= WAIT_CRC_3;
                    end if;
                when WAIT_CRC_3 =>
                    uart_tx_send <= '0'; if uart_tx_busy = '1' then tx_state <= SEND_CRC_2; end if;

                when SEND_CRC_2 =>
                    if uart_tx_busy = '0' then
                        uart_tx_data <= internal_crc_out(23 downto 16);
                        uart_tx_send <= '1'; tx_state <= WAIT_CRC_2;
                    end if;
                when WAIT_CRC_2 =>
                    uart_tx_send <= '0'; if uart_tx_busy = '1' then tx_state <= SEND_CRC_1; end if;

                when SEND_CRC_1 =>
                    if uart_tx_busy = '0' then
                        uart_tx_data <= internal_crc_out(15 downto 8);
                        uart_tx_send <= '1'; tx_state <= WAIT_CRC_1;
                    end if;
                when WAIT_CRC_1 =>
                    uart_tx_send <= '0'; if uart_tx_busy = '1' then tx_state <= SEND_CRC_0; end if;

                when SEND_CRC_0 =>
                    if uart_tx_busy = '0' then
                        uart_tx_data <= internal_crc_out(7 downto 0);
                        uart_tx_send <= '1'; tx_state <= WAIT_CRC_0;
                    end if;
                when WAIT_CRC_0 =>
                    uart_tx_send <= '0'; 
                    if uart_tx_busy = '1' then 
                        tx_state <= IDLE; 
                        soft_reset_pulse <= '1'; -- RESET DONE!
                    end if;
                -- SEND RX STATUS
                when SEND_STATUS =>
                    if uart_tx_busy = '0' then
                        if internal_is_corrupt = '0' then uart_tx_data <= x"56"; -- 'V'
                        else uart_tx_data <= x"43"; -- 'C'
                        end if;
                        uart_tx_send <= '1'; tx_state <= WAIT_STATUS;
                    end if;
                when WAIT_STATUS =>
                    uart_tx_send <= '0'; 
                    if uart_tx_busy = '1' then 
                        tx_state <= IDLE; 
                        soft_reset_pulse <= '1'; -- RESET DONE!
                    end if;
            end case;
        end if;
    end process;

    -- Button Mode Switch
    process(clk) begin
        if rising_edge(clk) then
            -- Store current button state for next cycle
            btn_tick_prev <= btn_tick;

            -- Check for Rising Edge: (Current is 1 AND Previous was 0)
            if btn_tick = '1' and btn_tick_prev = '0' then
                if current_mode = CRC_Transmitter then 
                    current_mode <= CRC_Receiver;
                else 
                    current_mode <= CRC_Transmitter; 
                end if;
            end if;
        end if;
    end process;

end Behavioral;