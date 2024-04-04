module canny_edgedetect_top #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540,
    parameter FIFO_BUFFER_SIZE = 8
) (
    input logic         clock,
    input logic         reset,
    output logic        image_full,
    input logic         image_wr_en,
    input logic [23:0]  image_din,

    output logic        img_out_empty,
    input logic         img_out_rd_en,
    output logic [7:0]  img_out_dout
);

// Input wires to grayscale function

logic [23:0]    image_dout;
logic           image_empty;
logic           image_rd_en;

// Output wires from grayscale function to gaussian_blur FIFO
logic           gaussian_wr_en;
logic           gaussian_full;
logic [7:0]     gaussian_din;

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

// Output wires from sobel function to output FIFO
logic           img_out_wr_en;
logic           img_out_full;
logic [7:0]     img_out_din;

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
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

grayscale grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(image_rd_en),
    .in_empty(image_empty),
    .in_dout(image_dout),
    .out_wr_en(gaussian_wr_en),
    .out_full(gaussian_full),
    .out_din(gaussian_din)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
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

gaussian_blur #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) gaussian_inst(
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
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
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

sobel #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) sobel_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(sobel_rd_en),
    .in_empty(sobel_empty),
    .in_dout(sobel_dout),
    .out_wr_en(img_out_wr_en),
    .out_full(img_out_full),
    .out_din(img_out_din)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
) fifo_img_out_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(img_out_wr_en),
    .din(img_out_din),
    .full(img_out_full),
    .rd_clk(clock),
    .rd_en(img_out_rd_en),
    .dout(img_out_dout),
    .empty(img_out_empty)
);

endmodule