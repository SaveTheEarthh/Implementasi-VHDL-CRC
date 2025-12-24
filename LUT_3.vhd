library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LUT_3 is
    Port ( 
        addr_in  : in  STD_LOGIC_VECTOR (7 downto 0);
        data_out : out STD_LOGIC_VECTOR (31 downto 0)
    );
end LUT_3;

architecture Behavioral of LUT_3 is

    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);

    -- Ganti nama fungsi biar rapi
    function init_lut_3 return rom_type is
        variable temp_rom : rom_type := (others => (others => '0'));
        variable crc      : std_logic_vector(31 downto 0);
        variable top_bit  : std_logic;
        constant POLY     : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        for i in 0 to 255 loop
            crc := (others => '0');
            
            -- LUT_3 SPECIFIC: Place Input Byte at bits 15-8
            -- This simulates shifting the byte by 8 bits (Shift 8)
            crc(15 downto 8) := std_logic_vector(to_unsigned(i, 8)); -- KOREKSI KOMENTAR: Shift 8

            -- Run the CRC LFSR for 32 Clock Cycles
            for j in 1 to 32 loop
                top_bit := crc(31);
                crc := crc(30 downto 0) & '0'; 
                if top_bit = '1' then
                    crc := crc xor POLY;
                end if;
            end loop;

            temp_rom(i) := crc;
        end loop;
        return temp_rom;
    end function;

    -- Panggil fungsi yang namanya sudah diganti
    constant ROM : rom_type := init_lut_3;

begin
    process(addr_in)
    begin
        if is_x(addr_in) then
            data_out <= (others => 'U');
        else
            data_out <= ROM(to_integer(unsigned(addr_in)));
        end if;
    end process;

end Behavioral;