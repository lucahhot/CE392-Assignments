
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/globals.sv"
vlog -work work "../sv/bram.sv"
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/grayscale_mask.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/gaussian_blur.sv"
vlog -work work "../sv/div.sv"
vlog -work work "../sv/non_maximum_suppressor.sv"
vlog -work work "../sv/hysteresis.sv"
vlog -work work "../sv/hough.sv"
vlog -work work "../sv/hough_top.sv"
vlog -work work "../sv/hough_tb.sv"
vlog -work work "../sv/image_loader.sv"


# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.hough_tb -wlf hough.wlf

do hough_wave.do

run -all
#quit;