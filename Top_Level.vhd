
-- Pembuat
-- Nama 	: Timothy Yves Halim dan Akursio Kidung Gamel B.P
-- NIM		: 132240024 dan 13224051
-- Rombongan : Selasa-1
-- kelompok : 2
-- percobaan: 3
-- Tanggal: 4 November 2024
-----------------------------------------------------------------------------
-- Deskripsi
-- Menghitung Modulo dari Pembagian A/B. Akan mengeluarkan output C (Hasil sisa/modulo) dan D jumlah Iterasi
-- input:
--			A		data 4 bit
--			B		data 4 bit.
--			Start input 1 bit, menandakan sistem berjalan
--			Stop input 1 bit, menandakan sistem berhenti
--			Clk input untuk clock
-- output :
--			C dan D output 4 bit. C adalah hasil modulo dan D merupakan jumlah iterasi

-- Library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Define entity
entity CRCtransmitter is
	port	(
				input		:in		std_logic_vector (31 downto 0);	-- data A
                output		:in		std_logic_vector (31 downto 0); -- data B
                data_valid  :in     std_logic;
				Clk	:		in		std_logic-- sinyal Clockian
			);
end CRCtransmitter;

-- Define architecture
architecture rtl of CRCtransmitter is
    signal Sel, is_4, is_end, chunk_ctrl, feedback_ctrl, sel_out_xor, en_regis, Output_ctrl, reset, Z_fromBus: STD_LOGIC;
    signal data_after_regis32bit, data_after_demux, data_after_XOR, data_after_muxC, data_after_muxB, data_after_LUT_prev, data_after_muxA, data_after_PIPO, A, B, Data: STD_LOGIC_VECTOR(31 downto 1);
    signal hasil_comparator_4: STD_LOGIC_VECTOR(3 downto 0);

component mux2to1_32bit 
	port	(
				A		:		in		std_logic_vector (31 downto 0);	-- data A
				B		:		in		std_logic_vector (31 downto 0);	-- data B
				Sel	    :		in		std_logic;								-- selector
				Data	:		out	std_logic_vector (3 downto 0)		-- luaran data
			);
end component;

component demux_1to2 
	port	(
				F : in std_logic_vector(31 downto 0);
                S: in STD_LOGIC;
                A,B: out std_logic_vector(31 downto 0)
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

component SIPO_32bit 
	port	(
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        
        -- Interface ke UART (Input)
        uart_data   : in  STD_LOGIC_VECTOR (7 downto 0); -- Data 8-bit masuk
        uart_valid  : in  STD_LOGIC;                     -- Sinyal valid dari UART
        
        -- Interface ke CRC Engine (Output)
        chunk_data  : out STD_LOGIC_VECTOR (31 downto 0); -- Data 32-bit keluar
        chunk_ready : out STD_LOGIC        	-- luaran data
			);
end component;

component comparator 
	port	(
            inp_A,inp_B   : in std_logic_vector(3 downto 0);
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
        en_regis        : out STD_LOGIC; -- Clock Enable Register
        Output_ctrl        : out STD_LOGIC; -- Clock Enable Register
        Reset        : out STD_LOGIC; -- Clock Enable Register
        Z_fromBus        : out STD_LOGIC -- Clock Enable Register
    );
end component;

begin

data_after_XOR <= data_after_muxA xor data_after_muxB;

CTRL: CRC_Controller
 port map(
    clk => clk,
    is_4 => is_4,
    is_end => is_end,
    chunk_ctrl => chunk_ctrl,
    feedback_ctrl => feedback_ctrl,
    sel_out_xor => sel_out_xor,
    en_regis => en_regis,
    Output_ctrl => Output_ctrl,
    Reset => Reset,
    Z_fromBus => Z_fromBus
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
    B => data_after_demux,
    Sel => sel_out_xor,
    Data => data_after_muxC
);

DEMUX: demux_1to2
 port map(
    F => data_after_regis32bit,
    S => Output_ctrl,
    A => output,
    B => data_after_demux
);

REGIS_PIPO_atas: register32bitPIPO
 port map(
    A => output_LUT,
    En => '1',
    Res => '0',
    Clk => Clk,
    Data => data_after_PIPO
);

REGIS_PIPO_bawah: register32bitPIPO
 port map(
    A => data_after_muxC,
    En => en_regis,
    Res => '0',
    Clk => Clk,
    Data => data_after_regis32bit
);

REGIS_SIPO: SIPO_32bit
 port map(
    clk => clk,
    reset => '0',
    uart_data => input,
    uart_valid => data_valid,
    chunk_data => SIPO_out,
    chunk_ready => Z_fromBus
);
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
    inp_A => hasil_comparator_4,
    inp_B => "100",
    equal => is_4
);

comparator_end: comparator
 port map(
    inp_A => input,
    inp_B => "00001101",
    equal => is_end
);


    end rtl;
	