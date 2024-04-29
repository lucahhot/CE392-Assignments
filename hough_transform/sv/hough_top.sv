`include "globals.sv"

module hough_top (
    input   logic           clock,
    input   logic           reset,
    // IMAGE INPUT
    output  logic           image_full,
    input   logic           image_wr_en,
    input   logic [23:0]    image_din,
    // MASK INPUT
    output  logic           mask_full,
    input   logic           mask_wr_en,
    input   logic [23:0]    mask_din,
    // DONE signals
    output logic accum_buff_done,
    output logic hough_done,
    // LANE OUTPUTS
    output logic [ACCUM_BUFF_WIDTH-1:0] output_data,
    output logic signed [15:0] left_rho_out,
    output logic signed [15:0] right_rho_out,
    output logic [THETA_BITS-1:0] left_theta_out,
    output logic [THETA_BITS-1:0] right_theta_out
);

// Input wires to image_loader
logic [23:0]    image_dout;
logic           image_empty;
logic           image_rd_en;

// Output wires from image_loader to grayscale FIFO
logic           grayscale_wr_en;
logic           grayscale_full;
logic [23:0]    grayscale_din;

// Output wires from image_loader to image_BRAM
logic                           image_bram_wr_en;
logic [23:0]                    image_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_wr_addr;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_rd_addr;
logic [23:0]                    image_bram_rd_data;

// Input wires to grayscale function
logic [23:0]    grayscale_dout;
logic           grayscale_empty;
logic           grayscale_rd_en;

// Input wires to grayscale function for mask
logic [23:0]    mask_dout;
logic           mask_empty;
logic           mask_rd_en;

// Output wires from grayscale function to gaussian_blur FIFO
logic           gaussian_wr_en;
logic           gaussian_full;
logic [7:0]     gaussian_din;

// Output wires from grayscale_mask function to mask_bram
logic                           mask_bram_wr_en;
logic [7:0]                     mask_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  mask_bram_wr_addr;
logic [$clog2(IMAGE_SIZE)-1:0]  mask_bram_rd_addr;
logic [7:0]                     mask_bram_rd_data;

// Input wires to gaussian_blur function
logic [7:0]     gaussian_dout;
logic           gaussian_empty;
logic           gaussian_rd_en;

// Output wires from gaussian_blur function to sobel FIFO
logic           sobel_wr_en;
logic           sobel_full;
logic [7:0]     sobel_din;

// Input wires to sobel function
logic [7:0]     sobel_dout;
logic           sobel_empty;
logic           sobel_rd_en;

// Output wires from sobel function to NMS FIFO
logic           nms_wr_en;
logic           nms_full;
logic [7:0]     nms_din;

// Input wires to NMS function
logic [7:0]     nms_dout;
logic           nms_empty;
logic           nms_rd_en;

// Output wires from NMS function to hysteresis FIFO
logic           hysteresis_wr_en;
logic           hysteresis_full;
logic [7:0]     hysteresis_din;

// Input wires to hysteresis function
logic [7:0]     hysteresis_dout;
logic           hysteresis_empty;
logic           hysteresis_rd_en;

// Output wires from hysteresis function to hysteresis_bram
logic                           hysteresis_bram_wr_en;
logic [7:0]                     hysteresis_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  hysteresis_bram_wr_addr;
logic [$clog2(IMAGE_SIZE)-1:0]  hysteresis_bram_rd_addr;
logic [7:0]                     hysteresis_bram_rd_data;
logic                           hough_start;

fifo #(
    .FIFO_DATA_WIDTH(24),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_image_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(image_wr_en),
    .din(image_din),
    .full(image_full),
    .rd_clk(clock),
    .rd_en(image_rd_en),
    .dout(image_dout),
    .empty(image_empty)
);

image_loader image_loader_inst (
    .clock(clock),
    .reset(reset),
    .in_rd_en(image_rd_en),
    .in_empty(image_empty),
    .in_dout(image_dout),
    .fifo_out_wr_en(grayscale_wr_en),
    .fifo_out_full(grayscale_full),
    .fifo_out_din(grayscale_din),
    .bram_out_wr_en(image_bram_wr_en),
    .bram_out_wr_addr(image_bram_wr_addr),
    .bram_out_wr_data(image_bram_wr_data)
);

bram #(
    .BRAM_DATA_WIDTH(24),
    .IMAGE_SIZE(IMAGE_SIZE)
) image_bram_inst (
    .clock(clock),
    .rd_addr(image_bram_rd_addr),
    .wr_addr(image_bram_wr_addr),
    .wr_en(image_bram_wr_en),
    .wr_data(image_bram_wr_data),
    .rd_data(image_bram_rd_data)
);

fifo #(
    .FIFO_DATA_WIDTH(24),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_grayscale_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(grayscale_wr_en),
    .din(grayscale_din),
    .full(grayscale_full),
    .rd_clk(clock),
    .rd_en(grayscale_rd_en),
    .dout(grayscale_dout),
    .empty(grayscale_empty)
);

fifo #(
    .FIFO_DATA_WIDTH(24),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_mask_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(mask_wr_en),
    .din(mask_din),
    .full(mask_full),
    .rd_clk(clock),
    .rd_en(mask_rd_en),
    .dout(mask_dout),
    .empty(mask_empty)
);

grayscale img_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(grayscale_rd_en),
    .in_empty(grayscale_empty),
    .in_dout(grayscale_dout),
    .out_wr_en(gaussian_wr_en),
    .out_full(gaussian_full),
    .out_din(gaussian_din)
);

grayscale_mask mask_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(mask_rd_en),
    .in_empty(mask_empty),
    .in_dout(mask_dout),
    .out_wr_en(mask_bram_wr_en),
    .out_wr_addr(mask_bram_wr_addr),
    .out_wr_data(mask_bram_wr_data)
);

bram #(
    .BRAM_DATA_WIDTH(8),
    .IMAGE_SIZE(IMAGE_SIZE)
) mask_bram_inst (
    .clock(clock),
    .rd_addr(mask_bram_rd_addr),
    .wr_addr(mask_bram_wr_addr),
    .wr_en(mask_bram_wr_en),
    .wr_data(mask_bram_wr_data),
    .rd_data(mask_bram_rd_data)
);

fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_gaussian_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(gaussian_wr_en),
    .din(gaussian_din),
    .full(gaussian_full),
    .rd_clk(clock),
    .rd_en(gaussian_rd_en),
    .dout(gaussian_dout),
    .empty(gaussian_empty)
);

gaussian_blur gaussian_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(gaussian_rd_en),
    .in_empty(gaussian_empty),
    .in_dout(gaussian_dout),
    .out_wr_en(sobel_wr_en),
    .out_full(sobel_full),
    .out_din(sobel_din)
);

fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_sobel_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(sobel_wr_en),
    .din(sobel_din),
    .full(sobel_full),
    .rd_clk(clock),
    .rd_en(sobel_rd_en),
    .dout(sobel_dout),
    .empty(sobel_empty)
);

sobel sobel_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(sobel_rd_en),
    .in_empty(sobel_empty),
    .in_dout(sobel_dout),
    .out_wr_en(nms_wr_en),
    .out_full(nms_full),
    .out_din(nms_din)
);

fifo #(
    .FIFO_DATA_WIDTH(8)
) fifo_nms_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(nms_wr_en),
    .din(nms_din),
    .full(nms_full),
    .rd_clk(clock),
    .rd_en(nms_rd_en),
    .dout(nms_dout),
    .empty(nms_empty)
);

non_maximum_suppressor nms_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(nms_rd_en),
    .in_empty(nms_empty),
    .in_dout(nms_dout),
    .out_wr_en(hysteresis_wr_en),
    .out_full(hysteresis_full),
    .out_din(hysteresis_din)
);

fifo #(
    .FIFO_DATA_WIDTH(8)
) fifo_hysteresis_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(hysteresis_wr_en),
    .din(hysteresis_din),
    .full(hysteresis_full),
    .rd_clk(clock),
    .rd_en(hysteresis_rd_en),
    .dout(hysteresis_dout),
    .empty(hysteresis_empty)
);

hysteresis hysteresis_inst (
    .clock(clock),
    .reset(reset),
    .in_rd_en(hysteresis_rd_en),
    .in_empty(hysteresis_empty),
    .in_dout(hysteresis_dout),
    .out_wr_en(hysteresis_bram_wr_en),
    .out_wr_addr(hysteresis_bram_wr_addr),
    .out_wr_data(hysteresis_bram_wr_data),
    .hough_start(hough_start)
);

bram #(
    .BRAM_DATA_WIDTH(8),
    .IMAGE_SIZE(IMAGE_SIZE)
) hysteresis_bram_inst (
    .clock(clock),
    .rd_addr(hysteresis_bram_rd_addr),
    .wr_addr(hysteresis_bram_wr_addr),
    .wr_en(hysteresis_bram_wr_en),
    .wr_data(hysteresis_bram_wr_data),
    .rd_data(hysteresis_bram_rd_data)
);

hough hough_inst (
    .clock(clock),
    .reset(reset),
    .start(hough_start),
    .hysteresis_bram_rd_data(hysteresis_bram_rd_data),
    .hysteresis_bram_rd_addr(hysteresis_bram_rd_addr),
    .mask_bram_rd_data(mask_bram_rd_data),
    .mask_bram_rd_addr(mask_bram_rd_addr),
    .accum_buff_done(accum_buff_done),
    .hough_done(hough_done),
    .output_data(output_data),
    .left_rho_out(left_rho_out),
    .right_rho_out(right_rho_out),
    .left_theta_out(left_theta_out),
    .right_theta_out(right_theta_out)
);

endmodule