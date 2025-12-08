library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity CRC_Controller is
    Port ( 
        -- INPUT (Dari Luar / Datapath)
        clk             : in  STD_LOGIC;
        is_4      : in  STD_LOGIC; -- Sinyal dari SIPO (Chunk Ready)
        is_end   : in  STD_LOGIC; -- Sinyal deteksi akhir (misal tombol/timeout)

        -- OUTPUT (Ke Datapath)
        chunk_ctrl      : out STD_LOGIC; -- MUX Kiri
        feedback_ctrl   : out STD_LOGIC; -- MUX Kanan
        sel_out_xor     : out STD_LOGIC; -- MUX Atas Register
        en_regis        : out STD_LOGIC; -- Clock Enable Register
        Output_ctrl        : out STD_LOGIC; -- Clock Enable Register
        Reset        : out STD_LOGIC; -- Clock Enable Register
        Z_fromBus        : out STD_LOGIC; -- Clock Enable Register
        

    );
end CRC_Controller;

architecture Behavioral of CRC_Controller is

    -- Definisi State
    type state_type is (
        S_IDLE,         -- Reset & Menunggu Data Pertama
        s_First4Byte,   -- Menunggu SIPO penuh (4 byte pertama)
        S_Transition,   -- Hitung Iterasi Pertama (Pakai Seed)
        S_Buffer,    -- Menunggu SIPO penuh (4 byte selanjutnya)
        S_Next4Byte,    -- Hitung Iterasi Lanjut (Pakai Feedback)
        S_Done          -- Selesai, Output Valid
    );
    
    signal current_state, next_state : state_type;

begin

    -- =========================================================
    -- PROSES 1: SEQUENTIAL (Memori State)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                current_state <= S_IDLE;
            else
                current_state <= next_state;
            end if;
        end if;
    end process;

    -- =========================================================
    -- PROSES 2: COMBINATIONAL (Logika Transisi & Output)
    -- =========================================================
    process(current_state, is_4_bytes, is_end_packet)
    begin
        -- Default Values (Untuk mencegah Latch & Glitch)
        -- Kondisi "HOLD" yang aman:
        chunk_ctrl    <= '1'; -- Default blokir SIPO (Pilih 0)
        feedback_ctrl <= '1'; -- Default Feedback
        sel_out_xor   <= '0'; -- Default Loopback (Hold)
        en_regis      <= '1'; -- Default Register Mati
        reset    <= '1';
        
        next_state <= current_state; -- Default stay

        case current_state is
            
            -- STATE: IDLE
            when S_IDLE =>
                en_regis <= '1'; -- Bersihkan SIPO
                Chunk_ctrl <= '0';
                Feedback_ctrl <= '1';
                Output_ctrl <= '0';
                Z_fromBus <= '1';
                SelOut_XOR <= '1';
                Reset <= '1';
                -- Pindah ke tunggu data pertama
                if is_4_bytes = '1' then
                    next_state <= S_First4Byte;
                else
                    next_state <= S_IDLE;
                end if;

            -- STATE: MENUNGGU 4 BYTE PERTAMA
            when S_First4Byte =>
                en_regis <= '1'; -- Bersihkan SIPO
                Chunk_ctrl <= '0';
                Feedback_ctrl <= '1';
                Output_ctrl <= '0';
                Z_fromBus <= '1';
                SelOut_XOR <= '1';
                Reset <= '1';
                -- Diam di sini sampai SIPO penuh
                if is_end = '1' then
                    next_state <= S_DONE;
                else
                    next_state <= S_Transition;
                end if;

            -- STATE: HITUNG PAKET PERTAMA (Inisialisasi)
            when S_Transition =>
                en_regis <= '1'; -- Bersihkan SIPO
                Chunk_ctrl <= '1';
                Feedback_ctrl <= '0';
                Output_ctrl <= '0';
                Z_fromBus <= '1';
                SelOut_XOR <= '1';
                Reset <= '0';
                -- Diam di sini sampai SIPO penuh
                if is_4 = '0' and is_end = '0' then
                    next_state <= S_Transition;
                elsif is_end = '1' then
                    next_state <= S_Transition;
                elsif is_4 = '1' and is_end = '0' then
                    next_state <= S_Next4Byte;
                end if;
            -- STATE: MENUNGGU 4 BYTE SELANJUTNYA
            when S_Next4Byte =>
                en_regis <= '0'; -- Bersihkan SIPO
                Chunk_ctrl <= '0';
                Feedback_ctrl <= '0';
                Output_ctrl <= '0';
                Z_fromBus <= '1';
                SelOut_XOR <= '1';
                Reset <= '1';
                -- Diam di sini sampai SIPO penuh
                if is_4 = '0' and is_end = '0' then
                    next_state <= S_Transition;
                elsif is_end = '1' then
                    next_state <= S_Done;
                else
                    next_state <= S_Buffer;
                end if;
            
             when S_Buffer =>
                en_regis <= '1'; -- Bersihkan SIPO
                Chunk_ctrl <= '0';
                Feedback_ctrl <= '0';
                Output_ctrl <= '0';
                Z_fromBus <= '1';
                SelOut_XOR <= '0';
                Reset <= '0';
                -- Diam di sini sampai SIPO penuh
                if is_end = 0 then
                    next_state <= S_Transition;
                else
                    next_state <= S_Done;

            -- STATE: HITUNG PAKET LANJUTAN (Looping)
            when S_Done =>
                en_regis <= '0'; -- Bersihkan SIPO
                Chunk_ctrl <= '0';
                Feedback_ctrl <= '0';
                Output_ctrl <= '1';
                Z_fromBus <= '0';
                SelOut_XOR <= '1';
                Reset <= '1';
                -- Diam di sini sampai SIPO penuh
                next_state <= S_idle;

        end case;
    end process;

end Behavioral;