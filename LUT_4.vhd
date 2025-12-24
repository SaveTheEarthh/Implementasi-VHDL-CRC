library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LUT_4 is
    Port ( 
        addr_in  : in  STD_LOGIC_VECTOR (7 downto 0);
        data_out : out STD_LOGIC_VECTOR (31 downto 0)
    );
end LUT_4;

architecture Behavioral of LUT_4 is

    -- 1. Definisi Tipe Array ROM
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);

    -- 2. Fungsi Internal Pembangkit Tabel (Dijalankan saat Compile)
    function init_lut_4 return rom_type is
        variable temp_rom : rom_type := (others => (others => '0'));
        variable crc      : std_logic_vector(31 downto 0);
        variable top_bit  : std_logic;
        constant POLY     : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        for i in 0 to 255 loop
            -- Inisialisasi CRC dengan 0
            crc := (others => '0');
            
            -- LUT_4 SPECIFIC: Letakkan Input Byte di posisi LSB (Bits 7-0)
            -- Ini mensimulasikan data masuk tanpa pergeseran tambahan (Shift 0)
            crc(7 downto 0) := std_logic_vector(to_unsigned(i, 8)); 

            -- Jalankan LFSR CRC selama 32 Siklus Clock
            for j in 1 to 32 loop
                top_bit := crc(31);
                crc := crc(30 downto 0) & '0'; -- Shift Left
                if top_bit = '1' then
                    crc := crc xor POLY;
                end if;
            end loop;

            -- Simpan hasil ke ROM
            temp_rom(i) := crc;
        end loop;
        return temp_rom;
    end function;

    -- 3. Membuat Tabel Konstan
    constant ROM : rom_type := init_lut_4;

begin
    -- 4. Logika Pembacaan Sederhana
    process(addr_in)
    begin
        if is_x(addr_in) then
            data_out <= (others => 'U');
        else
            data_out <= ROM(to_integer(unsigned(addr_in)));
        end if;
    end process;

end Behavioral;