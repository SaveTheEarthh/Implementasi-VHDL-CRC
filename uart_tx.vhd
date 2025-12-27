library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port (
        i_CLOCK     : in  std_logic;
        i_START     : in  std_logic;
        i_DATA      : in  std_logic_vector(7 downto 0);
        o_TX_LINE   : out std_logic := '1';
        o_BUSY      : out std_logic
    );
end uart_tx;

architecture behavior of uart_tx is
    signal r_PRESCALER          : integer range 0 to 5208 := 0;
    signal r_INDEX              : integer range 0 to 9 := 0;
    signal r_DATA_BUFFER        : std_logic_vector(9 downto 0) := (others => '1');
    signal s_TRANSMITTING_FLAG  : std_logic := '0';
begin
    process(i_CLOCK)
    begin
        if rising_edge(i_CLOCK) then
            if s_TRANSMITTING_FLAG = '0' and i_START = '1' then
                r_DATA_BUFFER(0) <= '0'; r_DATA_BUFFER(9) <= '1';
                r_DATA_BUFFER(8 downto 1) <= i_DATA;
                s_TRANSMITTING_FLAG <= '1'; o_BUSY <= '1';
                r_PRESCALER <= 0; r_INDEX <= 0;
            end if;

            if s_TRANSMITTING_FLAG = '1' then
                if r_PRESCALER < 5207 then
                    r_PRESCALER <= r_PRESCALER + 1;
                else
                    r_PRESCALER <= 0;
                end if;

                if r_PRESCALER = 0 then o_TX_LINE <= r_DATA_BUFFER(r_INDEX); end if;

                if r_PRESCALER = 5207 then
                    if r_INDEX < 9 then
                        r_INDEX <= r_INDEX + 1;
                    else
                        s_TRANSMITTING_FLAG <= '0'; o_BUSY <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
end behavior;