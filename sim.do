# 1. Create and map the work library
vlib work
vmap work work

# 2. Compile Design Files (Order matters for dependencies)
# Support components first
vcom -2008 uart.vhd
vcom -2008 CRCtransmitter.vhd
vcom -2008 CRCreceiver.vhd

# Top Level (The modified version with padding)
vcom -2008 TopLevel_CRC.vhd

# Testbench
vcom -2008 tb_TopLevel_CRC.vhd

# 3. Load Simulation
# -voptargs=+acc enables full signal visibility for debugging
vsim -voptargs=+acc work.tb_TopLevel_CRC

# 4. Add Signals to Wave Window
# Grouping them makes it easier to read
add wave -noupdate -divider "System"
add wave -noupdate -color "white" /tb_TopLevel_CRC/clk
add wave -noupdate -color "red"   /tb_TopLevel_CRC/reset
add wave -noupdate /tb_TopLevel_CRC/btn_tick

add wave -noupdate -divider "UART Physical"
add wave -noupdate -color "yellow" /tb_TopLevel_CRC/uart_rx
add wave -noupdate -color "cyan"   /tb_TopLevel_CRC/uart_tx

add wave -noupdate -divider "Internal State (Debug)"
add wave -noupdate -radix ascii /tb_TopLevel_CRC/uut/uart_data_out
add wave -noupdate /tb_TopLevel_CRC/uut/current_mode
add wave -noupdate /tb_TopLevel_CRC/uut/tx_state
add wave -noupdate /tb_TopLevel_CRC/uut/internal_data_valid

add wave -noupdate -divider "Padding Logic"
add wave -noupdate -radix unsigned /tb_TopLevel_CRC/uut/byte_tracker
add wave -noupdate /tb_TopLevel_CRC/uut/pad_zeros_active
add wave -noupdate /tb_TopLevel_CRC/uut/crc_input_data
add wave -noupdate /tb_TopLevel_CRC/uut/crc_input_valid

add wave -noupdate -divider "Outputs"
add wave -noupdate -radix hex /tb_TopLevel_CRC/data_crc
add wave -noupdate /tb_TopLevel_CRC/is_corrupt

# 5. Run Simulation
# Run long enough to see the slow UART transactions
# (Approx 10ms should cover the bytes sent at 9600 baud)
run 120 ms

# Zoom to fit
wave zoom full