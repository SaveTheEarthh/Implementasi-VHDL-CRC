library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Result_Serializer is
    Port ( 
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        start_send  : in  STD_LOGIC; 
        
        mode_rx     : in  STD_LOGIC; -- '0' = TX Mode, '1' = RX Mode
        data_in     : in  STD_LOGIC_VECTOR (31 downto 0);
        is_corrupt  : in  STD_LOGIC;
        
        uart_busy   : in  STD_LOGIC;
        uart_start  : out STD_LOGIC;
        uart_data   : out STD_LOGIC_VECTOR (7 downto 0)
    );
end Result_Serializer;

architecture Behavioral of Result_Serializer is

    type state_type is (IDLE, PREPARE, START_TX, WAIT_BUSY_HIGH, WAIT_BUSY_LOW, NEXT_CHAR);
    signal state : state_type := IDLE;

    -- Buffer to hold the message (Max 16 chars)
    type char_array is array (0 to 15) of std_logic_vector(7 downto 0);
    signal msg_buffer : char_array := (others => (others => '0'));
    
    signal char_count : integer range 0 to 16 := 0;
    signal tx_index   : integer range 0 to 16 := 0;
    
    -- [FIXED] Robust Function: Explicitly returns 8-bit Vector
    function to_hex_char(nibble : std_logic_vector(3 downto 0)) return std_logic_vector is
        variable n_int : integer;
    begin
        n_int := to_integer(unsigned(nibble));
        if n_int < 10 then
            -- ASCII '0' is 48. n_int + 48 gives '0'..'9'
            return std_logic_vector(to_unsigned(n_int + 48, 8)); 
        else
            -- ASCII 'A' is 65. n_int(10) + 55 = 65 ('A')
            return std_logic_vector(to_unsigned(n_int + 55, 8)); 
        end if;
    end function;

begin

    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            uart_start <= '0';
            uart_data <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                
                -- 1. Wait for Trigger
                when IDLE =>
                    uart_start <= '0';
                    tx_index <= 0;
                    if start_send = '1' then
                        state <= PREPARE;
                    end if;

                -- 2. Build the Message String
                when PREPARE =>
                    msg_buffer <= (others => x"20"); -- Clear with spaces
                    
                    if mode_rx = '0' then
                        -- TX MODE: "CRC: XXXXXXXX"
                        msg_buffer(0) <= x"43"; -- C
                        msg_buffer(1) <= x"52"; -- R
                        msg_buffer(2) <= x"43"; -- C
                        msg_buffer(3) <= x"3A"; -- :
                        msg_buffer(4) <= x"20"; -- space
                        
                        -- Convert 32-bit Hex to ASCII
                        msg_buffer(5) <= to_hex_char(data_in(31 downto 28));
                        msg_buffer(6) <= to_hex_char(data_in(27 downto 24));
                        msg_buffer(7) <= to_hex_char(data_in(23 downto 20));
                        msg_buffer(8) <= to_hex_char(data_in(19 downto 16));
                        msg_buffer(9) <= to_hex_char(data_in(15 downto 12));
                        msg_buffer(10) <= to_hex_char(data_in(11 downto 8));
                        msg_buffer(11) <= to_hex_char(data_in(7 downto 4));
                        msg_buffer(12) <= to_hex_char(data_in(3 downto 0));
                        
                        msg_buffer(13) <= x"0D"; -- CR
                        msg_buffer(14) <= x"0A"; -- LF
                        char_count <= 15;
                        
                    else
                        -- RX MODE: Status
                        if is_corrupt = '0' then
                            -- "RX: VALID"
                            msg_buffer(0) <= x"52"; -- R
                            msg_buffer(1) <= x"58"; -- X
                            msg_buffer(2) <= x"3A"; -- :
                            msg_buffer(3) <= x"20"; -- space
                            msg_buffer(4) <= x"56"; -- V
                            msg_buffer(5) <= x"41"; -- A
                            msg_buffer(6) <= x"4C"; -- L
                            msg_buffer(7) <= x"49"; -- I
                            msg_buffer(8) <= x"44"; -- D
                            msg_buffer(9) <= x"0D"; -- CR
                            msg_buffer(10) <= x"0A"; -- LF
                            char_count <= 11;
                        else
                            -- "RX: CORRUPT"
                            msg_buffer(0) <= x"52"; -- R
                            msg_buffer(1) <= x"58"; -- X
                            msg_buffer(2) <= x"3A"; -- :
                            msg_buffer(3) <= x"20"; -- space
                            msg_buffer(4) <= x"43"; -- C
                            msg_buffer(5) <= x"4F"; -- O
                            msg_buffer(6) <= x"52"; -- R
                            msg_buffer(7) <= x"52"; -- R
                            msg_buffer(8) <= x"55"; -- U
                            msg_buffer(9) <= x"50"; -- P
                            msg_buffer(10) <= x"54"; -- T
                            msg_buffer(11) <= x"0D"; -- CR
                            msg_buffer(12) <= x"0A"; -- LF
                            char_count <= 13;
                        end if;
                    end if;
                    
                    state <= START_TX;

                -- 3. Trigger UART
                when START_TX =>
                    uart_data <= msg_buffer(tx_index);
                    uart_start <= '1';
                    state <= WAIT_BUSY_HIGH;

                -- 4. Wait for Acknowledge
                when WAIT_BUSY_HIGH =>
                    if uart_busy = '1' then
                        uart_start <= '0';
                        state <= WAIT_BUSY_LOW;
                    end if;

                -- 5. Wait for Finish
                when WAIT_BUSY_LOW =>
                    if uart_busy = '0' then
                        state <= NEXT_CHAR;
                    end if;

                -- 6. Loop
                when NEXT_CHAR =>
                    if tx_index < (char_count - 1) then
                        tx_index <= tx_index + 1;
                        state <= START_TX;
                    else
                        state <= IDLE;
                    end if;
                    
            end case;
        end if;
    end process;

end Behavioral;