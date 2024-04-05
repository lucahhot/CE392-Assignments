
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/gaussian_blur.sv"
vlog -work work "../sv/canny_edgedetect_top.sv"
vlog -work work "../sv/canny_edgedetect_tb.sv"
vlog -work work "../sv/div.sv"

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.canny_edgedetect_tb -wlf canny_edgedetect.wlf

do canny_edgedetect_wave.do

run -all
#quit;