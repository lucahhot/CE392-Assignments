// example algorithm - to be replaced by user algorithm
// this algorithm turns RGB colors into greyscale
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
		output 	[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_out,
		output	end_of_video_out,		
		
		output	reg [15:0] width_out,
		output	reg [15:0] height_out,
		output	reg [3:0] interlaced_out,		
		input		vip_ctrl_busy,
		output	reg vip_ctrl_send);
		
// internal flow controlled signals	
reg output_valid;			
						
/******************************************************************************/
/* Data processing of user algorithm starts here                              */
/******************************************************************************/

/*********************************************/
/* this example: RGB to greyscale conversion */
/*********************************************/

wire gs_image_full;
reg gs_image_wr_en;
wire gs_img_out_empty;
reg gs_img_out_rd_en;
wire [7:0] gs_img_out_dout;

grayscale_top #(
	.WIDTH(1920),
	.HEIGHT(1080),
	.FIFO_BUFFER_SIZE(32)
) grayscale_top_inst (
	.clock(clk),
	.reset(rst),
	.image_full(gs_image_full),
	.image_wr_en(gs_image_wr_en),
	.image_din(data_in),
	.img_out_empty(gs_img_out_empty),
	.img_out_rd_en(gs_img_out_rd_en),
	.img_out_dout(gs_img_out_dout)
);

fifo #(
	.FIFO_BUFFER_SIZE(),
	.FIFO_DATA_WIDTH(),
) width_fifo (
	.reset(),
	.wr_clk(),
	.wr_en(),
	.din(),
	.full(),
	.rd_clk(),
	.rd_en(),
	.dout(),
	.empty()
);

fifo #(
	.FIFO_BUFFER_SIZE(),
	.FIFO_DATA_WIDTH(),
) height_fifo (
	.reset(),
	.wr_clk(),
	.wr_en(),
	.din(),
	.full(),
	.rd_clk(),
	.rd_en(),
	.dout(),
	.empty()
);

fifo #(
	.FIFO_BUFFER_SIZE(),
	.FIFO_DATA_WIDTH(),
) interlaced_fifo (
	.reset(),
	.wr_clk(),
	.wr_en(),
	.din(),
	.full(),
	.rd_clk(),
	.rd_en(),
	.dout(),
	.empty()
);


wire vip_ctrl_valid_dout;
reg vip_ctrl_rd_en, vip_ctrl_wr_en;
fifo #(
	.FIFO_BUFFER_SIZE(32),
	.FIFO_DATA_WIDTH(1),
) vip_ctrl_fifo (
	.reset(rst),
	.wr_clk(clk),
	.wr_en(vip_ctrl_wr_en),
	.din(vip_ctrl_valid),
	.full(),
	.rd_clk(),
	.rd_en(vip_ctrl_rd_en),
	.dout(vip_ctrl_valid_dout),
	.empty()
);


/******************************************************************************/
/* End of user algorithm data processing                                      */
/******************************************************************************/

/******************************************************************************/
/* Start of flow control processing                                           */
/******************************************************************************/
// input control signals
assign read = ~gs_image_full;		// read whenever fifo is not full
assign input_valid = (read & ~stall_in);
always @(posedge clk or posedge rst)
	if (rst) begin
		gs_image_wr_en <= 1'b0;
		vip_ctrl_wr_en <= 1'b0;
	end else begin
		gs_image_wr_en <= (read & input_valid) ? 1'b1: 1'b0;
		
		// Hopefully vip_ctrl_valid and input_valid are high at the same time?
		if (read & vip_ctrl_valid) begin
			vip_ctrl_wr_en = 1'b1;
		end else begin
			vip_ctrl_wr_en = 1'b0;
		end
	end

// output control signals
always @(posedge clk or posedge rst)
	if (rst) begin
		gs_img_out_rd_en <= 1'b0;
		output_valid <= 1'b0;
		data_out <= 24'd0;
		vip_ctrl_rd_en <= 1'b0;
	end else begin
		if (gs_img_out_empty) begin
			gs_img_out_rd_en <= 1'b0;
			output_valid <= 1'b0;
			vip_ctrl_send <= 1'b0;
			vip_ctrl_rd_en <= 1'b0;
		end else begin
			gs_img_out_rd_en <= 1'b1;
			output_valid <= 1'b1;
			data_out <= {gs_img_out_dout, gs_img_out_dout, gs_img_out_dout};
			vip_ctrl_send <= vip_ctrl_valid_dout & ~vip_ctrl_busy;
			vip_ctrl_rd_en = 1'b1;
		end
	end



			
/******************************************************************************/
/* End of flow control processing                                             */
/******************************************************************************/

// connect control signals	
always @(posedge clk or posedge rst)
	if (rst) begin
		width_out <= 16'd1920;
		height_out <= 16'd1080;
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
		
					
			