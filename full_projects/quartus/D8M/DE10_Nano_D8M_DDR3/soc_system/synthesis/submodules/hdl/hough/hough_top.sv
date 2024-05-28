

module hough_top #(
    // Image dimensions
    parameter WIDTH = 512,
    parameter HEIGHT = 288,
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

// DEFINE ALL PARAMETERS HERE
localparam IMAGE_SIZE = WIDTH*HEIGHT;
localparam STARTING_X = 0;
localparam STARTING_Y = 0;
localparam ENDING_X = WIDTH;
localparam ENDING_Y = HEIGHT;

localparam START_THETA = 20;
localparam THETAS = 160;
localparam RHOS = 588;
localparam RHO_RANGE = RHOS * 2;

localparam THETA_UNROLL = 16;
localparam THETA_DIVIDE_BITS = 4;
localparam THETA_FACTOR = 9;

localparam ACCUM_BUFF_WIDTH = 8;
localparam THETA_BITS = 9;
localparam NUM_LANES = 100; // TUNE THIS
localparam HOUGH_TRANSFORM_THRESHOLD = 100; // TUNE THIS

localparam BITS = 8;
localparam TRIG_DATA_SIZE = 12;

localparam K_START = -1000; // TUNE THIS
localparam K_END = 1000;
localparam OFFSET = 8;

// Trig values to be used by both hough and highlight as parameters
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{0, 4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 48, 53, 57, 61, 66, 70, 74, 79, 83, 87, 91, 95, 100, 104, 108, 112, 116, 120, 124, 128, 131, 135, 139, 143, 146, 150, 154, 157, 161, 164, 167, 171, 174, 177, 181, 184, 187, 190, 193, 196, 198, 201, 204, 207, 209, 212, 214, 217, 219, 221, 223, 226, 228, 230, 232, 233, 235, 237, 238, 240, 242, 243, 244, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255, 255, 256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4};
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4, 0, -4, -8, -13, -17, -22, -26, -31, -35, -40, -44, -48, -53, -57, -61, -66, -70, -74, -79, -83, -87, -91, -95, -100, -104, -108, -112, -116, -120, -124, -128, -131, -135, -139, -143, -146, -150, -154, -157, -161, -164, -167, -171, -174, -177, -181, -184, -187, -190, -193, -196, -198, -201, -204, -207, -209, -212, -214, -217, -219, -221, -223, -226, -228, -230, -232, -233, -235, -237, -238, -240, -242, -243, -244, -246, -247, -248, -249, -250, -251, -252, -252, -253, -254, -254, -255, -255, -255, -255, -255};

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

// BRAM wires from hysteresis loader to hysteresis BRAM
logic                           hysteresis_bram_wr_en;
logic [7:0]                     hysteresis_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  hysteresis_bram_wr_addr;
logic [$clog2(IMAGE_SIZE)-1:0]  hysteresis_bram_rd_addr;
logic [7:0]                     hysteresis_bram_rd_data;

// Image BRAM wires (will only be REDUCED_IMAGE_SIZE big)
logic                           image_bram_wr_en;
logic [7:0]                     image_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_wr_addr;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_rd_addr;
logic [7:0]                     image_bram_rd_data;

// Start/Stop signals
logic hough_start;
logic hough_done_internal;

// Wires from highlight module to highlight FIFO
logic [7:0] highlight_din;
logic highlight_full;
logic highlight_wr_en;

logic signed [15:0]     left_rho_out_internal;
logic signed [15:0]     right_rho_out_internal;
logic [THETA_BITS-1:0]  left_theta_out_internal;
logic [THETA_BITS-1:0]  right_theta_out_internal;

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
//     .rd_en(sobel_rd_en),
//     .dout(sobel_dout),
//     .empty(sobel_empty)
//     // .rd_en(img_out_rd_en),
//     // .dout(img_out_dout),
//     // .empty(img_out_empty)
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
    // .rd_en(img_out_rd_en),
    // .dout(img_out_dout),
    // .empty(img_out_empty)
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
    // .rd_en(img_out_rd_en),
    // .dout(img_out_dout),
    // .empty(img_out_empty)
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
    .bram_out_wr_en(hysteresis_bram_wr_en),
    .bram_out_wr_addr(hysteresis_bram_wr_addr),
    .bram_out_wr_data(hysteresis_bram_wr_data),
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

bram #(
    .BRAM_DATA_WIDTH(8),
    .IMAGE_SIZE(IMAGE_SIZE)
) image_bram_inst (
    .clock(clock),
    .rd_addr(image_bram_rd_addr),
    .wr_addr(image_bram_wr_addr),
    .wr_en(image_bram_wr_en),
    .wr_data(image_bram_wr_data),
    .rd_data(image_bram_rd_data)
);

hough #(
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y),
    .REDUCED_WIDTH(WIDTH),
    .REDUCED_HEIGHT(HEIGHT),
    .START_THETA(START_THETA),
    .THETAS(THETAS),
    .RHOS(RHOS),
    .RHO_RANGE(RHO_RANGE),
    .THETA_UNROLL(THETA_UNROLL),
    .THETA_DIVIDE_BITS(THETA_DIVIDE_BITS),
    .THETA_FACTOR(THETA_FACTOR),
    .ACCUM_BUFF_WIDTH(ACCUM_BUFF_WIDTH),
    .THETA_BITS(THETA_BITS),
    .NUM_LANES(NUM_LANES),
    .HOUGH_TRANSFORM_THRESHOLD(HOUGH_TRANSFORM_THRESHOLD),
    .TRIG_DATA_SIZE(TRIG_DATA_SIZE),
    .SIN_QUANTIZED(SIN_QUANTIZED),
    .COS_QUANTIZED(COS_QUANTIZED)
) hough_inst (
    .clock(clock),
    .reset(reset),
    .start(hough_start),
    .hysteresis_bram_rd_data(hysteresis_bram_rd_data),
    .hysteresis_bram_rd_addr(hysteresis_bram_rd_addr),
    .highlight_din(highlight_din),
    .highlight_wr_en(highlight_wr_en),
    .highlight_full(highlight_full),
    .hough_done(hough_done_internal),
    .left_rho_out(left_rho_out_internal),
    .right_rho_out(right_rho_out_internal),
    .left_theta_out(left_theta_out_internal),
    .right_theta_out(right_theta_out_internal)
);

// highlight #(
//     .STARTING_X(STARTING_X),
//     .STARTING_Y(STARTING_Y),
//     .ENDING_X(ENDING_X),
//     .ENDING_Y(ENDING_Y),
//     .REDUCED_WIDTH(WIDTH),
//     .REDUCED_HEIGHT(HEIGHT),
//     .THETA_BITS(THETA_BITS),
//     .BITS(BITS),
//     .TRIG_DATA_SIZE(TRIG_DATA_SIZE),
//     .K_START(K_START),
//     .K_END(K_END),
//     .OFFSET(OFFSET),
//     .SIN_QUANTIZED(SIN_QUANTIZED),
//     .COS_QUANTIZED(COS_QUANTIZED)
// ) highlight_inst (
//     .clock(clock),
//     .reset(reset),
//     .hough_done(hough_done_internal),
//     .left_rho_in(left_rho_out_internal),
//     .right_rho_in(right_rho_out_internal),
//     .left_theta_in(left_theta_out_internal),
//     .right_theta_in(right_theta_out_internal),
//     .bram_out_wr_en(image_bram_wr_en),
//     .bram_out_wr_addr(image_bram_wr_addr),
//     .bram_out_wr_data(image_bram_wr_data),
//     .bram_out_rd_addr(image_bram_rd_addr),
//     .bram_out_rd_data(image_bram_rd_data),
//     .highlight_din(highlight_din),
//     .highlight_wr_en(highlight_wr_en),
//     .highlight_full(highlight_full)
// );

fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) fifo_highlight_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(highlight_wr_en),
    .din(highlight_din),
    .full(highlight_full),
    .rd_clk(clock),
    .rd_en(img_out_rd_en),
    .dout(img_out_dout),
    .empty(img_out_empty)
);



endmodule