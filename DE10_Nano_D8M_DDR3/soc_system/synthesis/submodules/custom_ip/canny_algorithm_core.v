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
		output  [BITS_PER_SYMBOL * SYMBOLS_PER_BEAT - 1:0] data_out,
		output  end_of_video_out,		
		
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
						
wire input_valid;
reg output_valid;
reg data_available;
reg end_of_video_reg;

/******************************************************************************/
/* Data processing of user algorithm starts here                              */
/******************************************************************************/

/*********************************************/
/* this example: RGB to greyscale conversion */
/*********************************************/

wire gs_image_full;
wire gs_image_wr_en;
wire gs_img_out_empty;
wire gs_img_out_rd_en;
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

/******************************************************************************/
/* End of user algorithm data processing                                      */
/******************************************************************************/

/******************************************************************************/
/* Start of flow control processing                                           */
/******************************************************************************/

// input control signals
assign read = ~stall_out & ~gs_image_full;
assign input_valid = (read & ~stall_in) ? 1'b1 : 1'b0;
assign gs_image_wr_en = (read & ~stall_in) ? 1'b1 : 1'b0;

// output control signals
assign gs_img_out_rd_en = output_valid;
assign write = (output_valid | data_available);
assign data_out = {gs_img_out_dout, gs_img_out_dout, gs_img_out_dout};
assign end_of_video_out = (output_valid | data_available) ? end_of_video_reg : 1'b0;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		output_valid <= 1'b0;
		data_available <= 1'b0;
		// input_valid <= 1'b0;
		// gs_image_wr_en <= 1'b0;
		end_of_video_reg <= 1'b0;
	end else begin
		output_valid <= ~gs_img_out_empty;
		data_available <= stall_out & (output_valid | data_available);
		// input_valid <= (read & ~stall_in);
		// gs_image_wr_en <= (read & ~stall_in);
		end_of_video_reg <= (input_valid) ? end_of_video : end_of_video_reg;
	end
end


// end_of_video handler: if EOV signal ==> wait for out fifo to empty
	// reg [0:0] state, next_state;
	// localparam EOV_WAIT = 0, EOV = 1;

	// always @(posedge clk) begin
	// 	if (rst) begin
	// 		state <= EOV_WAIT;
	// 	end else begin
	// 		state <= next_state;
	// 	end
	// end

	// always @(*) begin
	// 	end_of_video_out = 1'b0;
	// 	next_state = state;

	// 	case(state)
	// 		EOV_WAIT: begin
	// 			end_of_video_out = 1'b0;
	// 			if (end_of_video) begin
	// 				next_state = EOV;
	// 			end else begin
	// 				next_state = EOV_WAIT;
	// 			end
	// 		end

	// 		EOV: begin
	// 			next_state = EOV;
	// 			if (gs_img_out_empty) begin
	// 				end_of_video_out = 1'b1;
	// 			end else begin
	// 				end_of_video_out = 1'b0;
	// 			end
	// 		end

	// 		default: begin
	// 			next_state = EOV_WAIT;
	// 			end_of_video_out = 1'b0;
	// 		end
			
	// 	endcase
	// end



			
/******************************************************************************/
/* End of flow control processing                                             */
/******************************************************************************/
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
		
					
			