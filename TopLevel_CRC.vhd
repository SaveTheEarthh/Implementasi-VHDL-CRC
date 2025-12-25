library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TopLevel_CRC is
    Port ( 
        clk         : in  std_logic; 
        reset       : in  std_logic; 
        btn_tick    : in  std_logic; 
        input_data  : in  std_logic_vector (7 downto 0);
        data_valid  : in  std_logic;
        data_crc    : out std_logic_vector(31 downto 0);
        is_corrupt  : out std_logic
    );
end TopLevel_CRC;

architecture Behavioral of TopLevel_CRC is

    -- State Machine Definition
    type state_type is (CRC_Transmitter, CRC_Receiver);
    signal current_state, next_state : state_type;

    -- Internal "Steering" signals
    signal valid_for_tx : std_logic;
    signal valid_for_rx : std_logic;

    signal tx_out_signal : std_logic_vector(31 downto 0);
    signal rx_out_signal : std_logic_vector(31 downto 0);

    signal btn_tick_prev : std_logic := '0';

    signal internal_reset : std_logic; -- New Signal

    -- Component Declarations
    component CRCtransmitter
        port (
            reset : in std_logic;
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            crc_out    : out std_logic_vector(31 downto 0); -- FIXED: Changed 'data_crc' to 'crc_out'
            data_valid : in  std_logic
        );
    end component;

    component CRCreceiver
        port (
            reset : in std_logic;
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            is_corrupt : out std_logic;
            data_valid : in  std_logic;
            rx_debug_data : out std_logic_vector(31 downto 0) -- ADD THIS
        );
    end component;

begin

    internal_reset <= reset OR btn_tick;
    ------------------------------------------------------------------
    -- 1. STATE MACHINE (MODE SWITCHING)
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= CRC_Transmitter;
            btn_tick_prev <= '0';
        elsif rising_edge(clk) then
            -- 1. Store previous button state to detect edges
            btn_tick_prev <= btn_tick; 

            -- 2. State Transition Logic (Only on RISING EDGE of button)
            case current_state is
                when CRC_Transmitter =>
                    -- Only switch if button is high NOW and was low BEFORE
                    if (btn_tick = '1' and btn_tick_prev = '0') then 
                        current_state <= CRC_Receiver;
                    end if;

                when CRC_Receiver =>
                    if (btn_tick = '1' and btn_tick_prev = '0') then
                        current_state <= CRC_Transmitter;
                    end if;
            end case;
        end if;
    end process;

    ------------------------------------------------------------------
    -- 2. DATA STEERING
    ------------------------------------------------------------------
    valid_for_tx <= data_valid when (current_state = CRC_Transmitter) else '0';
    valid_for_rx <= data_valid when (current_state = CRC_Receiver)    else '0';

    ------------------------------------------------------------------
    -- 3. COMPONENT INSTANTIATIONS
    ------------------------------------------------------------------
    TX_INST : CRCtransmitter
    port map(
        reset => internal_reset,
        clk        => clk,            
        input_data => input_data,
        crc_out    => tx_out_signal,       -- FIXED: Mapping port 'crc_out' to signal 'data_crc'
        data_valid => valid_for_tx    
    );

    RX_INST : CRCreceiver
    port map(
        reset => internal_reset,
        clk        => clk,            
        input_data => input_data,
        is_corrupt => is_corrupt,
        data_valid => valid_for_rx,
        rx_debug_data => rx_out_signal    
    );

    data_crc <= tx_out_signal when current_state = CRC_Transmitter else rx_out_signal;

end Behavioral;