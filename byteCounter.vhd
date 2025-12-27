library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
-- FSM oke, udah di simul sesuai
entity byteCounter is
    Port ( 
        -- INPUT (Dari Luar / Datapath)
        clk             : in  STD_LOGIC;
        data_valid      : in  STD_LOGIC;
        reset           : in STD_LOGIC; -- Sinyal dari SIPO (Chunk Ready) -- Sinyal deteksi akhir (misal tombol/timeout)

        -- OUTPUT (Ke Datapath)
        currentCount    : out STD_LOGIC_VECTOR(2 downto 0)
    );
end byteCounter;

architecture Behavioral of byteCounter is

    -- Definisi State
    type state_type is (
        s_zero, s_one, s_two, s_three, s_four       -- Selesai, Output Valid
    );
    
    signal current_state, next_state : state_type;

begin

    -- =========================================================
    -- PROSES 1: SEQUENTIAL (Memori State)
    -- =========================================================
    process(clk)
    begin
        if rising_edge(clk) then
            current_state <= next_state;
            end if;
           end process;

    -- =========================================================
    -- PROSES 2: COMBINATIONAL (Logika Transisi & Output)
    -- =========================================================
    process(current_state, data_valid)
    begin
        -- Default Values (Untuk mencegah Latch & Glitch)
        -- Kondisi "HOLD" yang aman:
        currentCount <= "000";
        
        next_state <= current_state; -- Default stay

        case current_state is
            
            -- STATE: IDLE
            when s_zero =>
                currentCount <= "000"; -- Bersihkan SIPO
                -- Pindah ke tunggu data pertama
                if data_valid = '1' then
                    next_state <= s_one;
                else
                    next_state <= s_zero;
                end if;
            
             when s_one =>
                currentCount <= "001"; -- Bersihkan SIPO
                -- Pindah ke tunggu data pertama
                if data_valid = '1' then
                    next_state <= s_two;
                else
                    next_state <= s_one;
                end if;
             when s_two =>
                currentCount <= "010"; -- Bersihkan SIPO
                -- Pindah ke tunggu data pertama
                if data_valid = '1' then
                    next_state <= s_three;
                else
                    next_state <= s_two;
                end if;
             when s_three =>
                currentCount <= "011"; -- Bersihkan SIPO
                -- Pindah ke tunggu data pertama
                if data_valid = '1' then
                    next_state <= s_four;
                else
                    next_state <= s_three;
                end if;
            when s_four =>
                currentCount <= "100"; -- Bersihkan SIPO
                -- Pindah ke tunggu data pertama
                if data_valid = '1' then
                    next_state <= s_one;
                else
                    next_state <= s_one;
                end if;

        end case;
    end process;

end Behavioral;