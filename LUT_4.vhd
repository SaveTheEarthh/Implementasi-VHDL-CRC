library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- NOTE: No "use work.CRC32_Pkg.ALL" here! We are completely independent now.

entity LUT_4 is
    Port ( 
        addr_in  : in  STD_LOGIC_VECTOR (7 downto 0);
        data_out : out  STD_LOGIC_VECTOR (31 downto 0)
    );
end LUT_4;

architecture Behavioral of LUT_4 is

    -- 1. Define the ROM Array Type locally
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);

    -- 2. Internal Function to Generate the Table (Runs once at compile time)
    function init_lut_1 return rom_type is
        variable temp_rom : rom_type := (others => (others => '0')); -- Initialize to 0
        variable crc      : std_logic_vector(31 downto 0);
        variable top_bit  : std_logic;
        constant POLY     : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        for i in 0 to 255 loop
            -- Initialize CRC with 0 for every iteration
            crc := (others => '0');
            
            -- LUT_1 SPECIFIC: Place Input Byte at MSB (Bits 31 downto 24)
            -- This simulates shifting the byte into the top of the register (Shift 24)
            crc(7 downto 0) := std_logic_vector(to_unsigned(i, 8)); -- Shift 0

            -- Run the CRC LFSR for 32 Clock Cycles
            for j in 1 to 32 loop
                top_bit := crc(31);
                crc := crc(30 downto 0) & '0'; -- Shift Left
                if top_bit = '1' then
                    crc := crc xor POLY;
                end if;
            end loop;

            -- Store result in ROM
            temp_rom(i) := crc;
        end loop;
        return temp_rom;
    end function;

    -- 3. The Actual Lookup Table (Created by the function above)
    constant ROM : rom_type := init_lut_1;

begin
    -- 4. Simple Read Logic
    -- Validates that addr_in is not 'U' or 'X' before converting to integer to prevent warnings
    process(addr_in)
    begin
        if is_x(addr_in) then
            data_out <= (others => 'U');
        else
            data_out <= ROM(to_integer(unsigned(addr_in)));
        end if;
    end process;

end Behavioral;