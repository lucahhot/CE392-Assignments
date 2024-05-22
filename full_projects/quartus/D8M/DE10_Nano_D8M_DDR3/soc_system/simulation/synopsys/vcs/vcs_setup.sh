
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
# vcs - auto-generated simulation script

# ----------------------------------------
# This script provides commands to simulate the following IP detected in
# your Quartus project:
#     soc_system
# 
# Altera recommends that you source this Quartus-generated IP simulation
# script from your own customized top-level script, and avoid editing this
# generated script.
# 
# To write a top-level shell script that compiles Altera simulation libraries
# and the Quartus-generated IP in your project, along with your design and
# testbench files, follow the guidelines below.
# 
# 1) Copy the shell script text from the TOP-LEVEL TEMPLATE section
# below into a new file, e.g. named "vcs_sim.sh".
# 
# 2) Copy the text from the DESIGN FILE LIST & OPTIONS TEMPLATE section into
# a separate file, e.g. named "filelist.f".
# 
# ----------------------------------------
# # TOP-LEVEL TEMPLATE - BEGIN
# #
# # TOP_LEVEL_NAME is used in the Quartus-generated IP simulation script to
# # set the top-level simulation or testbench module/entity name.
# #
# # QSYS_SIMDIR is used in the Quartus-generated IP simulation script to
# # construct paths to the files required to simulate the IP in your Quartus
# # project. By default, the IP script assumes that you are launching the
# # simulator from the IP script location. If launching from another
# # location, set QSYS_SIMDIR to the output directory you specified when you
# # generated the IP script, relative to the directory from which you launch
# # the simulator.
# #
# # Source the Quartus-generated IP simulation script and do the following:
# # - Compile the Quartus EDA simulation library and IP simulation files.
# # - Specify TOP_LEVEL_NAME and QSYS_SIMDIR.
# # - Compile the design and top-level simulation module/entity using
# #   information specified in "filelist.f".
# # - Override the default USER_DEFINED_SIM_OPTIONS. For example, to run
# #   until $finish(), set to an empty string: USER_DEFINED_SIM_OPTIONS="".
# # - Run the simulation.
# #
# source <script generation output directory>/synopsys/vcs/vcs_setup.sh \
# TOP_LEVEL_NAME=<simulation top> \
# QSYS_SIMDIR=<script generation output directory> \
# USER_DEFINED_ELAB_OPTIONS="\"-f filelist.f\"" \
# USER_DEFINED_SIM_OPTIONS=<simulation options for your design>
# #
# # TOP-LEVEL TEMPLATE - END
# ----------------------------------------
# 
# ----------------------------------------
# # DESIGN FILE LIST & OPTIONS TEMPLATE - BEGIN
# #
# # Compile all design files and testbench files, including the top level.
# # (These are all the files required for simulation other than the files
# # compiled by the Quartus-generated IP simulation script)
# #
# +systemverilogext+.sv
# <design and testbench files, compile-time options, elaboration options>
# #
# # DESIGN FILE LIST & OPTIONS TEMPLATE - END
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
QSYS_SIMDIR="./../../"
QUARTUS_INSTALL_DIR="/home/laa8390/intelFPGA_lite/23.1std/quartus/"
SKIP_FILE_COPY=0
SKIP_SIM=0
USER_DEFINED_ELAB_OPTIONS=""
USER_DEFINED_SIM_OPTIONS="+vcs+finish+100"
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
if [[ `vcs -platform` != *"amd64"* ]]; then
  :
else
  :
fi

# ----------------------------------------
# copy RAM/ROM files to simulation directory

vcs -lca -timescale=1ps/1ps -sverilog +verilog2001ext+.v -ntb_opts dtm $ELAB_OPTIONS $USER_DEFINED_ELAB_OPTIONS \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/altera_primitives.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/220model.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/sgate.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/altera_mf.v \
  $QUARTUS_INSTALL_DIR/eda/sim_lib/altera_lnsim.sv \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/synopsys/cyclonev_atoms_ncrypt.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/synopsys/cyclonev_hmi_atoms_ncrypt.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_atoms.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/synopsys/cyclonev_hssi_atoms_ncrypt.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_hssi_atoms.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/synopsys/cyclonev_pcie_hip_atoms_ncrypt.v \
  -v $QUARTUS_INSTALL_DIR/eda/sim_lib/cyclonev_pcie_hip_atoms.v \
  $QSYS_SIMDIR/submodules/synopsys/common/alt_vip_common_pkg.sv \
  $QSYS_SIMDIR/submodules/soc_system_hps_ddr3_hps.v \
  $QSYS_SIMDIR/submodules/altera_address_span_extender.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_event_packet_decode/src_hdl/alt_vip_common_event_packet_decode.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_event_packet_encode/src_hdl/alt_vip_common_event_packet_encode.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_vfb_sync_ctrl.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_latency_0_to_latency_1.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_video_packet_empty.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_video_packet_encode/src_hdl/alt_vip_common_video_packet_encode.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_message_pipeline_stage/src_hdl/alt_vip_common_message_pipeline_stage.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_sop_align/src_hdl/alt_vip_common_sop_align.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_video_output_bridge.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_vfb_rd_ctrl.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_dc_mixed_widths_fifo/src_hdl/alt_vip_common_dc_mixed_widths_fifo.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_fifo2/src_hdl/alt_vip_common_fifo2.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_delay/src_hdl/alt_vip_common_delay.sv \
  $QSYS_SIMDIR/submodules/synopsys/modules/alt_vip_common_clock_crossing_bridge_grey/src_hdl/alt_vip_common_clock_crossing_bridge_grey.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer_pack_proc.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer_twofold_ram.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer_twofold_ram_reversed.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer_read_proc.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer_write_proc.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_packet_transfer.sv \
  $QSYS_SIMDIR/submodules/synopsys/src_hdl/alt_vip_vfb_wr_ctrl.sv \
  $QSYS_SIMDIR/submodules/soc_system_alt_vip_cl_vfb_0_video_in.v \
  $QSYS_SIMDIR/submodules/altera_reset_controller.v \
  $QSYS_SIMDIR/submodules/altera_reset_synchronizer.v \
  $QSYS_SIMDIR/submodules/soc_system_mm_interconnect_0.v \
  $QSYS_SIMDIR/submodules/soc_system_pll_1.vo \
  $QSYS_SIMDIR/submodules/soc_system_pll_0.vo \
  $QSYS_SIMDIR/submodules/soc_system_hps_ddr3.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid.sv \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_sync_compare.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_calculate_mode.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_control.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_mode_banks.sv \
  $QSYS_SIMDIR/submodules/alt_vipitc131_IS2Vid_statemachine.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_fifo.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_generic_count.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_to_binary.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_sync.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_trigger_sync.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_sync_generation.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_frame_counter.v \
  $QSYS_SIMDIR/submodules/alt_vipitc131_common_sample_counter.v \
  $QSYS_SIMDIR/submodules/soc_system_alt_vip_cl_vfb_0.v \
  $QSYS_SIMDIR/submodules/TERASIC_CAMERA.v \
  $QSYS_SIMDIR/submodules/CAMERA_RGB.v \
  $QSYS_SIMDIR/submodules/CAMERA_Bayer.v \
  $QSYS_SIMDIR/submodules/Bayer2RGB.v \
  $QSYS_SIMDIR/submodules/Bayer_LineBuffer.v \
  $QSYS_SIMDIR/submodules/rgb_fifo.v \
  $QSYS_SIMDIR/submodules/add2.v \
  $QSYS_SIMDIR/submodules/add4.v \
  $QSYS_SIMDIR/soc_system.v \
  -top $TOP_LEVEL_NAME
# ----------------------------------------
# simulate
if [ $SKIP_SIM -eq 0 ]; then
  ./simv $SIM_OPTIONS $USER_DEFINED_SIM_OPTIONS
fi
