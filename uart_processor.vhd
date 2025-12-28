library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_processor is
    Port (
        clk         : in  STD_LOGIC;
        rst_n       : in  STD_LOGIC;
        
        -- Sambung ke UART RX
        rx_data     : in  STD_LOGIC_VECTOR(7 downto 0); -- Dari o_DATA
        rx_valid    : in  STD_LOGIC;                    -- Dari o_VALID
        
        -- Sambung ke UART TX
        tx_data     : out STD_LOGIC_VECTOR(7 downto 0); -- Ke i_DATA
        tx_start    : out STD_LOGIC;                    -- Ke i_START
        tx_busy     : in  STD_LOGIC                     -- Dari o_BUSY
    );
end uart_processor;

architecture Behavioral of uart_processor is

    type state_type is (IDLE, GET_MSG, GET_SUFFIX, PROCESS_CMD, SEND_RES, WAIT_TX);
    signal state : state_type := IDLE;

    -- Buffer & CRC
    signal calculated_crc : std_logic_vector(31 downto 0) := x"FFFFFFFF"; 
    signal received_crc   : std_logic_vector(31 downto 0) := (others => '0');
    signal is_tx_mode     : std_logic := '0'; -- '1' jika user minta hitungkan CRC

    -- String Buffer untuk pengiriman balik
    signal tx_buffer : string(1 to 20) := (others => ' '); 
    signal tx_len    : integer range 0 to 20 := 0;
    signal tx_idx    : integer range 1 to 21 := 1;

    -- Konstanta
    constant CHAR_PIPE : std_logic_vector(7 downto 0) := x"7C"; -- '|'
    constant CHAR_LF   : std_logic_vector(7 downto 0) := x"0A"; -- '\n'

    -- Fungsi Konversi ASCII Hex ke 4-bit
    function hex_char_to_val(c : std_logic_vector) return std_logic_vector is
    begin
        if c >= x"30" and c <= x"39" then return std_logic_vector(unsigned(c) - x"30")(3 downto 0);
        elsif c >= x"41" and c <= x"46" then return std_logic_vector(unsigned(c) - x"37")(3 downto 0);
        elsif c >= x"61" and c <= x"66" then return std_logic_vector(unsigned(c) - x"57")(3 downto 0);
        else return "0000"; end if;
    end function;

    -- Fungsi Konversi 4-bit ke ASCII Hex
    function val_to_hex_char(v : std_logic_vector) return character is
        variable i : integer;
    begin
        i := to_integer(unsigned(v));
        if i < 10 then return character'val(i + 48); -- '0'
        else return character'val(i + 55); end if;   -- 'A'
    end function;

    -- CRC32 Sederhana (Logic XOR polynomial standar)
    function update_crc32(crc_in : std_logic_vector; data_in : std_logic_vector) return std_logic_vector is
        variable crc_tmp : std_logic_vector(31 downto 0);
    begin
        crc_tmp := crc_in;
        -- Implementasi sederhana: XOR byte masuk ke LSB (bisa diganti algo full IEEE 802.3)
        crc_tmp := (crc_tmp(23 downto 0) & data_in) xor x"04C11DB7"; 
        return crc_tmp;
    end function;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                state <= IDLE;
                tx_start <= '0';
            else
                -- Default
                tx_start <= '0';

                case state is
                    -- 1. IDLE: Reset CRC, tunggu data pertama
                    when IDLE =>
                        if rx_valid = '1' then
                            calculated_crc <= x"FFFFFFFF"; -- Init CRC
                            
                            if rx_data = CHAR_PIPE then
                                state <= GET_SUFFIX; -- Pesan kosong
                            else
                                calculated_crc <= update_crc32(x"FFFFFFFF", rx_data);
                                state <= GET_MSG;
                            end if;
                        end if;

                    -- 2. GET_MSG: Baca pesan sampai ketemu '|'
                    when GET_MSG =>
                        if rx_valid = '1' then
                            if rx_data = CHAR_PIPE then
                                state <= GET_SUFFIX;
                            else
                                calculated_crc <= update_crc32(calculated_crc, rx_data);
                            end if;
                        end if;

                    -- 3. GET_SUFFIX: Baca apa setelah '|'
                    when GET_SUFFIX =>
                        if rx_valid = '1' then
                            if rx_data = CHAR_LF then
                                -- Ketemu Enter. Cek apakah tadi kita terima CRC atau kosong?
                                -- Logika simplifikasi: Jika received_crc masih 0, anggap TX Mode
                                -- (Atau kita bisa set flag khusus saat terima digit hex)
                                state <= PROCESS_CMD;
                            else
                                -- Asumsi user kirim Hex CRC. Geser masuk.
                                received_crc <= received_crc(27 downto 0) & hex_char_to_val(rx_data);
                                is_tx_mode <= '0'; -- Ini mode RX (validasi)
                            end if;
                        else
                            -- Kalau belum terima data, set default ke TX Mode dulu
                            -- Nanti kalau terima Hex, flag ini di-overwrite jadi '0' di atas
                            if is_tx_mode = '0' and received_crc = x"00000000" then
                                is_tx_mode <= '1'; 
                            end if;
                        end if;

                    -- 4. PROCESS_CMD: Tentukan Balasan
                    when PROCESS_CMD =>
                        if is_tx_mode = '1' then
                            -- Mode TX: Kirim "CRC : XXXXXXXX"
                            tx_buffer(1 to 6) <= "CRC : ";
                            tx_buffer(7)  <= val_to_hex_char(calculated_crc(31 downto 28));
                            tx_buffer(8)  <= val_to_hex_char(calculated_crc(27 downto 24));
                            tx_buffer(9)  <= val_to_hex_char(calculated_crc(23 downto 20));
                            tx_buffer(10) <= val_to_hex_char(calculated_crc(19 downto 16));
                            tx_buffer(11) <= val_to_hex_char(calculated_crc(15 downto 12));
                            tx_buffer(12) <= val_to_hex_char(calculated_crc(11 downto 8));
                            tx_buffer(13) <= val_to_hex_char(calculated_crc(7 downto 4));
                            tx_buffer(14) <= val_to_hex_char(calculated_crc(3 downto 0));
                            tx_len <= 14;
                        else
                            -- Mode RX: Validasi
                            if calculated_crc = received_crc then
                                tx_buffer(1 to 10) <= "RX : VALID";
                                tx_len <= 10;
                            else
                                tx_buffer(1 to 12) <= "RX : INVALID";
                                tx_len <= 12;
                            end if;
                        end if;
                        
                        tx_idx <= 1;
                        state <= SEND_RES;

                    -- 5. SEND_RES: Kirim byte ke UART TX
                    when SEND_RES =>
                        if tx_idx <= tx_len then
                            tx_data <= std_logic_vector(to_unsigned(character'pos(tx_buffer(tx_idx)), 8));
                            tx_start <= '1'; -- Trigger pulsa
                            state <= WAIT_TX;
                        else
                            -- Reset untuk pesan berikutnya
                            received_crc <= (others => '0');
                            is_tx_mode <= '0';
                            state <= IDLE;
                        end if;

                    -- 6. WAIT_TX: Tunggu UART TX modul selesai
                    when WAIT_TX =>
                        -- Tunggu busy naik dulu (tanda mulai), lalu tunggu busy turun
                        if tx_busy = '0' and tx_start = '0' then
                            tx_idx <= tx_idx + 1;
                            state <= SEND_RES;
                        end if;

                end case;
            end if;
        end if;
    end process;
end Behavioral;