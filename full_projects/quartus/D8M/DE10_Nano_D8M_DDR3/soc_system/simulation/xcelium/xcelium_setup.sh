
# (C) 2001-2024 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and 
# other software and tools, and its AMPP partner logic functions, and 
# any output files any of the foregoing (including device programming 
# or simulation files), and any associated documentation or information 
# are expressly subject to the terms and conditions of the Altera 
# Program License Subscription Agreement, Altera MegaCore Function 
# License Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by Altera 
# or its authorized distributors. Please refer to the applicable 
# agreement for further details.

# ACDS 23.1 991 linux 2024.05.13.00:03:26

# ----------------------------------------
# xcelium - auto-generated simulation script

# ----------------------------------------
# This script provides commands to simulate the following IP detected in
# your Quartus project:
#     soc_system
# 
# Altera recommends that you source this Quartus-generated IP simulation
# script from your own customized top-level script, and avoid editing this
# generated script.
# 
# Xcelium Simulation Script.
# To write a top-level shell script that compiles Intel simulation libraries
# and the Quartus-generated IP in your project, along with your design and
# testbench files, copy the text from the TOP-LEVEL TEMPLATE section below
# into a new file, e.g. named "xcelium_sim.sh", and modify text as directed.
# 
# You can also modify the simulation flow to suit your needs. Set the
# following variables to 1 to disable their corresponding processes:
# - SKIP_FILE_COPY: skip copying ROM/RAM initialization files
# - SKIP_DEV_COM: skip compiling the Quartus EDA simulation library
# - SKIP_COM: skip compiling Quartus-generated IP simulation files
# - SKIP_ELAB and SKIP_SIM: skip elaboration and simulation
# 
# ----------------------------------------
# # TOP-LEVEL TEMPLATE - BEGIN
# #
# # QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# # construct paths to the files required to simulate the IP in your Quartus
# # project. By default, the IP script assumes that you are launching the
# # simulator from the IP script location. If launching from another
# # location, set QSYS_SIMDIR to the output directory you specified when you
# # generated the IP script, relative to the directory from which you launch
# # the simulator. In this case, you must also copy the generated files
# # "cds.lib" and "hdl.var" - plus the directory "cds_libs" if generated - 
# # into the location from which you launch the simulator, or incorporate
# # into any existing library setup.
# #
# # Run Quartus-generated IP simulation script once to compile Quartus EDA
# # simulation libraries and Quartus-generated IP simulation files, and copy
# # any ROM/RAM initialization files to the simulation directory.
# # - If necessary, specify any compilation options:
# #   USER_DEFINED_COMPILE_OPTIONS
# #   USER_DEFINED_VHDL_COMPILE_OPTIONS applied to vhdl compiler
# #   USER_DEFINED_VERILOG_COMPILE_OPTIONS applied to verilog compiler
# #
# source <script generation output directory>/xcelium/xcelium_setup.sh \
# SKIP_ELAB=1 \
# SKIP_SIM=1 \
# USER_DEFINED_COMPILE_OPTIONS=<compilation options for your design> \
# USER_DEFINED_VHDL_COMPILE_OPTIONS=<VHDL compilation options for your design> \
# USER_DEFINED_VERILOG_COMPILE_OPTIONS=<Verilog compilation options for your design> \
# QSYS_SIMDIR=<script generation output directory>
# #
# # Compile all design files and testbench files, including the top level.
# # (These are all the files required for simulation other than the files
# # compiled by the IP script)
# #
# xmvlog <compilation options> <design and testbench files>
# #
# # TOP_LEVEL_NAME is used in this script to set the top-level simulation or
# # testbench module/entity name.
# #
# # Run the IP script again to elaborate and simulate the top level:
# # - Specify TOP_LEVEL_NAME and USER_DEFINED_ELAB_OPTIONS.
# # - Override the default USER_DEFINED_SIM_OPTIONS. For example, to run
# #   until $finish(), set to an empty string: USER_DEFINED_SIM_OPTIONS="".
# #
# source <script generation output directory>/xcelium/xcelium_setup.sh \
# SKIP_FILE_COPY=1 \
# SKIP_DEV_COM=1 \
# SKIP_COM=1 \
# TOP_LEVEL_NAME=<simulation top> \
# USER_DEFINED_ELAB_OPTIONS=<elaboration options for your design> \
# USER_DEFINED_SIM_OPTIONS=<simulation options for your design>
# #
# # TOP-LEVEL TEMPLATE - END
# ----------------------------------------
# 
# IP SIMULATION SCRIPT
# ----------------------------------------
# If soc_system is one of several IP cores in your
# Quartus project, you can generate a simulation script
# suitable for inclusion in your top-level simulation
# script by running the following command line:
# 
# ip-setup-simulation --quartus-project=<quartus project>
# 
# ip-setup-simulation will discover the Altera IP
# within the Quartus project, and generate a unified
# script which supports all the Altera IP within the design.
# ----------------------------------------
# ACDS 23.1 991 linux 2024.05.13.00:03:26
# ----------------------------------------
# initialize variables
TOP_LEVEL_NAME="soc_system"
QSYS_SIMDIR="./../"
QUARTUS_INSTALL_DIR="/home/laa8390/intelFPGA_lite/23.1std/quartus/"
SKIP_FILE_COPY=0
SKIP_DEV_COM=0
SKIP_COM=0
SKIP_ELAB=0
SKIP_SIM=0
USER_DEFINED_ELAB_OPTIONS=""
USER_DEFINED_SIM_OPTIONS="-input \"@run 100; exit\""

# ----------------------------------------
# overwrite variables - DO NOT MODIFY!
# This block evaluates each command line argument, typically used for 
# overwriting variables. An example usage:
#   sh <simulator>_setup.sh SKIP_SIM=1
for expression in "$@"; do
  eval $expression
  if [ $? -ne 0 ]; then
    echo "Error: This command line argument, \"$expression\", is/has an invalid expression." >&2
    exit $?
  fi
done

# ----------------------------------------
# initialize simulation properties - DO NOT MODIFY!
ELAB_OPTIONS=""
SIM_OPTIONS=""
if [[ `xmsim -version` != *"xmsim(64)"* ]]; then
  :
else
  :
fi

# ----------------------------------------
# create compilation libraries
mkdir -p ./libraries/work/
mkdir -p ./libraries/altera_common_sv_packages/
mkdir -p ./libraries/hps/
mkdir -p ./libraries/address_span_extender_0/
mkdir -p ./libraries/sync_ctrl/
mkdir -p ./libraries/video_out/
mkdir -p ./libraries/rd_ctrl/
mkdir -p ./libraries/pkt_trans_wr/
mkdir -p ./libraries/wr_ctrl/
mkdir -p ./libraries/video_in/
mkdir -p ./libraries/rst_controller/
mkdir -p ./libraries/mm_interconnect_0/
mkdir -p ./libraries/pll_1/
mkdir -p ./libraries/pll_0/
mkdir -p ./libraries/hps_ddr3/
mkdir -p ./libraries/alt_vip_itc_0/
mkdir -p ./libraries/alt_vip_cl_vfb_0/
mkdir -p ./libraries/TERASIC_CAMERA_0/
mkdir -p ./libraries/altera_ver/
mkdir -p ./libraries/lpm_ver/
mkdir -p ./libraries/sgate_ver/
mkdir -p ./libraries/altera_mf_ver/
mkdir -p ./libraries/altera_lnsim_ver/
mkdir -p ./libraries/cyclonev_ver/
mkdir -p ./libraries/cyclonev_hssi_ver/
mkdir -p ./libraries/cyclonev_pcie_hip_ver/

# ----------------------------------------
# copy RAM/ROM files to simulation directory

# ----------------------------------------
# compile device library files
if [ $SKIP_DEV_COM -eq 0 ]; then
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_primitives.v"                      -work altera_ver           
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/220model.v"                               -work lpm_ver              
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/sgate.v"                                  -work sgate_ver            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_mf.v"                              -work altera_mf_ver        
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QUARTUS_INSTALL_DIR/eda/sim_lib/altera_lnsim.sv"                          -work altera_lnsim_ver     
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cadence/cyclonev_atoms_ncrypt.v"          -work cyclonev_ver         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cadence/cyclonev_hmi_atoms_ncrypt.v"      -work cyclonev_ver         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_atoms.v"                         -work cyclonev_ver         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cadence/cyclonev_hssi_atoms_ncrypt.v"     -work cyclonev_hssi_ver    
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_hssi_atoms.v"                    -work cyclonev_hssi_ver    
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cadence/cyclonev_pcie_hip_atoms_ncrypt.v" -work cyclonev_pcie_hip_ver
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_pcie_hip_atoms.v"                -work cyclonev_pcie_hip_ver
fi

# ----------------------------------------
# compile design files in correct order
if [ $SKIP_COM -eq 0 ]; then
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/common/alt_vip_common_pkg.sv"                                                                           -work altera_common_sv_packages -cdslib ./cds_libs/altera_common_sv_packages.cds.lib
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_hps_ddr3_hps.v"                                                                                      -work hps                       -cdslib ./cds_libs/hps.cds.lib                      
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/altera_address_span_extender.sv"                                                                                -work address_span_extender_0   -cdslib ./cds_libs/address_span_extender_0.cds.lib  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv"               -work sync_ctrl                 -cdslib ./cds_libs/sync_ctrl.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv"               -work sync_ctrl                 -cdslib ./cds_libs/sync_ctrl.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_vfb_sync_ctrl.sv"                                                                       -work sync_ctrl                 -cdslib ./cds_libs/sync_ctrl.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_latency_0_to_latency_1.sv"            -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_video_packet_empty.sv"                -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_video_packet_encode.sv"               -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv"               -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv"               -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_message_pipeline_stage/src_hdl/alt_vip_common_message_pipeline_stage.sv"         -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_sop_align/src_hdl/alt_vip_common_sop_align.sv"                                   -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_video_output_bridge.sv"                                                                 -work video_out                 -cdslib ./cds_libs/video_out.cds.lib                
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv"               -work rd_ctrl                   -cdslib ./cds_libs/rd_ctrl.cds.lib                  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv"               -work rd_ctrl                   -cdslib ./cds_libs/rd_ctrl.cds.lib                  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_vfb_rd_ctrl.sv"                                                                         -work rd_ctrl                   -cdslib ./cds_libs/rd_ctrl.cds.lib                  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv"               -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv"               -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_dc_mixed_widths_fifo/src_hdl/alt_vip_common_dc_mixed_widths_fifo.sv"             -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_fifo2/src_hdl/alt_vip_common_fifo2.sv"                                           -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_delay/src_hdl/alt_vip_common_delay.sv"                                           -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_clock_crossing_bridge_grey/src_hdl/alt_vip_common_clock_crossing_bridge_grey.sv" -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer_pack_proc.sv"                                                           -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer_twofold_ram.sv"                                                         -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer_twofold_ram_reversed.sv"                                                -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer_read_proc.sv"                                                           -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer_write_proc.sv"                                                          -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_packet_transfer.sv"                                                                     -work pkt_trans_wr              -cdslib ./cds_libs/pkt_trans_wr.cds.lib             
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv"               -work wr_ctrl                   -cdslib ./cds_libs/wr_ctrl.cds.lib                  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv"               -work wr_ctrl                   -cdslib ./cds_libs/wr_ctrl.cds.lib                  
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/cadence/src_hdl/alt_vip_vfb_wr_ctrl.sv"                                                                         -work wr_ctrl                   -cdslib ./cds_libs/wr_ctrl.cds.lib                  
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_alt_vip_cl_vfb_0_video_in.v"                                                                         -work video_in                  -cdslib ./cds_libs/video_in.cds.lib                 
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/altera_reset_controller.v"                                                                                      -work rst_controller            -cdslib ./cds_libs/rst_controller.cds.lib           
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/altera_reset_synchronizer.v"                                                                                    -work rst_controller            -cdslib ./cds_libs/rst_controller.cds.lib           
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_mm_interconnect_0.v"                                                                                 -work mm_interconnect_0         -cdslib ./cds_libs/mm_interconnect_0.cds.lib        
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_pll_1.vo"                                                                                            -work pll_1                     -cdslib ./cds_libs/pll_1.cds.lib                    
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_pll_0.vo"                                                                                            -work pll_0                     -cdslib ./cds_libs/pll_0.cds.lib                    
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_hps_ddr3.v"                                                                                          -work hps_ddr3                  -cdslib ./cds_libs/hps_ddr3.cds.lib                 
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid.sv"                                                                                        -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_sync_compare.v"                                                                            -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_calculate_mode.v"                                                                          -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_control.v"                                                                                 -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog -sv $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_mode_banks.sv"                                                                             -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_statemachine.v"                                                                            -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_fifo.v"                                                                                    -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_generic_count.v"                                                                           -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_to_binary.v"                                                                               -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_sync.v"                                                                                    -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_trigger_sync.v"                                                                            -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_sync_generation.v"                                                                         -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_frame_counter.v"                                                                           -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/alt_vipitc131_common_sample_counter.v"                                                                          -work alt_vip_itc_0             -cdslib ./cds_libs/alt_vip_itc_0.cds.lib            
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/soc_system_alt_vip_cl_vfb_0.v"                                                                                  -work alt_vip_cl_vfb_0          -cdslib ./cds_libs/alt_vip_cl_vfb_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/TERASIC_CAMERA.v"                                                                                               -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/CAMERA_RGB.v"                                                                                                   -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/CAMERA_Bayer.v"                                                                                                 -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/Bayer2RGB.v"                                                                                                    -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/Bayer_LineBuffer.v"                                                                                             -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/rgb_fifo.v"                                                                                                     -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/add2.v"                                                                                                         -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/submodules/add4.v"                                                                                                         -work TERASIC_CAMERA_0          -cdslib ./cds_libs/TERASIC_CAMERA_0.cds.lib         
  xmvlog $USER_DEFINED_VERILOG_COMPILE_OPTIONS $USER_DEFINED_COMPILE_OPTIONS     "$QSYS_SIMDIR/soc_system.v"                                                                                                                                                                                                  
fi

# ----------------------------------------
# elaborate top level design
if [ $SKIP_ELAB -eq 0 ]; then
  xmelab -update -access +w+r+c -namemap_mixgen +DISABLEGENCHK $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS $TOP_LEVEL_NAME
fi

# ----------------------------------------
# simulate
if [ $SKIP_SIM -eq 0 ]; then
  eval xmsim -licqueue $SIM_OPTIONS $USER_DEFINED_SIM_OPTIONS $TOP_LEVEL_NAME
fi
