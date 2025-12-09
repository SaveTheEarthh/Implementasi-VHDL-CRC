library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SIPO_32bit is
    Port ( 
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- Interface ke UART (Input)
        uart_data   : in  STD_LOGIC_VECTOR (7 downto 0); -- Data 8-bit masuk
        uart_valid  : in  STD_LOGIC;                     -- Sinyal valid dari UART
        
        -- Interface ke CRC Engine (Output)
        chunk_data  : out STD_LOGIC_VECTOR (31 downto 0) -- Data 32-bit keluar                    -- Sinyal 'Is_4' (Penuh)
    );
end SIPO_32bit;

architecture Behavioral of SIPO_32bit is
    
    -- Register penampung geser (Internal Buffer)
    signal shift_reg : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Counter untuk menghitung jumlah byte (0 sampai 3)
    -- Menggunakan integer agar mudah dibaca logika if-nya
    signal byte_count : integer range 0 to 3 := 0;
    
    -- Sinyal internal untuk output valid
    signal ready_pulse : std_logic := '0';

begin

    -- Proses Utama
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                shift_reg   <= (others => '0');
                byte_count  <= 0;
                ready_pulse <= '0';
                
            -- Hanya bereaksi jika ada data valid dari UART
            elsif uart_valid = '1' then
                
                -- LOGIKA GESER (SHIFT LEFT)
                -- Data lama digeser ke kiri sejauh 8 bit
                -- Data baru (uart_data) ditempel di posisi paling kanan (LSB)
                -- Ilustrasi: [A] -> [A,B] -> [A,B,C] -> [A,B,C,D]
                shift_reg <= shift_reg(23 downto 0) & uart_data;
                
                -- LOGIKA COUNTER
                if byte_count = 3 then
                    -- Jika ini adalah byte ke-4 (0,1,2,3), berarti sudah penuh
                    byte_count  <= 0;    -- Reset counter untuk paket berikutnya
                    ready_pulse <= '1';  -- Nyalakan sinyal 'Is_4'
                else
                    -- Jika belum penuh, tambah counter
                    byte_count  <= byte_count + 1;
                    ready_pulse <= '0';
                end if;
                
            else
                -- Jika tidak ada data UART, matikan sinyal ready (Pulse hanya 1 clock)
                ready_pulse <= '0';
            end if;
        end if;
    end process;

    -- Sambungkan sinyal internal ke port output
    chunk_data  <= shift_reg; -- Ini yang disambung ke 'Is4' di FSM Anda

end Behavioral;