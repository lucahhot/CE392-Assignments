
// Test hough_top module takes an image of hysteresis, writes it into BRAM, and uses that to perform the Hough Transform

module hough_top #(
    // Image dimensions
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter IMAGE_SIZE = WIDTH * HEIGHT, // 921600
    parameter FIFO_BUFFER_SIZE = 8,

    // Reduced image dimensions
    parameter STARTING_X = 0,
    parameter STARTING_Y = 0,
    parameter ENDING_X = 512,
    parameter ENDING_Y = 288,

    parameter REDUCED_WIDTH = ENDING_X - STARTING_X,
    parameter REDUCED_HEIGHT = ENDING_Y - STARTING_Y, 
    parameter REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT, 

    parameter START_THETA = 20, // Start theta instead of default 0
    parameter THETAS = 160, // Reducing our theta range to save cycles and memory
    parameter RHOS = 588, // ceil(sqrt(REDUCED_WIDTH^2 + REDUCED_HEIGHT^2)) = 588
    parameter RHO_RANGE = 2*RHOS, 

    // Unroll factor for the accumulation stage (the theta loop)
    parameter THETA_UNROLL = 16,
    parameter THETA_DIVIDE_BITS = 4, // So that we don't have to divide by a non-power of 2 number (this means THEAT_UNROLL must be a power of 2)
    parameter THETA_FACTOR = 9, // ceil((THETAS-START_THETA)/16) = 10 (this is necessary if THETAS%THETA_UNROLL != 0), also reducing our theta range to 10 - 170 to save BRAM and cycles

    // Accum_buff BRAM width (was set to 16 in the original C code given but we can reduce to 8 bits)
    // It just has to be at least wide enough to go until HOUGH_TRANSFORM_THRESHOLD
    parameter ACCUM_BUFF_WIDTH = 8,

    // Theta bits (includes an extra bit just so we can always treat thetas as a signed number even though it'll always be positive)
    parameter THETA_BITS = 9,
    // Lane selection constants
    parameter NUM_LANES = 100,
    parameter HOUGH_TRANSFORM_THRESHOLD = 150,

    // Quantization constants
    parameter BITS = 8,
    parameter TRIG_DATA_SIZE = 12
)(
    input   logic           clock,
    input   logic           reset,

    // HYSTERESIS INPUT
    output  logic           hysteresis_full,
    input   logic           hysteresis_wr_en,
    input   logic [23:0]    hysteresis_din,

    // LANE OUTPUTS (for debugging)
    output  logic signed [15:0]     left_rho_out,
    output  logic signed [15:0]     right_rho_out,
    output  logic [THETA_BITS-1:0]  left_theta_out,
    output  logic [THETA_BITS-1:0]  right_theta_out,
    output  logic                   hough_done,    

    // HIGHILIGHT OUTPUT
    output  logic [7:0]     highlight_dout,
    output  logic           highlight_empty,
    input   logic           highlight_rd_en
);

// K_START and K_END parameters
localparam K_START = -1000;
localparam K_END = 1000;

// Trig values to be used by both hough and highlight as parameters
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{0, 4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 48, 53, 57, 61, 66, 70, 74, 79, 83, 87, 91, 95, 100, 104, 108, 112, 116, 120, 124, 128, 131, 135, 139, 143, 146, 150, 154, 157, 161, 164, 167, 171, 174, 177, 181, 184, 187, 190, 193, 196, 198, 201, 204, 207, 209, 212, 214, 217, 219, 221, 223, 226, 228, 230, 232, 233, 235, 237, 238, 240, 242, 243, 244, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255, 255, 256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4};
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4, 0, -4, -8, -13, -17, -22, -26, -31, -35, -40, -44, -48, -53, -57, -61, -66, -70, -74, -79, -83, -87, -91, -95, -100, -104, -108, -112, -116, -120, -124, -128, -131, -135, -139, -143, -146, -150, -154, -157, -161, -164, -167, -171, -174, -177, -181, -184, -187, -190, -193, -196, -198, -201, -204, -207, -209, -212, -214, -217, -219, -221, -223, -226, -228, -230, -232, -233, -235, -237, -238, -240, -242, -243, -244, -246, -247, -248, -249, -250, -251, -252, -252, -253, -254, -254, -255, -255, -255, -255, -255};

// Input wires to hyesteresis loader
logic [23:0]    hysteresis_dout;
logic           hysteresis_empty;
logic           hysteresis_rd_en;

// BRAM wires from hysteresis loader to hysteresis BRAM
logic                                   hysteresis_bram_wr_en;
logic [7:0]                             hysteresis_bram_wr_data;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  hysteresis_bram_wr_addr;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  hysteresis_bram_rd_addr;
logic [7:0]                             hysteresis_bram_rd_data;
logic                                   hysteresis_bram_rd_en;

// Image BRAM wires (will only be REDUCED_IMAGE_SIZE big)
logic                                   image_bram_wr_en;
logic [7:0]                             image_bram_wr_data;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  image_bram_wr_addr;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  image_bram_rd_addr;
logic [7:0]                             image_bram_rd_data;
logic                                   image_bram_rd_en;

// Start/Stop signals
logic hough_start;
logic hough_done_internal;
assign hough_done = hough_done_internal;

// LANE OUTPUTS
logic signed [15:0] left_rho_out_internal;
logic signed [15:0] right_rho_out_internal;
logic [THETA_BITS-1:0] left_theta_out_internal;
logic [THETA_BITS-1:0] right_theta_out_internal;

assign left_rho_out = left_rho_out_internal;
assign right_rho_out = right_rho_out_internal;
assign left_theta_out = left_theta_out_internal;
assign right_theta_out = right_theta_out_internal;

// Wires from highlight module to highlight FIFO
logic [7:0] highlight_din;
logic highlight_full;
logic highlight_wr_en;

fifo #(
    .FIFO_DATA_WIDTH(24),
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

hysteresis_loader #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y),
    .REDUCED_IMAGE_SIZE(REDUCED_IMAGE_SIZE)
) hysteresis_loader_inst (
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
    .IMAGE_SIZE(REDUCED_IMAGE_SIZE)
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
    .IMAGE_SIZE(REDUCED_IMAGE_SIZE)
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
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
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
    .hough_done(hough_done_internal),
    .left_rho_out(left_rho_out_internal),
    .right_rho_out(right_rho_out_internal),
    .left_theta_out(left_theta_out_internal),
    .right_theta_out(right_theta_out_internal)
);

highlight #(
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y),
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .THETA_BITS(THETA_BITS),
    .BITS(BITS),
    .TRIG_DATA_SIZE(TRIG_DATA_SIZE),
    .K_START(K_START),
    .K_END(K_END),
    .OFFSET(8),
    .SIN_QUANTIZED(SIN_QUANTIZED),
    .COS_QUANTIZED(COS_QUANTIZED)
) highlight_inst (
    .clock(clock),
    .reset(reset),
    .hough_done(hough_done_internal),
    .left_rho_in(left_rho_out_internal),
    .right_rho_in(right_rho_out_internal),
    .left_theta_in(left_theta_out_internal),
    .right_theta_in(right_theta_out_internal),
    .bram_out_wr_en(image_bram_wr_en),
    .bram_out_wr_addr(image_bram_wr_addr),
    .bram_out_wr_data(image_bram_wr_data),
    .bram_out_rd_addr(image_bram_rd_addr),
    .bram_out_rd_data(image_bram_rd_data),
    .bram_out_rd_en(image_bram_rd_en),
    .highlight_din(highlight_din),
    .highlight_wr_en(highlight_wr_en),
    .highlight_full(highlight_full)
);

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
    .rd_en(highlight_rd_en),
    .dout(highlight_dout),
    .empty(highlight_empty)
);

endmodule