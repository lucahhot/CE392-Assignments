
setenv LMC_TIMEUNIT -9
vlib work
vmap work work

# udp_reader architecture
vlog -work work "../sv/fifo.sv"
vlog -work work "../sv/nms.sv"
vlog -work work "../sv/nms_top.sv"
vlog -work work "../sv/nms_tb.sv"

# uvm library
#vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm.sv
#vlog -work work +incdir+$env(UVM_HOME)/src $env(UVM_HOME)/src/uvm_macros.svh
#vlog -work work +incdir+$env(UVM_HOME)/src $env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/questa_uvm_pkg.sv

# start uvm simulation
# vsim -classdebug -voptargs=+acc +notimingchecks -L work work.iir_uvm_tb -wlf iir_uvm_tb.wlf -sv_lib lib/uvm_dpi -dpicpppath /usr/bin/gcc +incdir+$env(MTI_HOME)/verilog_src/questa_uvm_pkg-1.2/src/

# start basic simulation
vsim -classdebug -voptargs=+acc +notimingchecks -L work work.nms_tb -wlf nms.wlf

# do iir_wave.do

add wave -noupdate -group nms_tb/nms_top_inst
add wave -noupdate -group nms_tb/nms_top_inst -radix hexadecimal /nms_tb/nms_top_inst/*

add wave -noupdate -group nms_tb/nms_top_inst/fifo_image_inst
add wave -noupdate -group nms_tb/nms_top_inst/fifo_image_inst -radix hexadecimal /nms_tb/nms_top_inst/fifo_image_inst/*

add wave -noupdate -group nms_tb/nms_top_inst/nms_inst
add wave -noupdate -group nms_tb/nms_top_inst/nms_inst -radix hexadecimal /nms_tb/nms_top_inst/nms_inst/*

add wave -noupdate -group nms_tb/nms_top_inst/fifo_img_out_inst
add wave -noupdate -group nms_tb/nms_top_inst/fifo_img_out_inst -radix hexadecimal /nms_tb/nms_top_inst/fifo_img_out_inst/*

run -all
#quit;