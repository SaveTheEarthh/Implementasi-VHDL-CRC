library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_CRCreceiver is
end tb_CRCreceiver;

architecture behavior of tb_CRCreceiver is 

    -- Component Declaration
    component CRCreceiver
    port(
         input_data : in  std_logic_vector(7 downto 0);
         is_corrupt : out std_logic;
         data_valid : in  std_logic;
         clk        : in  std_logic
        );
    end component;

    -- Signals
    signal clk        : std_logic := '0';
    signal input_data : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid : std_logic := '0';
    signal is_corrupt : std_logic;

    -- Clock period definitions
    constant clk_period : time := 20 ns; -- 50 MHz

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: CRCreceiver port map (
          input_data => input_data,
          is_corrupt => is_corrupt,
          data_valid => data_valid,
          clk        => clk
        );

    -- Clock process
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stim_proc: process
        procedure send_byte(data : in std_logic_vector(7 downto 0)) is
        begin
            input_data <= data;
            data_valid <= '1';
            wait for clk_period;
            data_valid <= '0';
            wait for clk_period * 2; -- Gap between bytes
        end procedure;

    begin		
        -- Reset system
        wait for 100 ns;

        -- Send First 4 Bytes (0x01234567)
        send_byte(x"01"); send_byte(x"23");
        send_byte(x"45"); send_byte(x"67");

        -- Wait for FSM to process S_FIRST_CHUNK
        wait for clk_period * 5;

        -- Send Next 4 Bytes (0x89ABCDEF)
        send_byte(x"89"); send_byte(x"AB");
        send_byte(x"CD"); send_byte(x"EF");

        -- Wait for FSM to process S_NEXT_CHUNK
        wait for clk_period * 5;

        -- Send 'Enter' (0x0D) to trigger is_end
        send_byte(x"0D"); 

        wait for 200 ns;
        assert false report "Simulation Finished" severity failure;
    end process;

end architecture;