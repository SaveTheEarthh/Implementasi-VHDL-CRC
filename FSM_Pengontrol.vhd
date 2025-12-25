library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FSM_Pengontrol is
    Port ( 
        clk           : in  STD_LOGIC;
        is_4          : in  STD_LOGIC; 
        is_end        : in  STD_LOGIC; 
        chunk_ctrl    : out STD_LOGIC; 
        feedback_ctrl : out STD_LOGIC; 
        sel_out_xor   : out STD_LOGIC; 
        en_regis      : out STD_LOGIC; 
        Reset         : out STD_LOGIC; -- Corrected to Active-High for Counter
        Sel_PIPO      : out STD_LOGIC 
    );
end FSM_Pengontrol;

architecture Behavioral of FSM_Pengontrol is
    type state_type is (S_IDLE, S_FIRST_CHUNK, S_BUFFER, S_NEXT_CHUNK, S_DONE);
    signal current_state, next_state : state_type;
begin
    process(clk)
    begin
        if rising_edge(clk) then 
            current_state <= next_state;
        end if;
    end process;

    process(current_state, is_4, is_end)
    begin
        -- DEFAULT VALUES: Standardize to B-Input selection (Active Paths)
        chunk_ctrl    <= '1';    feedback_ctrl <= '1';
        sel_out_xor   <= '1';    en_regis      <= '0';
        Reset         <= '0';    Sel_PIPO      <= '1';
        next_state    <= current_state;

        case current_state is
            when S_IDLE =>
                Reset <= '1'; -- Keep counter cleared until data arrives
                if is_4 = '1' then next_state <= S_FIRST_CHUNK; 
                else Reset <= '0'; end if;

            when S_FIRST_CHUNK =>
                -- Pulse counter reset to prepare for next 4 bytes [cite: 105]
                Reset         <= '1'; 
                chunk_ctrl    <= '1'; -- Select New Data (Input B) [cite: 106]
                feedback_ctrl <= '0'; -- Select Initial Zeros (Input A) [cite: 107]
                sel_out_xor   <= '0'; -- Select XOR Path (Input A) [cite: 108]
                en_regis      <= '1'; -- Capture into register 
                next_state    <= S_BUFFER;

            when S_BUFFER =>
                Reset <= '0'; -- Allow counter to work [cite: 111]
                -- CRITICAL FIX: Put register in Hold Mode by selecting its own output
                -- This prevents it from sampling XOR zeros during the wait [cite: 112]
                sel_out_xor <= '1'; -- Select Feedback Path (Input B)
                en_regis    <= '0';
                if is_end = '1' then next_state <= S_DONE;
                elsif is_4 = '1' then next_state <= S_NEXT_CHUNK; end if;

            when S_NEXT_CHUNK =>
                Reset         <= '1'; -- Clear counter for next batch [cite: 117]
                chunk_ctrl    <= '1'; -- Select Data
                feedback_ctrl <= '1'; -- Select Feedback Path (Input B) [cite: 119]
                sel_out_xor   <= '0'; -- Select XOR Result Path (Input A) [cite: 120]
                en_regis      <= '1'; -- Capture accumulated CRC [cite: 121]
                next_state    <= S_BUFFER;

            when S_DONE =>
                if is_end = '0' then next_state <= S_IDLE; end if;
        end case;
    end process;
end Behavioral;