/* VIP flow control wrapper of HDL template */
module gray_wrapper

	#(parameter BITS_PER_SYMBOL = 8,
		parameter SYMBOLS_PER_BEAT = 3)
		
	(	input		clk,
		input		rst,
	
		// interface to decoder
		output	din_ready,
		input		din_valid,
		input		[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] din_data,
		input		[15:0] decoder_width,
		input		[15:0] decoder_height,
		input		[3:0] decoder_interlaced,
		input		decoder_end_of_video,
		input		decoder_is_video,
		input		decoder_vip_ctrl_valid,
		
		// algorithm inputs from decoder
		output	[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_in,
		output	[15:0] width_in,
		output	[15:0] height_in,
		output	[3:0] interlaced_in,
		output	end_of_video,
		output	vip_ctrl_valid,
		
		// algorithm outputs to encoder
		input		[BITS_PER_SYMBOL * 1 - 1:0] data_out,
		input		[15:0] width_out,
		input		[15:0] height_out,
		input		[3:0] interlaced_out,
		input		vip_ctrl_send,
		output	vip_ctrl_busy,
		input		end_of_video_out,
		
		// interface to encoder
		input		dout_ready,
		output	dout_valid,
		output	[BITS_PER_SYMBOL * 1 - 1:0] dout_data,
		output	[15:0] encoder_width,
		output	[15:0] encoder_height,
		output	[3:0] encoder_interlaced,
		output	encoder_vip_ctrl_send,
		input		encoder_vip_ctrl_busy,
		output	encoder_end_of_video,
				
		// flow control signals
		input		read,
		input		write,
		output	stall_in,
		output	stall_out
		);	

// conversion ready/valid to stall/read interface and filtering of active video		
assign data_in = din_data;
assign end_of_video = decoder_end_of_video;
assign din_ready = ~decoder_is_video | read;
assign stall_in = ~(din_valid & decoder_is_video);
		
// conversion stall/write to ready/valid interface
assign dout_data = data_out;
assign encoder_end_of_video = end_of_video_out;
assign dout_valid = write;
assign stall_out = ~dout_ready;

// decoder control signals
assign width_in = decoder_width;
assign height_in = decoder_height;
assign interlaced_in = decoder_interlaced;
assign vip_ctrl_valid = decoder_vip_ctrl_valid;
	
// encoder control signals
assign encoder_width = width_out;
assign encoder_height = height_out;
assign encoder_interlaced = interlaced_out;
assign encoder_vip_ctrl_send = vip_ctrl_send;
assign vip_ctrl_busy = encoder_vip_ctrl_busy;
	
endmodule
		
					
			