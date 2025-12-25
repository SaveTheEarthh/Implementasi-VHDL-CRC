library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LUT_Prev is
    Port ( 
        prev_crc_in : in  STD_LOGIC_VECTOR (31 downto 0);
        lut_prev_out : out  STD_LOGIC_VECTOR (31 downto 0)
    );
end LUT_Prev;

architecture Behavioral of LUT_Prev is
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);

    -- Generates LUT for 64-cycle displacement (32 bits position + 32 bits shift)
    function init_lut_64(shift_val : integer) return rom_type is
        variable temp_rom : rom_type := (others => (others => '0'));
        variable crc      : std_logic_vector(31 downto 0);
        variable top_bit  : std_logic;
        constant POLY     : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        for i in 0 to 255 loop
            crc := (others => '0');
            crc(shift_val + 7 downto shift_val) := std_logic_vector(to_unsigned(i, 8));
            for j in 1 to 32 loop -- Corrected: Run for 64 cycles
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

    constant ROM_MSB : rom_type := init_lut_64(24);
    constant ROM_B2  : rom_type := init_lut_64(16);
    constant ROM_B1  : rom_type := init_lut_64(8);
    constant ROM_LSB : rom_type := init_lut_64(0);
begin
process(prev_crc_in)
begin
    -- Prevent TO_INTEGER errors during initialization [cite: 842]
    if is_x(prev_crc_in) then
        lut_prev_out <= (others => '0');
    else
        lut_prev_out <= ROM_MSB(to_integer(unsigned(prev_crc_in(31 downto 24)))) xor
                        ROM_B2(to_integer(unsigned(prev_crc_in(23 downto 16)))) xor
                        ROM_B1(to_integer(unsigned(prev_crc_in(15 downto 8)))) xor
                        ROM_LSB(to_integer(unsigned(prev_crc_in(7 downto 0))));
    end if;
end process;
end Behavioral;