library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_CRCreceiver is
    -- Testbench tidak memiliki port
end tb_CRCreceiver;

architecture Behavioral of tb_CRCreceiver is

    -- 1. Komponen yang akan diuji (DUT - Design Under Test)
    component CRCreceiver
        Port ( 
            input_data : in  STD_LOGIC_VECTOR (7 downto 0);
            is_corrupt : out STD_LOGIC;
            data_valid : in  STD_LOGIC;
            clk        : in  STD_LOGIC
        );
    end component;

    -- 2. Sinyal Internal untuk menghubungkan ke DUT
    signal tb_clk        : std_logic := '0';
    signal tb_data_valid : std_logic := '0';
    signal tb_input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tb_is_corrupt : std_logic;

    -- 3. Konstanta Waktu
    constant CLK_PERIOD : time := 10 ns; -- 100 MHz Clock

begin

    -- Instansiasi DUT
    uut: CRCreceiver
        port map (
            clk        => tb_clk,
            data_valid => tb_data_valid,
            input_data => tb_input_data,
            is_corrupt => tb_is_corrupt
        );

    -- Proses Pembangkit Clock
    clk_process : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD/2;
        tb_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Proses Stimulus (Skenario Data Valid)
    stim_proc: process
    begin
        -- Inisialisasi
        wait for 100 ns;
        
        report "TEST 1: Mengirim Data Valid (Payload + CRC Benar)...";
        
        -- -----------------------------------------------------------
        -- BAGIAN 1: Kirim Payload (01 02 03 04)
        -- -----------------------------------------------------------
        
        -- Byte 1
        tb_input_data <= x"01"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD; -- Pulse 1 clock
        tb_data_valid <= '0';
        wait for 50 ns;      -- Jeda antar byte
        
        -- Byte 2
        tb_input_data <= x"02"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;

        -- Byte 3
        tb_input_data <= x"03"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;

        -- Byte 4 (Payload Terakhir)
        tb_input_data <= x"04"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;
        
        -- -----------------------------------------------------------
        -- BAGIAN 2: Kirim Checksum CRC (B6 3C FB CD)
        -- Ini adalah 'Kunci Jawaban' agar Checker bilang VALID
        -- -----------------------------------------------------------

        -- Byte 5 (CRC Byte MSB)
        tb_input_data <= x"B6"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;

        -- Byte 6
        tb_input_data <= x"3C"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;

        -- Byte 7
        tb_input_data <= x"FB"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        wait for 50 ns;

        -- Byte 8 (CRC Byte LSB / Akhir Paket)
        tb_input_data <= x"CD"; 
        tb_data_valid <= '1';
        wait for CLK_PERIOD;
        tb_data_valid <= '0';
        
        -- -----------------------------------------------------------
        -- BAGIAN 3: Verifikasi
        -- -----------------------------------------------------------
        
        report "Data Selesai Dikirim. Menunggu Hasil Checker...";
        wait for 200 ns; -- Beri waktu FSM memproses (State DONE)
        
        -- Cek Hasil
        if tb_is_corrupt = '0' then
            report "SUKSES: Checker mendeteksi DATA VALID!" severity note;
        else
            report "GAGAL: Checker mendeteksi ERROR, padahal data benar." severity error;
        end if;

        wait; -- Stop simulasi
    end process;

end Behavioral;