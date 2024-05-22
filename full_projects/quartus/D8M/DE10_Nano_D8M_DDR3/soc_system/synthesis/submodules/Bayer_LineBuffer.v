// megafunction wizard: %Shift register (RAM-based)%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: ALTSHIFT_TAPS 

// ============================================================
// File Name: Bayer_LineBuffer.v
// Megafunction Name(s):
// 			ALTSHIFT_TAPS
//
// Simulation Library Files(s):
// 			altera_mf
// ============================================================
// ************************************************************
// THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//
// 15.1.2 Build 193 02/01/2016 SJ Standard Edition
// ************************************************************


//Copyright (C) 1991-2016 Altera Corporation. All rights reserved.
//Your use of Altera Corporation's design tools, logic functions 
//and other software and tools, and its AMPP partner logic 
//functions, and any output files from any of the foregoing 
//(including device programming or simulation files), and any 
//associated documentation or information are expressly subject 
//to the terms and conditions of the Altera Program License 
//Subscription Agreement, the Altera Quartus Prime License Agreement,
//the Altera MegaCore Function License Agreement, or other 
//applicable license agreement, including, without limitation, 
//that your use is for the sole purpose of programming logic 
//devices manufactured by Altera and sold by Altera or its 
//authorized distributors.  Please refer to the applicable 
//agreement for further details.


// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module Bayer_LineBuffer #(
	parameter VIDEO_W = 1920
)(
	aclr,
	clken,
	clock,
	shiftin,
	shiftout,
	taps);

	input	  aclr;
	input	  clken;
	input	  clock;
	input	[11:0]  shiftin;
	output	[11:0]  shiftout;
	output	[35:0]  taps;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1	  aclr;
	tri1	  clken;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [11:0] sub_wire0;
	wire [35:0] sub_wire1;
	wire [11:0] shiftout = sub_wire0[11:0];
	wire [35:0] taps = sub_wire1[35:0];

	altshift_taps	ALTSHIFT_TAPS_component (
				.aclr (aclr),
				.clken (clken),
				.clock (clock),
				.shiftin (shiftin),
				.shiftout (sub_wire0),
				.taps (sub_wire1)
				// synopsys translate_off
				,
				.sclr ()
				// synopsys translate_on
				);
	defparam
		ALTSHIFT_TAPS_component.intended_device_family = "Stratix V",
		ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M20K",
		ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
		ALTSHIFT_TAPS_component.number_of_taps = 3,
		//ALTSHIFT_TAPS_component.tap_distance = 1920,
		ALTSHIFT_TAPS_component.tap_distance = VIDEO_W,  // richard modify
		ALTSHIFT_TAPS_component.width = 12;


endmodule

// ============================================================
// CNX file retrieval info
// ============================================================
// Retrieval info: PRIVATE: ACLR NUMERIC "1"
// Retrieval info: PRIVATE: CLKEN NUMERIC "1"
// Retrieval info: PRIVATE: GROUP_TAPS NUMERIC "0"
// Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Stratix V"
// Retrieval info: PRIVATE: NUMBER_OF_TAPS NUMERIC "3"
// Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "1"
// Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
// Retrieval info: PRIVATE: TAP_DISTANCE NUMERIC "1920"
// Retrieval info: PRIVATE: WIDTH NUMERIC "12"
// Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
// Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Stratix V"
// Retrieval info: CONSTANT: LPM_HINT STRING "RAM_BLOCK_TYPE=M20K"
// Retrieval info: CONSTANT: LPM_TYPE STRING "altshift_taps"
// Retrieval info: CONSTANT: NUMBER_OF_TAPS NUMERIC "3"
// Retrieval info: CONSTANT: TAP_DISTANCE NUMERIC "1920"
// Retrieval info: CONSTANT: WIDTH NUMERIC "12"
// Retrieval info: USED_PORT: aclr 0 0 0 0 INPUT VCC "aclr"
// Retrieval info: USED_PORT: clken 0 0 0 0 INPUT VCC "clken"
// Retrieval info: USED_PORT: clock 0 0 0 0 INPUT NODEFVAL "clock"
// Retrieval info: USED_PORT: shiftin 0 0 12 0 INPUT NODEFVAL "shiftin[11..0]"
// Retrieval info: USED_PORT: shiftout 0 0 12 0 OUTPUT NODEFVAL "shiftout[11..0]"
// Retrieval info: USED_PORT: taps 0 0 36 0 OUTPUT NODEFVAL "taps[35..0]"
// Retrieval info: CONNECT: @aclr 0 0 0 0 aclr 0 0 0 0
// Retrieval info: CONNECT: @clken 0 0 0 0 clken 0 0 0 0
// Retrieval info: CONNECT: @clock 0 0 0 0 clock 0 0 0 0
// Retrieval info: CONNECT: @shiftin 0 0 12 0 shiftin 0 0 12 0
// Retrieval info: CONNECT: shiftout 0 0 12 0 @shiftout 0 0 12 0
// Retrieval info: CONNECT: taps 0 0 36 0 @taps 0 0 36 0
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer.v TRUE
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer.inc FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer.cmp FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer.bsf FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer_inst.v FALSE
// Retrieval info: GEN_FILE: TYPE_NORMAL Bayer_LineBuffer_bb.v TRUE
// Retrieval info: LIB_FILE: altera_mf
