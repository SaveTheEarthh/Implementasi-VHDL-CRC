library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity I2C_LCD_Driver is
    Port (
        clk        : in    STD_LOGIC;
        reset_n    : in    STD_LOGIC;
        is_rx_mode : in    STD_LOGIC;
        -- KEMBALI KE INOUT (Standar I2C yang benar)
        sda        : inout STD_LOGIC; 
        scl        : inout STD_LOGIC
    );
end I2C_LCD_Driver;

architecture Behavioral of I2C_LCD_Driver is
    -- ALAMAT PASTI PCF8574T = 0x27
    constant I2C_ADDR : std_logic_vector(6 downto 0) := "0100111"; 
    
    constant DIV_VAL : integer := 250; 
    signal clk_div   : integer range 0 to DIV_VAL := 0;
    signal i2c_tick  : std_logic := '0';
    
    -- BLINK setiap 1 detik
    signal blink_timer : integer range 0 to 50000000 := 0;
    signal led_state   : std_logic := '0'; -- Mulai dari Mati

    type state_t is (IDLE, START, ADDR, ACK1, DATA, ACK2, STOP);
    signal state : state_t := IDLE;
    
    signal bit_cnt : integer range -2 to 7 := 7;
    signal tx_byte : std_logic_vector(7 downto 0);
    
    -- Buffer Internal
    signal sda_int : std_logic := '1';
    signal scl_int : std_logic := '1';

begin
    -- OPEN DRAIN LOGIC (Standard I2C)
    -- Jika '0', tarik ke GND. Jika '1', lepas (High-Z) biar resistor yang narik.
    sda <= '0' when sda_int = '0' else 'Z';
    scl <= '0' when scl_int = '0' else 'Z';

    process(clk)
    begin
        if rising_edge(clk) then
            -- CLOCK TICK
            if clk_div = DIV_VAL then clk_div <= 0; i2c_tick <= '1';
            else clk_div <= clk_div + 1; i2c_tick <= '0'; end if;

            -- TIMER
            if blink_timer < 25000000 then 
                blink_timer <= blink_timer + 1;
            else
                blink_timer <= 0;
                led_state <= not led_state; -- Toggle
                state <= IDLE; -- Trigger kirim
            end if;

            -- STATE MACHINE
            if i2c_tick = '1' then
                case state is
                    when IDLE =>
                        scl_int <= '1'; sda_int <= '1';
                        if blink_timer = 0 then state <= START; end if;

                    when START =>
                        sda_int <= '0'; scl_int <= '1';
                        state <= ADDR; bit_cnt <= 7;

                    when ADDR => 
                        scl_int <= '0';
                        if bit_cnt >= 0 then
                            if I2C_ADDR(bit_cnt) = '1' then sda_int <= '1'; else sda_int <= '0'; end if;
                            bit_cnt <= bit_cnt - 1;
                        else
                            sda_int <= '0'; -- Write bit (0)
                            state <= ACK1;
                        end if;

                    when ACK1 => 
                        scl_int <= '0'; sda_int <= '1'; -- Release SDA for ACK
                        if scl_int = '0' then scl_int <= '1'; -- Pulse Clock
                        else 
                            scl_int <= '0'; state <= DATA; bit_cnt <= 7;
                            -- Kirim Data: P3=Backlight
                            if led_state = '1' then tx_byte <= x"08"; else tx_byte <= x"00"; end if;
                        end if;

                    when DATA => 
                        scl_int <= '0';
                        if bit_cnt >= 0 then
                            sda_int <= tx_byte(bit_cnt); bit_cnt <= bit_cnt - 1;
                        else
                            state <= ACK2;
                        end if;

                    when ACK2 => 
                        scl_int <= '0'; sda_int <= '1';
                        if scl_int = '0' then scl_int <= '1';
                        else scl_int <= '0'; state <= STOP; end if;

                    when STOP =>
                        scl_int <= '0'; sda_int <= '0';
                        if scl_int = '0' then scl_int <= '1';
                        else sda_int <= '1'; state <= IDLE; end if;
                end case;
                
                -- SCL GENERATION (Toggle saat Data Phase)
                if state = ADDR or state = DATA then
                     if scl_int = '0' then scl_int <= '1';
                     else scl_int <= '0'; end if;
                end if;
            end if;
        end if;
    end process;
end Behavioral;