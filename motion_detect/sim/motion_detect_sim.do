setenv LMC_TIMEUNIT -9
vlib work
vmap work work

vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/grayscale.sv"
vlog -work work "../sv/mask.sv"
vlog -work work "../sv/highlight.sv"
vlog -work work "../sv/motion_detect_top.sv"
vlog -work work "../sv/motion_detect_tb.sv"

vsim -classdebug -voptargs=+acc +notimingchecks -L work work.motion_detect_tb -wlf motion_detect.wlf

do motion_detect_wave.do

run -all
