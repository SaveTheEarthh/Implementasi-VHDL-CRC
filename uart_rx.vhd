library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port (
        i_CLOCK     : in  std_logic;
        i_RX        : in  std_logic;
        o_DATA      : out std_logic_vector(7 downto 0);
        o_VALID     : out std_logic; -- PULSE when new byte arrives
        o_BUSY      : out std_logic
    );
end uart_rx;

architecture behavior of uart_rx is
    signal r_PRESCALER      : integer range 0 to 5208 := 0; 
    signal r_INDEX          : integer range 0 to 9 := 0;
    signal r_DATA_BUFFER    : std_logic_vector(9 downto 0) := (others => '0');
    signal s_RECIEVING_FLAG : std_logic := '0';
begin
    process(i_CLOCK)
    begin
        if rising_edge(i_CLOCK) then
            o_VALID <= '0'; -- Default low

            if s_RECIEVING_FLAG = '0' and i_RX = '0' then -- Start Bit
                r_INDEX <= 0;
                r_PRESCALER <= 0;
                s_RECIEVING_FLAG <= '1';
                o_BUSY <= '1';
            end if;

            if s_RECIEVING_FLAG = '1' then
                r_DATA_BUFFER(r_INDEX) <= i_RX;
                
                if r_PRESCALER < 5207 then
                    r_PRESCALER <= r_PRESCALER + 1;
                else
                    r_PRESCALER <= 0;
                end if;

                if r_PRESCALER = 2500 then -- Sample Middle
                    if r_INDEX < 9 then
                        r_INDEX <= r_INDEX + 1;
                    else
                        s_RECIEVING_FLAG <= '0';
                        o_BUSY <= '0';
                        -- Check Framing (Start=0, Stop=1)
                        if r_DATA_BUFFER(0) = '0' and r_DATA_BUFFER(9) = '1' then
                            o_DATA  <= r_DATA_BUFFER(8 downto 1);
                            o_VALID <= '1'; -- HERE IS THE PULSE
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
end behavior;