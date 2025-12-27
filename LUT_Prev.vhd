library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LUT_Prev is
    Port ( 
        prev_crc_in : in  STD_LOGIC_VECTOR (31 downto 0);
        lut_prev_out : out STD_LOGIC_VECTOR (31 downto 0)
    );
end LUT_Prev;

architecture Behavioral of LUT_Prev is
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);

    -- Generates LUT for 8-bit input with variable zero-padding
    function init_lut_8bit(zero_bytes : integer) return rom_type is
        variable temp_rom : rom_type := (others => (others => '0'));
        variable crc      : std_logic_vector(31 downto 0);
        variable top_bit  : std_logic;
        constant POLY     : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        for i in 0 to 255 loop
            crc := (others => '0');
            -- Initialize with input byte at MSB position
            crc(31 downto 24) := std_logic_vector(to_unsigned(i, 8));
            
            -- Process shifts
            for j in 1 to (8 + 8 * zero_bytes) loop
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

    -- Define the 4 Tables
    -- B3 = Shortest Shift (8 cycles) -> For LSB input
    -- B0 = Longest Shift (32 cycles) -> For MSB input
    constant LUT_Prev_B3 : rom_type := init_lut_8bit(0); 
    constant LUT_Prev_B2 : rom_type := init_lut_8bit(1); 
    constant LUT_Prev_B1 : rom_type := init_lut_8bit(2); 
    constant LUT_Prev_B0 : rom_type := init_lut_8bit(3); 

begin

    process(prev_crc_in)
    begin
        if is_x(prev_crc_in) then
            lut_prev_out <= (others => '0');
        else
            -- [FIXED] REVERSED MAPPING
            -- MSB (31-24) needs the most shifts -> use LUT_Prev_B0 (32 shifts)
            -- LSB (7-0) needs the least shifts  -> use LUT_Prev_B3 (8 shifts)
            
            lut_prev_out <= 
                LUT_Prev_B0(to_integer(unsigned(prev_crc_in(31 downto 24)))) xor -- MSB uses B0
                LUT_Prev_B1(to_integer(unsigned(prev_crc_in(23 downto 16)))) xor
                LUT_Prev_B2(to_integer(unsigned(prev_crc_in(15 downto 8))))  xor
                LUT_Prev_B3(to_integer(unsigned(prev_crc_in(7 downto 0))));    -- LSB uses B3
        end if;
    end process;

end Behavioral;