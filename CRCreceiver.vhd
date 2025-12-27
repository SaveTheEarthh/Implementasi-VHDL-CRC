library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CRCreceiver is
	port	(
				input_data		:in		std_logic_vector (7 downto 0);
                is_corrupt		: out  std_logic;
                data_valid      :in     std_logic;
                reset           : in    std_logic;
				clk	            :		in		std_logic;
                rx_debug_data   : out std_logic_vector(31 downto 0);
                compute_final   : in std_logic 
			);
end CRCreceiver;

architecture rtl of CRCreceiver is
    signal Sel_PIPO, is_corrupt_temp, is_ready, is_4, en_regis, data_good, is_end, chunk_ctrl, feedback_ctrl, sel_out_xor: STD_LOGIC;
    signal fsm_counter_reset, combined_counter_reset : STD_LOGIC;
    
    signal output_data, out_LUT1, out_LUT2, out_LUT3, out_LUT4 : STD_LOGIC_VECTOR(31 downto 0);
    signal output_LUT, SIPO_out, data_after_regis32bit, data_after_XOR, data_after_LUT_prev: STD_LOGIC_VECTOR(31 downto 0);
    signal data_after_muxA, data_after_muxB, data_after_muxC: STD_LOGIC_VECTOR(31 downto 0);
    signal data_final_partial : STD_LOGIC_VECTOR(31 downto 0);
    
    signal hasil_comparator_4 : STD_LOGIC_VECTOR(3 downto 0);
    signal padded_counter, SIPO_padded : std_logic_vector(31 downto 0);
    signal first_byte, second_byte, third_byte, fourth_byte: STD_LOGIC_VECTOR(7 downto 0);

    signal combined_enable, auto_reset : std_logic := '0';
    signal is_corrupt_latched : std_logic := '0';

    -- Components
    component register32bitPIPO port ( A : in std_logic_vector (31 downto 0); En : in std_logic; Res : in std_logic; Clk : in std_logic; Data : out std_logic_vector (31 downto 0)); end component;
    component Register32BitSIPO port ( clk : in STD_LOGIC; reset : in STD_LOGIC; uart_data : in STD_LOGIC_VECTOR (7 downto 0); uart_valid : in STD_LOGIC; chunk_data : out STD_LOGIC_VECTOR (31 downto 0)); end component;
    component comparator port ( inp_A,inp_B : in std_logic_vector(31 downto 0); equal : out std_logic); end component;
    component counter4bit port (En, Res, Clk: in std_logic; Count: out std_logic_vector(3 downto 0)); end component;
    component FSM_Pengontrol Port (clk, is_4, is_end: in STD_LOGIC; chunk_ctrl, feedback_ctrl, sel_out_xor, en_regis, Reset, Sel_PIPO: out STD_LOGIC); end component;
    component LUT_Prev Port ( prev_crc_in : in STD_LOGIC_VECTOR (31 downto 0); lut_prev_out : out STD_LOGIC_VECTOR (31 downto 0)); end component;
    component mux2to1_32bit port (A, B: in std_logic_vector(31 downto 0); Sel: in std_logic; Data: out std_logic_vector(31 downto 0)); end component;
    component LUT_1 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_2 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_3 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;
    component LUT_4 is Port (addr_in: in STD_LOGIC_VECTOR(7 downto 0); data_out: out STD_LOGIC_VECTOR(31 downto 0)); end component;

    function calc_crc_8bit (cur_crc : std_logic_vector(31 downto 0); data_byte : std_logic_vector(7 downto 0)) return std_logic_vector is
        variable crc : std_logic_vector(31 downto 0);
        variable poly : std_logic_vector(31 downto 0) := x"04C11DB7";
    begin
        crc := cur_crc;
        crc(31 downto 24) := crc(31 downto 24) xor data_byte;
        for i in 0 to 7 loop
            if crc(31) = '1' then crc := (crc(30 downto 0) & '0') xor poly; else crc := (crc(30 downto 0) & '0'); end if;
        end loop;
        return crc;
    end function;

begin

    combined_counter_reset <= fsm_counter_reset or reset or auto_reset;

    SIPO_atas: Register32BitSIPO port map( clk => clk, reset => '0', uart_data => input_data, uart_valid => data_valid, chunk_data => SIPO_out );

    CTRL: FSM_Pengontrol port map( clk => clk, is_4 => is_4, is_end => '0', chunk_ctrl => chunk_ctrl, feedback_ctrl => feedback_ctrl, sel_out_xor => sel_out_xor, en_regis => en_regis, Reset => fsm_counter_reset, Sel_PIPO => Sel_PIPO );
    
    process(data_after_regis32bit, SIPO_out, hasil_comparator_4)
        variable temp_crc : std_logic_vector(31 downto 0);
        variable count : integer;
    begin
        temp_crc := data_after_regis32bit;
        count := to_integer(unsigned(hasil_comparator_4));
        if count >= 3 then temp_crc := calc_crc_8bit(temp_crc, SIPO_out(23 downto 16)); end if;
        if count >= 2 then temp_crc := calc_crc_8bit(temp_crc, SIPO_out(15 downto 8)); end if;
        if count >= 1 then temp_crc := calc_crc_8bit(temp_crc, SIPO_out(7 downto 0)); end if;
        data_final_partial <= temp_crc;
    end process;

    first_byte  <= SIPO_out(31 downto 24); second_byte <= SIPO_out(23 downto 16); third_byte  <= SIPO_out(15 downto 8); fourth_byte <= SIPO_out(7 downto 0);
    LUT_1_inst: LUT_1 port map(addr_in => first_byte, data_out => out_LUT1);
    LUT_2_inst: LUT_2 port map(addr_in => second_byte, data_out => out_LUT2);
    LUT_3_inst: LUT_3 port map(addr_in => third_byte, data_out => out_LUT3);
    LUT_4_inst: LUT_4 port map(addr_in => fourth_byte, data_out => out_LUT4);
    output_LUT <= out_LUT1 xor out_LUT2 xor out_LUT3 xor out_LUT4;
    LUT_Prev_inst: LUT_Prev port map( prev_crc_in => data_after_regis32bit, lut_prev_out => data_after_LUT_prev);
    MUX_A: mux2to1_32bit port map( A => x"00000000", B => output_LUT, Sel => '1', Data => data_after_muxA );
    MUX_B: mux2to1_32bit port map( A => x"00000000", B => data_after_LUT_prev, Sel => '1', Data => data_after_muxB );
    data_after_XOR <= data_after_muxA xor data_after_muxB;

    process(compute_final, auto_reset, data_after_XOR, data_final_partial)
    begin
        if auto_reset = '1' then
            data_after_muxC <= (others => '0'); 
        elsif compute_final = '1' then 
            data_after_muxC <= data_final_partial; 
        else 
            data_after_muxC <= data_after_XOR; 
        end if;
    end process;

    combined_enable <= en_regis or compute_final or auto_reset;

    REGIS_PIPO_bawah: register32bitPIPO
     port map(
        A => data_after_muxC,
        En => combined_enable, 
        Res => reset,
        Clk => Clk,
        Data => data_after_regis32bit
    );
    
    -- [UPDATED] Live Output Logic for Receiver
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                is_corrupt_latched <= '0';
                auto_reset <= '0';
            else
                -- 1. Auto Reset
                if compute_final = '1' then
                    auto_reset <= '1';
                else
                    auto_reset <= '0';
                end if;

                -- 2. Live Latching
                if compute_final = '1' then
                    if data_final_partial = x"00000000" then is_corrupt_latched <= '0'; else is_corrupt_latched <= '1'; end if;
                elsif combined_enable = '1' and auto_reset = '0' then
                    -- Live Check on intermediate data
                    if data_after_muxC = x"00000000" then is_corrupt_latched <= '0'; else is_corrupt_latched <= '1'; end if;
                end if;
            end if;
        end if;
    end process;

    rx_debug_data <= data_after_regis32bit;
    counter: counter4bit port map( En => data_valid, Res => combined_counter_reset, Clk => Clk, Count => hasil_comparator_4 );
    padded_counter <= x"0000000" & hasil_comparator_4;
    comparator_4: comparator port map(inp_A => padded_counter, inp_B => x"00000004", equal => is_4);
    comparator_zero: comparator port map(inp_A => data_after_regis32bit, inp_B => x"00000000", equal => data_good);

    is_corrupt <= is_corrupt_latched;

end rtl;