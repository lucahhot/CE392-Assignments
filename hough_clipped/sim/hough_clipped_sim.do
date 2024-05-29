
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# edgedetect architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/div_unsigned.sv"
vlog -work work "../sv/div_signed.sv"
vlog -work work "../sv/bram.sv"
vlog -work work "../sv/hough_clipped.sv"
vlog -work work "../sv/hough_clipped_top_full.sv"
vlog -work work "../sv/hough_clipped_tb.sv"
vlog -work work "../sv/highlight_clipped.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/hysteresis_clipped.sv"
vlog -work work "../sv/non_maximum_suppressor.sv"
vlog -work work "../sv/sobel.sv"
vlog -work work "../sv/gaussian_blur.sv"

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.hough_tb -wlf hough_clipped.wlf

do hough_clipped_wave.do

run -all
#quit;