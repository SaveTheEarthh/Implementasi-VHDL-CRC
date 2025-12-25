library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CRCtransmitter is
    port (
        reset : in std_logic;
        input_data  : in  std_logic_vector (7 downto 0);
        crc_out     : out std_logic_vector (31 downto 0);
        data_valid  : in  std_logic;
        clk         : in  std_logic
    );
end CRCtransmitter;

architecture rtl of CRCtransmitter is
    -- Signals
    signal Sel_PIPO, is_corrupt_temp, is_4, is_end, chunk_ctrl, feedback_ctrl, sel_out_xor, en_regis: STD_LOGIC;
    signal fsm_counter_reset : STD_LOGIC;
    signal combined_counter_reset : STD_LOGIC; -- NEW SIGNAL
    signal data_after_mux_PIPO, output_data, out_LUT1, out_LUT2, out_LUT3, out_LUT4, output_LUT, SIPO_out, data_after_regis32bit, data_after_XOR, data_after_muxC, data_after_muxB, data_after_LUT_prev, data_after_muxA: STD_LOGIC_VECTOR(31 downto 0);
    signal hasil_comparator_4: STD_LOGIC_VECTOR(3 downto 0);
    signal first_byte, second_byte, third_byte, fourth_byte: STD_LOGIC_VECTOR(7 downto 0);
    signal padded_counter, padded_input : std_logic_vector(31 downto 0);

    -- Component Declarations (Keep your existing component declarations)
    component mux2to1_32bit is
        port (A, B: in std_logic_vector(31 downto 0); Sel: in std_logic; Data: out std_logic_vector(31 downto 0));
    end component;
    
    component register32bitPIPO is
        port (A: in std_logic_vector(31 downto 0); En, Res, Clk: in std_logic; Data: out std_logic_vector(31 downto 0));
    end component;
    
    component Register32BitSIPO is
        port (clk, reset: in std_logic; uart_data: in std_logic_vector(7 downto 0); uart_valid: in std_logic; chunk_data: out std_logic_vector(31 downto 0));
    end component;
    
    component comparator is
        port (inp_A, inp_B: in std_logic_vector(31 downto 0); equal: out std_logic);
    end component;
    
    component counter4bit is
        port (En, Res, Clk: in std_logic; Count: out std_logic_vector(3 downto 0));
    end component;
    
    -- Ensure you are using the FIXED FSM_Pengontrol logic here
    component FSM_Pengontrol is
        Port (clk, is_4, is_end: in STD_LOGIC; chunk_ctrl, feedback_ctrl, sel_out_xor, en_regis, Reset, Sel_PIPO: out STD_LOGIC);
    end component;
    
    component LUT_1 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_2 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_3 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_4 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    
    component LUT_Prev is
        Port (prev_crc_in: in STD_LOGIC_VECTOR(31 downto 0); lut_prev_out: out STD_LOGIC_VECTOR(31 downto 0));
    end component;

begin

    combined_counter_reset <= fsm_counter_reset OR reset;
    -- SIPO Instantiation
    SIPO_atas: Register32BitSIPO
    port map(
        clk => clk,
        reset => '0', -- FIXED: Hardcoded to 0 to prevent FSM from wiping data
        uart_data => input_data,
        uart_valid => data_valid,
        chunk_data => SIPO_out
    );

    -- Comparator Logic
    padded_counter <= x"0000000" & hasil_comparator_4;
    padded_input   <= x"000000" & input_data;

    -- Controller
    CTRL: FSM_Pengontrol
    port map(
        clk => clk, is_4 => is_4, is_end => is_end,
        chunk_ctrl => chunk_ctrl, feedback_ctrl => feedback_ctrl,
        sel_out_xor => sel_out_xor, en_regis => en_regis,
        Reset => fsm_counter_reset, Sel_PIPO => Sel_PIPO
    );

    -- Byte Splitting & LUTs
    first_byte  <= SIPO_out(31 downto 24);
    second_byte <= SIPO_out(23 downto 16);
    third_byte  <= SIPO_out(15 downto 8);
    fourth_byte <= SIPO_out(7 downto 0);

    LUT_1_inst: LUT_1 port map(addr_in => first_byte, data_out => out_LUT1);
    LUT_2_inst: LUT_2 port map(addr_in => second_byte, data_out => out_LUT2);
    LUT_3_inst: LUT_3 port map(addr_in => third_byte, data_out => out_LUT3);
    LUT_4_inst: LUT_4 port map(addr_in => fourth_byte, data_out => out_LUT4);
    
    output_LUT <= out_LUT1 xor out_LUT2 xor out_LUT3 xor out_LUT4;

    -- Feedback LUT
    LUT_Prev_inst: LUT_Prev
    port map(prev_crc_in => data_after_regis32bit, lut_prev_out => data_after_LUT_prev);

    -- MUX A (DATA PATH) - FIXED: BYPASS REGISTER
    MUX_A: mux2to1_32bit
    port map(
        A => x"00000000",
        B => output_LUT, -- FIXED: Connected directly to LUT output
        Sel => chunk_ctrl,
        Data => data_after_muxA
    );

    -- MUX B (FEEDBACK PATH)
    MUX_B: mux2to1_32bit
    port map(
        A => x"00000000",
        B => data_after_LUT_prev,
        Sel => feedback_ctrl,
        Data => data_after_muxB
    );

    data_after_XOR <= data_after_muxA xor data_after_muxB;

    -- MUX C (HOLD LOGIC)
    MUX_C: mux2to1_32bit
    port map(
        A => data_after_XOR,
        B => data_after_regis32bit,
        Sel => sel_out_xor,
        Data => data_after_muxC
    );

    -- ACCUMULATION REGISTER
    REGIS_PIPO_bawah: register32bitPIPO
    port map(
        A => data_after_muxC,
        En => en_regis,
        Res => reset, -- FIXED: Hardcoded to 0
        Clk => Clk,
        Data => data_after_regis32bit
    );

    -- Output Assignment
    output_data <= data_after_regis32bit;
    crc_out <= output_data;

    -- Counter
    counter: counter4bit 
    port map(En => data_valid, Res => combined_counter_reset, Clk => Clk, Count => hasil_comparator_4);

    -- Comparators
    comparator_4: comparator port map(inp_A => padded_counter, inp_B => x"00000004", equal => is_4);
    comparator_end: comparator port map(inp_A => padded_input, inp_B => x"0000000D", equal => is_end);

end rtl;