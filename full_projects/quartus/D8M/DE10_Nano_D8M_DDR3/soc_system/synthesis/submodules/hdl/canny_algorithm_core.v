
module canny_algorithm_core

	#(parameter BITS_PER_SYMBOL = 8,
		parameter SYMBOLS_PER_BEAT = 3) // only 1 symbol used as black/white
		
	(	input		clk,
		input		rst,
		
		// interface to VIP control packet decoder via VIP flow control wrapper	
		input		stall_in,
		output	read,		
		input		[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_in, 		
		input		end_of_video,
		
		input		[15:0] width_in,
		input		[15:0] height_in,
		input		[3:0] interlaced_in,
		input		vip_ctrl_valid,
		
		// interface to VIP control packet encoder via VIP flow control wrapper	
		input		stall_out,		
		output	write,
		output [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_out,
		output	end_of_video_out,		
		
		output	reg [15:0] width_out,
		output	reg [15:0] height_out,
		output	reg [3:0] interlaced_out,		
		input		vip_ctrl_busy,
		output	reg vip_ctrl_send);
		
// internal flow controlled signals				
wire [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT : 0] data_int;
wire input_valid;
reg data_available;
reg [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT : 0] data_int_reg;
reg [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT : 0] data_out_reg;
				
		
/******************************************************************************/
/* Data processing of user algorithm starts here                              */
/******************************************************************************/

/*********************************************/
/* this example: RGB to greyscale conversion */
/*********************************************/

// Wires for inputs to grayscale_top
wire image_wr_en;
wire img_out_rd_en;
wire [23:0] image_din;

// Wires for outputs from grayscale_top
wire image_full;
wire img_out_empty;
wire [7:0] img_out_dout;

canny_top canny_top (
    .clock(clk),
    .reset(rst),
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
    .img_out_empty(img_out_empty),
    .img_out_rd_en(img_out_rd_en),
    .img_out_dout(img_out_dout)
);

// assign outputs
reg [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] output_data;  // algorithm output data
reg output_valid;
reg output_end_of_video;
wire output_ready; // [lucahhot]: Using this new signal to indicate that the grayscale_top module is ready to output data

// [lucahhot]: Assign output_ready when the grayscale_top module is not empty
assign output_ready = ~img_out_empty;
// [lucahhot]: If output_ready == 1'b1, then we can read from the output FIFO so assert img_out_rd_en
assign img_out_rd_en = output_ready;

always @(posedge clk or posedge rst)
	if (rst) begin
		output_data <= {(BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1){1'b0}};
		output_valid <= 1'b0;
	    output_end_of_video <= 1'b0;
	end else begin
        // [lucahhot]: We set output data to the output of the grayscale_top output FIFO (img_out_dout) and only when output_ready is high 
		output_data <= output_ready ? {img_out_dout, img_out_dout, img_out_dout} : output_data;
        // [lucahhot]: We set output_valid to output_ready (need the 1 cycle delay since output_data needs 1 cycle to get assigned with unblocking assignment)
		output_valid <= output_ready; 
        // [lucahhot]: This just passes the end_of_video signal through (there is no logic to modify it in this algorithm)
        // Only passes through when output_ready is working
	    output_end_of_video <= output_ready ? data_int[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT] : output_end_of_video;
	end	

/******************************************************************************/
/* End of user algorithm data processing                                      */
/******************************************************************************/

/******************************************************************************/
/* Start of flow control processing                                           */
/******************************************************************************/

// [lucahhot]: To request new data, doesn't necessarily mean we will since stall_in might be high (input is stalled)
// Only read in a new value if image_full == 1'b0 (meaning we have space to write new data into the grayscale_top module)
assign read = (~stall_out & ~image_full);

// [lucahhot]: To output data, we need to have valid data to output or have data available to output 
// I don't know why we also look at data_available since its just the same as output_valid but one cycle after stall_out and output_valid are high?
// Maybe this is in case there is a stall out in the previous cycle and we have yet to output data that has just been processed?
assign write = ( output_valid | data_available); 
	
// [lucahhot]: Same as read but only if input is not stalled (only when this is high can we take in new input data)
assign input_valid = (read & ~stall_in);

// [lucahhot]: Take in new input if input_valid == 1'b1 otherwise keep the old data
// From Github Copilot: The reason for concatenating end_of_video with data_in could be to include the end_of_video signal along with the data 
// for further processing. This way, the downstream logic can use the end_of_video signal to determine when the video data stream ends while processing data_in.
assign data_int = (input_valid) ? {end_of_video, data_in} : data_int_reg;

// [lucahhot]: Load in data_int into the grayscale_top module (input_valid already accounts for the input FIFO not being full)
assign image_wr_en = input_valid;
assign image_din = data_in;

// hold data if not writing or output stalled, otherwise assign internal data 
assign data_out = (output_valid | data_available) ? output_data : data_out_reg[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0];
assign end_of_video_out = (output_valid | data_available) ? output_end_of_video : data_out_reg[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT];

// register internal flow controlled signals	
always @(posedge clk or posedge rst)
	if (rst) begin
		data_int_reg <= {(BITS_PER_SYMBOL * SYMBOLS_PER_BEAT + 1){1'b0}};
		data_out_reg <= {(BITS_PER_SYMBOL * SYMBOLS_PER_BEAT + 1){1'b0}};
		data_available <= 1'b0;
	end
	else begin
		data_int_reg <= data_int;
		data_out_reg[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] <= data_out;
		data_out_reg[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT] <= end_of_video_out;
		data_available <= stall_out & (output_valid | data_available);
	end
			
/******************************************************************************/
/* End of flow control processing                                             */
/******************************************************************************/

// connect control signals	
always @(posedge clk or posedge rst)
	if (rst) begin
		width_out <= 16'd640;
		height_out <= 16'd480;
		interlaced_out <= 4'd0;
		vip_ctrl_send <= 1'b0;
	end
	else begin
		width_out <= vip_ctrl_valid ? width_in : width_out;
		height_out <= vip_ctrl_valid ? height_in : height_out;
		interlaced_out <= vip_ctrl_valid ? interlaced_in : interlaced_out;
		vip_ctrl_send <= vip_ctrl_valid & ~vip_ctrl_busy;
	end	
		 	 	 	
endmodule
		
					
			