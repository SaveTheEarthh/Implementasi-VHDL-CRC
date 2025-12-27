library ieee;
use ieee.std_logic_1164.all;

entity uart is
    port (
        i_CLOCK     : in  std_logic;
        i_RX        : in  std_logic;
        o_DATA      : out std_logic_vector(7 downto 0);
        o_VALID     : out std_logic;       -- NEW PORT
        i_DATA      : in  std_logic_vector(7 downto 0);
        i_SEND      : in  std_logic;
        o_TX        : out std_logic;
        o_TX_BUSY   : out std_logic
    );
end uart;

architecture structural of uart is
    component uart_rx is
        port (i_CLOCK : in std_logic; i_RX : in std_logic; o_DATA : out std_logic_vector(7 downto 0); o_VALID : out std_logic; o_BUSY : out std_logic);
    end component;
    component uart_tx is
        port (i_CLOCK : in std_logic; i_START : in std_logic; i_DATA : in std_logic_vector(7 downto 0); o_TX_LINE : out std_logic; o_BUSY : out std_logic);
    end component;
begin
    u_RX : uart_rx port map (i_CLOCK => i_CLOCK, i_RX => i_RX, o_DATA => o_DATA, o_VALID => o_VALID, o_BUSY => open);
    u_TX : uart_tx port map (i_CLOCK => i_CLOCK, i_START => i_SEND, i_DATA => i_DATA, o_TX_LINE => o_TX, o_BUSY => o_TX_BUSY);
end structural;