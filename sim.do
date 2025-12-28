# 1. Initialize
quit -sim
vlib work
vmap work work

# 2. Compile Utilities
vcom -2008 mux2to1_32bit.vhd
vcom -2008 mux2to1_8bit.vhd
vcom -2008 register32bitPIPO.vhd
vcom -2008 Register32BitSIPO.vhd
vcom -2008 UpCounter.vhd
vcom -2008 comparator.vhd
vcom -2008 LUT_1.vhd
vcom -2008 LUT_2.vhd
vcom -2008 LUT_3.vhd
vcom -2008 LUT_4.vhd
vcom -2008 LUT_Prev.vhd
vcom -2008 counter4bit.vhd

# 3. Compile Logic
vcom -2008 FSM_Pengontrol.vhd
vcom -2008 CRCtransmitter.vhd
vcom -2008 CRCreceiver.vhd
vcom -2008 Result_Serializer.vhd

# 4. Compile UART & Top
vcom -2008 uart_tx.vhd
vcom -2008 uart_rx.vhd
vcom -2008 uart.vhd
vcom -2008 TopLevel_CRC.vhd
vcom -2008 tb_TopLevel_CRC.vhd

# 5. Load
vsim -voptargs=+acc work.tb_TopLevel_CRC

# 6. Waveforms
add wave -divider "Top Level Inputs"
add wave -noupdate /tb_TopLevel_CRC/clk
add wave -noupdate /tb_TopLevel_CRC/reset
add wave -noupdate /tb_TopLevel_CRC/btn_tick
add wave -noupdate /tb_TopLevel_CRC/uart_rx 

add wave -divider "Internal Data"
# This shows the data extracted from UART inside the FPGA
add wave -noupdate -radix hex /tb_TopLevel_CRC/uut/uart_data_out
add wave -noupdate /tb_TopLevel_CRC/uut/uart_valid

add wave -divider "Top Level Outputs"
add wave -noupdate -radix hex /tb_TopLevel_CRC/data_crc
add wave -noupdate /tb_TopLevel_CRC/is_corrupt

add wave -divider "UART Output (Text)"
add wave -noupdate /tb_TopLevel_CRC/uart_tx
# Look here to see the ASCII text being sent back!
add wave -noupdate -radix ASCII /tb_TopLevel_CRC/uut/SERIALIZER_INST/uart_data
add wave -noupdate /tb_TopLevel_CRC/uut/SERIALIZER_INST/uart_start

# 7. Run
run 80 ms
