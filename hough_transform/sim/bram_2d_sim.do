
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/bram_2d.sv"
vlog -work work "../sv/bram_2d_tb.sv"

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.bram_2d_tb -wlf bram_2d.wlf

add wave -noupdate -group bram_2d_tb
add wave -noupdate -group bram_2d_tb -radix hexadecimal /bram_2d_tb/*

add wave -noupdate -group bram_2d_tb/bram_2d_inst
add wave -noupdate -group bram_2d_tb/bram_2d_inst -radix hexadecimal /bram_2d_tb/bram_2d_inst/*

run -all
#quit;