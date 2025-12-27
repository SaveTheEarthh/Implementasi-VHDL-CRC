library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity TopLevel_CRC is
    Port ( 
        clk         : in  std_logic; -- System Clock
        reset       : in  std_logic; -- Global Reset
        btn_tick    : in  std_logic; -- Button to switch modes
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

    -- Component Declarations
    component CRCtransmitter
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            crc_out    : out std_logic_vector(31 downto 0);
            data_valid : in  std_logic
        );
    end component;

    component CRCreceiver
        port (
            clk        : in  std_logic;
            input_data : in  std_logic_vector (7 downto 0);
            is_corrupt : out std_logic;
            data_valid : in  std_logic
        );
    end component;

begin

    ------------------------------------------------------------------
    -- 1. STATE MACHINE (MODE SWITCHING)
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= CRC_Transmitter; -- Default Mode
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- State Transition Logic
    process(current_state, btn_tick)
    begin
        next_state <= current_state; -- Default: Stay in current state
        
        case current_state is
            when CRC_Transmitter =>
                if btn_tick = '1' then
                    next_state <= CRC_Receiver;
                end if;

            when CRC_Receiver =>
                if btn_tick = '1' then
                    next_state <= CRC_Transmitter;
                end if;
        end case;
    end process;

    ------------------------------------------------------------------
    -- 2. DATA STEERING (The Safe Replacement for Clock Gating)
    ------------------------------------------------------------------
    -- Only the active module receives the 'data_valid' signal.
    -- The inactive module sees '0', keeping it in IDLE.
    valid_for_tx <= data_valid when (current_state = CRC_Transmitter) else '0';
    valid_for_rx <= data_valid when (current_state = CRC_Receiver)    else '0';

    ------------------------------------------------------------------
    -- 3. COMPONENT INSTANTIATIONS
    ------------------------------------------------------------------
    TX_INST : CRCtransmitter
    port map(
        clk        => clk,            -- Always running (Stable)
        input_data => input_data,
        crc_out    => data_crc,
        data_valid => valid_for_tx    -- Active only in TX mode
    );

    RX_INST : CRCreceiver
    port map(
        clk        => clk,            -- Always running (Stable)
        input_data => input_data,
        is_corrupt => is_corrupt,
        data_valid => valid_for_rx    -- Active only in RX mode
    );

end Behavioral;