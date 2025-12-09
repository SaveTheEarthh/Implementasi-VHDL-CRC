library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package CRC32_Pkg is
    -- Standard Ethernet CRC-32 Polynomial: 0x04C11DB7
    constant POLY : std_logic_vector(31 downto 0) := x"04C11DB7";

    -- Function to calculate the CRC remainder of a byte at a specific shift position
    -- Mathematically: (Byte * x^(32 + shift_amount)) mod Poly
    function calc_lut_entry(val : integer; shift_amount : integer) return std_logic_vector;
    
    -- Array type for the ROM
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);
end package CRC32_Pkg;

package body CRC32_Pkg is
    function calc_lut_entry(val : integer; shift_amount : integer) return std_logic_vector is
        variable crc : std_logic_vector(31 downto 0) := (others => '0');
        variable top_bit : std_logic;
        variable input_byte : std_logic_vector(7 downto 0);
    begin
        input_byte := std_logic_vector(to_unsigned(val, 8));
        
        -- 1. Position the byte in the register based on the shift amount
        if shift_amount = 24 then
            crc(31 downto 24) := input_byte;
        elsif shift_amount = 16 then
            crc(23 downto 16) := input_byte;
        elsif shift_amount = 8 then
            crc(15 downto 8)  := input_byte;
        elsif shift_amount = 0 then
            crc(7 downto 0)   := input_byte;
        end if;
        
        -- 2. Simulate the CRC LFSR for 32 clock cycles (multiplying by x^32)
        for i in 1 to 32 loop
            top_bit := crc(31);
            crc := crc(30 downto 0) & '0'; -- Shift Left
            if top_bit = '1' then
                crc := crc xor POLY;
            end if;
        end loop;
        
        return crc;
    end function;
end package body CRC32_Pkg;