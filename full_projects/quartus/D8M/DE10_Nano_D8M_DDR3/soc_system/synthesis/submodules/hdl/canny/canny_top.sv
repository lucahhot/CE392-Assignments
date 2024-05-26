

module canny_top #(
    // Image dimensions
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter FIFO_BUFFER_SIZE = 8
)(
    input   logic           clock,
    input   logic           reset,
    // IMAGE INPUT
    output  logic           image_full,
    input   logic           image_wr_en,
    input   logic [23:0]    image_din,
    // IMAGE OUTPUT
    input   logic           img_out_rd_en,
    output  logic           img_out_empty,
    output  logic [7:0]     img_out_dout
);

// Input wires to grayscale function from image FIFO
logic [23:0]    grayscale_dout;
logic           grayscale_empty;
logic           grayscale_rd_en;

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

// Output wires from hysteresis function to image output FIFO
logic           img_out_wr_en;
logic           img_out_full;
logic [7:0]     img_out_din;

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
    .rd_en(grayscale_rd_en),
    .dout(grayscale_dout),
    .empty(grayscale_empty)
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
    .rd_en(sobel_rd_en),
    .dout(sobel_dout),
    .empty(sobel_empty)
    // .rd_en(img_out_rd_en),
    // .dout(img_out_dout),
    // .empty(img_out_empty)
);

// gaussian_blur #(
//     .WIDTH(WIDTH),
//     .HEIGHT(HEIGHT)
// ) gaussian_inst(
//     .clock(clock),
//     .reset(reset),
//     .in_rd_en(gaussian_rd_en),
//     .in_empty(gaussian_empty),
//     .in_dout(gaussian_dout),
//     .out_wr_en(sobel_wr_en),
//     .out_full(sobel_full),
//     .out_din(sobel_din)
// );

// fifo #(
//     .FIFO_DATA_WIDTH(8),
//     .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
// ) fifo_sobel_inst (
//     .reset(reset),
//     .wr_clk(clock),
//     .wr_en(sobel_wr_en),
//     .din(sobel_din),
//     .full(sobel_full),
//     .rd_clk(clock),
//     // .rd_en(sobel_rd_en),
//     // .dout(sobel_dout),
//     // .empty(sobel_empty)
//     .rd_en(img_out_rd_en),
//     .dout(img_out_dout),
//     .empty(img_out_empty)
// );

sobel #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) sobel_inst(
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
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
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

non_maximum_suppressor #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) nms_inst(
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
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
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

hysteresis #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) hysteresis_inst (
    .clock(clock),
    .reset(reset),
    .in_rd_en(hysteresis_rd_en),
    .in_empty(hysteresis_empty),
    .in_dout(hysteresis_dout),
    .out_wr_en(img_out_wr_en),
    .out_full(img_out_full),
    .out_din(img_out_din)
);

fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
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