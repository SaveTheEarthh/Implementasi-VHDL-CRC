library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

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

    type state_type is (CRC_Transmitter, CRC_Receiver);
    signal current_state : state_type;

    signal uart_data_out : std_logic_vector(7 downto 0);
    signal uart_valid    : std_logic;
    
    -- Filtered signals
    signal valid_to_crc  : std_logic;
    signal compute_final : std_logic;
    
    signal valid_for_tx, valid_for_rx : std_logic;
    signal tx_out_signal, rx_out_signal : std_logic_vector(31 downto 0);
    signal btn_tick_prev : std_logic := '0';
    signal internal_reset : std_logic;

    component uart
        port (
            i_CLOCK : in std_logic;
            i_RX    : in std_logic;
            o_DATA  : out std_logic_vector(7 downto 0);
            o_VALID : out std_logic; 
            i_DATA  : in std_logic_vector(7 downto 0);
            i_SEND  : in std_logic;
            o_TX    : out std_logic;
            o_TX_BUSY : out std_logic
        );
    end component;

    -- [UPDATE] Added compute_final port
    component CRCtransmitter
        port ( reset : in std_logic; clk : in std_logic; input_data : in std_logic_vector (7 downto 0); crc_out : out std_logic_vector(31 downto 0); data_valid : in std_logic; compute_final : in std_logic );
    end component;

    component CRCreceiver
        port ( reset : in std_logic; clk : in std_logic; input_data : in std_logic_vector (7 downto 0); is_corrupt : out std_logic; data_valid : in std_logic; rx_debug_data : out std_logic_vector(31 downto 0); compute_final : in std_logic );
    end component;

begin
    internal_reset <= reset OR btn_tick;

    UART_INST : uart
    port map (
        i_CLOCK => clk,
        i_RX    => uart_rx,
        o_DATA  => uart_data_out,   
        o_VALID => uart_valid,      
        i_DATA  => uart_data_out,   
        i_SEND  => '0',        
        o_TX    => uart_tx,
        o_TX_BUSY => open
    );

    -- [CRITICAL LOGIC] Filter 'Enter' (0x0D)
    -- If data is 0x0D, DO NOT send 'valid' to CRC (keeps data clean).
    -- Instead, send 'compute_final' to force processing of partial buffer.
    valid_to_crc  <= uart_valid when (uart_data_out /= x"0D") else '0';
    compute_final <= uart_valid when (uart_data_out = x"0D") else '0';

    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= CRC_Transmitter;
            btn_tick_prev <= '0';
        elsif rising_edge(clk) then
            btn_tick_prev <= btn_tick;
            case current_state is
                when CRC_Transmitter =>
                    if (btn_tick = '1' and btn_tick_prev = '0') then current_state <= CRC_Receiver; end if;
                when CRC_Receiver =>
                    if (btn_tick = '1' and btn_tick_prev = '0') then current_state <= CRC_Transmitter; end if;
            end case;
        end if;
    end process;

    valid_for_tx <= valid_to_crc when (current_state = CRC_Transmitter) else '0';
    valid_for_rx <= valid_to_crc when (current_state = CRC_Receiver)    else '0';

    TX_INST : CRCtransmitter
    port map( 
        reset => internal_reset, 
        clk => clk, 
        input_data => uart_data_out, 
        crc_out => tx_out_signal, 
        data_valid => valid_for_tx,
        compute_final => compute_final -- Connected
    );

    RX_INST : CRCreceiver
    port map( 
        reset => internal_reset, 
        clk => clk, 
        input_data => uart_data_out, 
        is_corrupt => is_corrupt, 
        data_valid => valid_for_rx, 
        rx_debug_data => rx_out_signal,
        compute_final => compute_final -- Connected
    );

    data_crc <= tx_out_signal when current_state = CRC_Transmitter else rx_out_signal;

end Behavioral;