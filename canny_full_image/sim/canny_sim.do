
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/gaussian_blur.sv"
vlog -work work "../sv/non_maximum_suppressor.sv"
vlog -work work "../sv/hysteresis.sv"
vlog -work work "../sv/canny_top.sv"
vlog -work work "../sv/canny_tb.sv"


# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.canny_tb -wlf canny.wlf

do canny_wave.do

run -all
#quit;