
-- Library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Define entity
entity CRCtransmitter is
	port	(
				input_data		:in		std_logic_vector (7 downto 0);	-- data A
                crc_out		: out  STD_LOGIC_VECTOR(31 downto 0); -- data B
                data_valid  :in     std_logic;
				clk	:		in		std_logic-- sinyal Clockian
			);
end CRCtransmitter;

-- Define architecture
architecture rtl of CRCtransmitter is
    signal Sel_PIPO, is_corrupt_temp, is_4, is_end, chunk_ctrl, feedback_ctrl, sel_out_xor, en_regis, reset: STD_LOGIC;
    signal  data_after_mux_PIPO, output_data, out_LUT1, out_LUT2, out_LUT3, out_LUT4, output_LUT, SIPO_out, data_after_regis32bit, data_after_XOR, data_after_muxC, data_after_muxB, data_after_LUT_prev, data_after_muxA, data_after_PIPO: STD_LOGIC_VECTOR(31 downto 0);
    signal hasil_comparator_4: STD_LOGIC_VECTOR(3 downto 0);
    signal first_byte, second_byte, third_byte, fourth_byte: STD_LOGIC_VECTOR(7 downto 0);
    signal padded_counter : std_logic_vector(31 downto 0);
signal padded_input   : std_logic_vector(31 downto 0);

component mux2to1_32bit 
	port	(
				A		:		in		std_logic_vector (31 downto 0);	-- data A
				B		:		in		std_logic_vector (31 downto 0);	-- data B
				Sel	    :		in		std_logic;								-- selector
				Data	:		out	std_logic_vector (31 downto 0)		-- luaran data
			);
end component;

component mux2to1_8bit is
	port	(
				A		:		in		std_logic_vector (7 downto 0);	-- data A
				B		:		in		std_logic_vector (7 downto 0);	-- data B
				Sel	:		in		std_logic;								-- selector
				Data	:		out	std_logic_vector (7 downto 0)		-- luaran data
			);
end component;

component register32bitPIPO 
	port	(
			    A		:		in		std_logic_vector (31 downto 0);	-- data A
				En		:		in		std_logic;								-- sinyal Enable
				Res	    :		in		std_logic;								-- sinyal Reset
				Clk	    :		in		std_logic;								-- sinyal Clock
				Data	:		out	std_logic_vector (31 downto 0)		-- luaran data
			);
end component;

component Register32BitSIPO 
	port	(
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- Interface ke UART (Input)
        uart_data   : in  STD_LOGIC_VECTOR (7 downto 0); -- Data 8-bit masuk
        uart_valid  : in  STD_LOGIC;                     -- Sinyal valid dari UART
        
        -- Interface ke CRC Engine (Output)
        chunk_data  : out STD_LOGIC_VECTOR (31 downto 0) -- Data 32-bit keluar      	-- luaran data
			);
end component;

component comparator 
	port	(
            inp_A,inp_B   : in std_logic_vector(31 downto 0);
	        equal : out std_logic
    );
end component;

component counter4bit 
	port	(
				En		:		in		std_logic;							-- sinyal enable
				Res		:		in		std_logic;							-- sinyal reset
				Clk		:		in		std_logic;							-- sinyal clock
				Count	:		out	std_logic_vector (3 downto 0)	-- hasil penghitungan
			);
end component;

component CRC_Controller
  Port ( 
        -- INPUT (Dari Luar / Datapath)
        clk             : in  STD_LOGIC;
        is_4      : in  STD_LOGIC; -- Sinyal dari SIPO (Chunk Ready)
        is_end   : in  STD_LOGIC; -- Sinyal deteksi akhir (misal tombol/timeout)

        -- OUTPUT (Ke Datapath)
        chunk_ctrl      : out STD_LOGIC; -- MUX Kiri
        feedback_ctrl   : out STD_LOGIC; -- MUX Kanan
        sel_out_xor     : out STD_LOGIC; -- MUX Atas Register
        en_regis        : out STD_LOGIC; -- Clock Enable Register -- Clock Enable Register
        Reset        : out STD_LOGIC; -- Clock Enable Register
        Sel_PIPO        : out STD_LOGIC -- Clock Enable Register
    );
end component;

component LUT_1
    Port ( addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component LUT_2
Port ( addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component LUT_3
Port ( addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component LUT_4
Port ( addr_in : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (31 downto 0));
end component;

component LUT_Prev
 Port ( 
        prev_crc_in : in  STD_LOGIC_VECTOR (31 downto 0); -- From Register
        lut_prev_out : out  STD_LOGIC_VECTOR (31 downto 0) -- To Feedback Mux/XOR
    );
end component;

begin

SIPO_atas: Register32BitSIPO
 port map(
    clk => clk,
    reset => '0',
    uart_data => input_data,
    uart_valid => data_valid,
    chunk_data => SIPO_out
);


data_after_XOR <= data_after_muxA xor data_after_muxB;

-- Correct padding: 28 zeros + 4 bit counter = 32 bits
padded_counter <= "0000000000000000000000000000" & hasil_comparator_4; 

-- Correct padding for input data check (checking against 32-bit comparator)
padded_input   <= "000000000000000000000000" & input_data;

CTRL: CRC_Controller
 port map(
    clk => clk,
    is_4 => is_4,
    is_end => is_end,
    chunk_ctrl => chunk_ctrl,
    feedback_ctrl => feedback_ctrl,
    sel_out_xor => sel_out_xor,
    en_regis => en_regis,
    Reset => Reset,
    Sel_PIPO => Sel_PIPO
);

first_byte <= SIPO_out(31 downto 24);
second_byte <= SIPO_out(23 downto 16);
third_byte <= SIPO_out(15 downto 8);
fourth_byte <= SIPO_out(7 downto 0);


LUT_1_inst: LUT_1
 port map(
    addr_in => first_byte,
    data_out => out_LUT1
);

LUT_2_inst: LUT_2
 port map(
    addr_in => second_byte,
    data_out => out_LUT2
);

LUT_3_inst: LUT_3
 port map(
    addr_in => third_byte,
    data_out => out_LUT3
);

LUT_4_inst: LUT_4
 port map(
    addr_in => fourth_byte,
    data_out => out_LUT4
);

LUT_Prev_inst: LUT_Prev
 port map(
    prev_crc_in => data_after_regis32bit,
    lut_prev_out => data_after_LUT_prev
);

output_LUT <= out_LUT1 xor out_LUT2 xor out_LUT3 xor out_LUT4;

MUX_PIPO: mux2to1_32bit
 port map(
    A => output_LUT,
    B => data_after_PIPO,
    Sel => Sel_PIPO,
    Data => data_after_mux_PIPO
);

REGIS_PIPO_atas: register32bitPIPO
 port map(
    A => data_after_mux_PIPO,
    En => '1',
    Res => '0',
    Clk => Clk,
    Data => data_after_PIPO
);

MUX_A: mux2to1_32bit
 port map(
    A => "00000000000000000000000000000000",
    B => data_after_PIPO,
    Sel => chunk_ctrl,
    Data => data_after_muxA
);

MUX_B: mux2to1_32bit
 port map(
    A => "00000000000000000000000000000000",
    B => data_after_LUT_prev,
    Sel => feedback_ctrl,
    Data => data_after_muxB
);

MUX_C: mux2to1_32bit
 port map(
    A => data_after_XOR,
    B => data_after_regis32bit,
    Sel => sel_out_xor,
    Data => data_after_muxC
);

output_data <= data_after_regis32bit;
crc_out <= output_data;

REGIS_PIPO_bawah: register32bitPIPO
 port map(
    A => data_after_muxC,
    En => en_regis,
    Res => '0',
    Clk => Clk,
    Data => data_after_regis32bit
);

counter: counter4bit 
	port map(
		En	=> data_valid,
		Res	=> reset,
		Clk	=> Clk,
		Count => hasil_comparator_4
	);

comparator_4: comparator
    port map(
        inp_A => padded_counter, -- Clean signal
        inp_B => "00000000000000000000000000000100",    -- Hex is cleaner than "000..100"
        equal => is_4
    );

comparator_end: comparator
    port map(
        inp_A => padded_input,   -- Clean signal
        inp_B => x"0000000D",    -- 13 is 'Enter'
        equal => is_end
    );


    end rtl;
	