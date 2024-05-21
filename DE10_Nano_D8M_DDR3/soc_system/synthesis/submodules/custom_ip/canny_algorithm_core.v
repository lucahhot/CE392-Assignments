// example algorithm - to be replaced by user algorithm
// this algorithm turns RGB colors into greyscale
module canny_algorithm_core

	#(parameter BITS_PER_SYMBOL = 8,
		parameter SYMBOLS_PER_BEAT = 3) // only 1 symbol used as black/white
		
	(	input		clk,
		input		rst,
		
		// interface to VIP control packet decoder via VIP flow control wrapper	
		input		stall_in,
		output	reg read,		
		input		[BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_in, 		
		input		end_of_video,
		
		input		[15:0] width_in,
		input		[15:0] height_in,
		input		[3:0] interlaced_in,
		input		vip_ctrl_valid,
		
		// interface to VIP control packet encoder via VIP flow control wrapper	
		input		stall_out,		
		output	reg write,
		output 	reg [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_out,
		output	reg end_of_video_out,		
		
		output	reg [15:0] width_out,
		output	reg [15:0] height_out,
		output	reg [3:0] interlaced_out,		
		input		vip_ctrl_busy,
		output	reg vip_ctrl_send);
		
// Control packets always sent before data packet
// end_of_video --> next packet should be control packet?
	// wait for the pixels in the pipeline to finish executino before next control packet
	// end_of_video --> don't read next cycle until last pixel has been output
	//				--> if end_of_video_out == 1 --> read next control packet
						


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


// writing and reading at the same time as grayscale --> end_of_video should sync
// with output of the last pixel from grayscale!
// reg eov_wr_en;
wire eov_full;
reg eov_rd_en;
wire eov_empty;
wire eov_dout;

fifo #(
	.FIFO_DATA_WIDTH(1),
	.FIFO_BUFFER_SIZE(32)
) eov_fifo (
	.reset(rst),
	.wr_clk(clk),
	.wr_en(gs_image_wr_en),
	.din(end_of_video),
	.full(eov_full),
	.rd_clk(clk),
	.rd_en(gs_img_out_rd_en),
	.dout(eov_dout),
	.empty(eov_empty)
);

/******************************************************************************/
/* End of user algorithm data processing                                      */
/******************************************************************************/

/******************************************************************************/
/* Start of flow control processing                                           */
/******************************************************************************/

reg [1:0] state, next_state;
localparam INIT = 0, VID_DATA = 1, VID_DATA_END = 2;

always @(posedge clk) begin
	if (rst) begin
		state <= INIT;
	end else begin
		state <= next_state;
	end
end

always @(*) begin
	next_state = state;
	width_out = 16'd1920;
	height_out = 16'd1080;
	interlaced_out = 4'd0;
	vip_ctrl_send = 1'b0;

	read = 1'b0;
	write = 1'b0;

	end_of_video_out = 1'b0;
	data_out = 24'b0;

	gs_image_wr_en = 1'b0;
	gs_img_out_rd_en = 1'b0;

	case(state)
		INIT: begin
			// Wait for control packet to arrive (vip_ctrl_valid)
			// Output control packet data
			// Go to data processing stage
			read = ~vip_ctrl_busy & ~stall_in;
			if (vip_ctrl_valid) begin
				next_state = VID_DATA;
				width_out = width_in;
				height_out = height_in;
				interlaced_out = interlaced_in;
				vip_ctrl_send = ~vip_ctrl_busy;
			end else begin
				next_state = INIT;
				width_out = width_out;
				height_out = height_out;
				interlaced_out = interlaced_out;
				vip_ctrl_send = 1'b0;
			end
		end

		VID_DATA: begin
			if (end_of_video) begin
				next_state = VID_DATA_END;
			end else begin
				next_state = VID_DATA;
			end

			// INPUT
			read = ~stall_in & ~gs_image_full;
			if (~gs_image_full & ~stall_in) begin
				gs_image_wr_en = 1'b1;
			end else begin
				gs_image_wr_en = 1'b0;
			end

			// OUTPUT
			if (~gs_img_out_empty & ~stall_out) begin
				write = 1'b1;
				gs_img_out_rd_en = 1'b1;
				data_out = gs_img_out_dout;
				end_of_video_out = eov_dout;
			end else begin
				write = 1'b0;
				gs_img_out_rd_en = 1'b0;
				end_of_video_out = 1'b0;
			end
		end

		VID_DATA_END: begin
			// WAIT TO OUTPUT ALL PIXELS (end_of_video == 1)
			// after no pixels left in pipeline, transition to reading control signal
			if (~gs_img_out_empty & ~stall_out) begin
				write = 1'b1;
				gs_img_out_rd_en = 1'b1;
				data_out = gs_img_out_dout;
			end else begin
				write = 1'b0;
				gs_img_out_rd_en = 1'b0;
				data_out = data_out;
			end

			if (eov_dout) begin
				next_state = INIT;
			end else begin
				next_state = VID_DATA_END;
			end
		end

		default: begin
			data_out = 24'bX;
			next_state = INIT;
			width_out = 16'd1920;
			height_out = 16'd1080;
			interlaced_out = 4'd0;
			vip_ctrl_send = 1'b0;

			read = 1'b0;
			write = 1'b0;

			end_of_video_out = 1'b0;
			data_out = 24'b0;

			gs_image_wr_en = 1'b0;
			gs_img_out_rd_en = 1'b0;
		end
		
	endcase
end



			
/******************************************************************************/
/* End of flow control processing                                             */
/******************************************************************************/
		 	 	 	
endmodule
		
					
			