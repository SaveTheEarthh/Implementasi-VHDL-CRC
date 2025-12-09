library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CRC32_Pkg.ALL;

entity LUT_2 is
    Port ( addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0));
end LUT_2;

architecture Behavioral of LUT_2 is
    function init_rom return rom_type is
        variable temp_rom : rom_type;
    begin
        for i in 0 to 255 loop
            temp_rom(i) := calc_lut_entry(i, 16); -- Shift 16
        end loop;
        return temp_rom;
    end function;
    constant ROM : rom_type := init_rom;
begin
    data_out <= ROM(to_integer(unsigned(addr_in)));
end Behavioral;