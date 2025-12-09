library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_CRCreceiver_Check is
end tb_CRCreceiver_Check;

architecture Behavioral of tb_CRCreceiver_Check is

    -- 1. Deklarasi Komponen (Unit Under Test)
    component CRCreceiver
        Port ( 
            clk        : in  STD_LOGIC;
            input_data : in  STD_LOGIC_VECTOR (7 downto 0);
            data_valid : in  STD_LOGIC;
            is_corrupt : out STD_LOGIC
        );
    end component;

    -- 2. Sinyal Internal
    signal tb_clk        : std_logic := '0';
    signal tb_data_valid : std_logic := '0';
    signal tb_input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal tb_is_corrupt : std_logic;

    -- 3. Clock 100 MHz
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instansiasi
    uut: CRCreceiver
        port map (
            clk        => tb_clk,
            input_data => tb_input_data,
            data_valid => tb_data_valid,
            is_corrupt => tb_is_corrupt
        );

    -- Clock Process
    clk_process : process
    begin
        tb_clk <= '0';
        wait for CLK_PERIOD/2;
        tb_clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Stimulus Process
    stim_proc: process
        -- Prosedur kecil untuk mengirim 1 byte agar kode rapi
        procedure send_byte(data_in : in std_logic_vector(7 downto 0)) is
        begin
            tb_input_data <= data_in;
            tb_data_valid <= '1';
            wait for CLK_PERIOD; -- Pulse 1 clock
            tb_data_valid <= '0';
            wait for 50 ns;      -- Simulasi jeda UART (biar realistis)
        end procedure;

    begin
        -- Reset / Idle awal
        wait for 100 ns;
        report "SIMULASI MULAI: Mengirim Data + CRC Valid";

        -- ==========================================
        -- BAGIAN 1: Payload (01 02 03 04)
        -- ==========================================
        send_byte(x"01");
        send_byte(x"02");
        send_byte(x"03");
        send_byte(x"04");
        
        -- (Di titik ini SIPO penuh pertama kali -> FSM menghitung CRC awal)

        -- ==========================================
        -- BAGIAN 2: Checksum (89 A1 89 7F)
        -- Nilai ini didapat dari perhitungan CRC-32 (Init=0, Poly=04C11DB7)
        -- ==========================================
        send_byte(x"89");
        send_byte(x"A1");
        send_byte(x"89");
        send_byte(x"7F");

        -- (Di titik ini SIPO penuh kedua kali -> FSM menghitung akumulasi)
        -- Seharusnya Sisa Register menjadi 0 (atau Magic Number)

        -- ==========================================
        -- BAGIAN 3: Sinyal Akhir (Enter / 0x0D)
        -- ==========================================
        send_byte(x"0D"); 

        -- Tunggu hasil evaluasi FSM
        wait for 100 ns;

        -- ==========================================
        -- VERIFIKASI
        -- ==========================================
        if tb_is_corrupt = '0' then
            report "HASIL: SUKSES! is_corrupt = 0 (Data Valid)" severity note;
        else
            report "HASIL: GAGAL! is_corrupt = 1 (Data Salah Hitung)" severity error;
        end if;

        wait; -- Selesai
    end process;

end Behavioral;