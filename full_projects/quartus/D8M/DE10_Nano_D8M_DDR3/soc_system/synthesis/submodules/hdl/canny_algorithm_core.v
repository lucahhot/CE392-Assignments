
// Same as user_algorithm_core but using our own grayscale modules instead of the RGB to grayscale conversion
// that the original project used. This will allow us to input our entire canny pipeline here too

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

// Registers for outputs from grayscale_top
reg image_full;
reg img_out_empty;
reg [7:0] img_out_dout;

grayscale_top grayscale_top_inst (
    .clock(clk),
    .reset(rst),
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
    .img_out_empty(img_out_empty),
    .img_out_rd_en(img_out_rd_en),
    .img_out_dout(img_out_dout)
)

// assign outputs
reg [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] output_data;  // algorithm output data
reg output_valid;
reg output_end_of_video;

always @(posedge clk or posedge rst)
	if (rst) begin
		output_data <= {(BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1){1'b0}};
		output_valid <= 1'b0;
	  output_end_of_video <= 1'b0;
	end else begin
		output_data <= input_valid ? {grey_result, grey_result, grey_result} : output_data;
		output_valid <= input_valid; // one clock cycle latency in this algorithm
	  output_end_of_video <= input_valid ? data_int[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT] : output_end_of_video;
	end	

/******************************************************************************/
/* End of user algorithm data processing                                      */
/******************************************************************************/

/******************************************************************************/
/* Start of flow control processing                                           */
/******************************************************************************/

assign read = ~stall_out; 

assign write = ( output_valid | data_available); 
	
assign input_valid = (read & ~stall_in);

assign data_int = (input_valid) ? {end_of_video, data_in} : data_int_reg;

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
		
					
			