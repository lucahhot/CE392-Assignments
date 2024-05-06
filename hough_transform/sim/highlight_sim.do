
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/bram.sv"
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale_mask.sv"
vlog -work work "../sv/highlight.sv"
vlog -work work "../sv/highlight_top.sv"
vlog -work work "../sv/highlight_tb.sv"

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.highlight_tb -wlf highlight.wlf

do highlight_wave.do

run -all
#quit;