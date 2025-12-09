library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LUT_Prev is
    Port ( 
        prev_crc_in : in  STD_LOGIC_VECTOR (31 downto 0); -- From Register
        lut_prev_out : out  STD_LOGIC_VECTOR (31 downto 0) -- To Feedback Mux/XOR
    );
end LUT_Prev;

architecture Behavioral of LUT_Prev is
    -- Signals to hold outputs of the sub-LUTs
    signal out1, out2, out3, out4 : STD_LOGIC_VECTOR(31 downto 0);
    
    component LUT_1 is Port ( addr_in : in STD_LOGIC_VECTOR(7 downto 0); data_out : out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_2 is Port ( addr_in : in STD_LOGIC_VECTOR(7 downto 0); data_out : out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_3 is Port ( addr_in : in STD_LOGIC_VECTOR(7 downto 0); data_out : out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_4 is Port ( addr_in : in STD_LOGIC_VECTOR(7 downto 0); data_out : out STD_LOGIC_VECTOR(31 downto 0)); end component;

begin
    -- 1. Byte 3 (MSB): Bits 31-24
    LUT_Instance_1: LUT_1 port map (
        addr_in => prev_crc_in(31 downto 24),
        data_out => out1
    );
    
    -- 2. Byte 2: Bits 23-16
    LUT_Instance_2: LUT_2 port map (
        addr_in => prev_crc_in(23 downto 16),
        data_out => out2
    );
    
    -- 3. Byte 1: Bits 15-8
    LUT_Instance_3: LUT_3 port map (
        addr_in => prev_crc_in(15 downto 8),
        data_out => out3
    );
    
    -- 4. Byte 0 (LSB): Bits 7-0
    LUT_Instance_4: LUT_4 port map (
        addr_in => prev_crc_in(7 downto 0),
        data_out => out4
    );
    
    -- 5. Combine results
    lut_prev_out <= out1 XOR out2 XOR out3 XOR out4;

end Behavioral;