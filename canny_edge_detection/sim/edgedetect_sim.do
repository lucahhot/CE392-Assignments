
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/edgedetect_top.sv"
vlog -work work "../sv/edgedetect_tb.sv"

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.edgedetect_tb -wlf edgedetect.wlf

do edgedetect_wave.do

run -all
#quit;