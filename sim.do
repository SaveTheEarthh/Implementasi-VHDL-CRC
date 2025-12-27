# 1. Create and map the library
vlib work
vmap work work

# 2. Compile Utilities and Components first 
# (Assuming these files exist in your folder - add any missing ones here)
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

# 3. Compile the Main Logic Modules
vcom -2008 FSM_Pengontrol.vhd
vcom -2008 CRCtransmitter.vhd
vcom -2008 CRCreceiver.vhd

# 4. Compile Top Level and Testbench
vcom -2008 TopLevel_CRC.vhd
vcom -2008 tb_TopLevel_CRC.vhd

# 5. Load the simulation
vsim -voptargs=+acc work.tb_TopLevel_CRC

# 6. Setup Waveforms (Organized by module)
add wave -divider "Top Level Inputs"
add wave -noupdate -color white /tb_TopLevel_CRC/clk
add wave -noupdate -color white /tb_TopLevel_CRC/reset
add wave -noupdate -color yellow /tb_TopLevel_CRC/btn_tick

add wave -divider "Top Level Outputs"
add wave -noupdate -radix hex /tb_TopLevel_CRC/data_crc
add wave -noupdate -color red /tb_TopLevel_CRC/is_corrupt

add wave -divider "Internal State"
add wave -noupdate /tb_TopLevel_CRC/uut/current_state
add wave -noupdate /tb_TopLevel_CRC/uut/valid_for_tx
add wave -noupdate /tb_TopLevel_CRC/uut/valid_for_rx

# 7. Run Simulation
run 75 ms