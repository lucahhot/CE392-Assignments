
// Defining the parameters here because there are always problems with the parameters in the globals file

module hough_top #(
    // Image dimensions
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter IMAGE_SIZE = WIDTH * HEIGHT, // 921600
    parameter FIFO_BUFFER_SIZE = 8,

    // Adjusted height and width to save cycles (pre-calculated or else the fractions create problems)
    parameter ENDING_X = 1152 + 5, // 1157 = WIDTH * MASK_BR_X + 5
    parameter ENDING_Y = 251 + 5, // 256 = HEIGHT * MASK_TR_Y + 5

    parameter STARTING_X = 128 - 5, // 123 = WIDTH * MASK_BL_X - 5
    parameter STARTING_Y = 36 - 5, // 31 = HEIGHT * MASK_BL_Y - 5

    // Reduced image dimensions (rectangle that encompasses the mask)
    parameter REDUCED_WIDTH = ENDING_X - STARTING_X + 1, // 1157 - 123 + 1 = 1035 (need to include the last point as part of the width)
    parameter REDUCED_HEIGHT = ENDING_Y - STARTING_Y + 1, // 256 - 31 + 1 = 226 (need to include the last point as part of the height)
    parameter REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT, // 233910 -74.6% reduction in size

    parameter THETAS = 180,
    parameter RHOS = 1179,
    parameter RHO_RANGE = 2*RHOS, // 2358

    // Unroll factor for the accumulation stage (the theta loop)
    parameter THETA_UNROLL = 16,
    parameter THETA_DIVIDE_BITS = 4, // So that we don't have to divide by a non-power of 2 number (this means THEAT_UNROLL must be a power of 2)
    parameter THETA_FACTOR = 12, // ceil(THETAS/THETA_UNROLL) = 23, this is necessary if THETAS%THETA_UNROLL != 0

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
    output logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0] output_data,
    output logic signed [15:0] left_rho_out,
    output logic signed [15:0] right_rho_out,
    output logic [THETA_BITS-1:0] left_theta_out,
    output logic [THETA_BITS-1:0] right_theta_out
);

// Trig values to be used by both hough and highlight as parameters
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{0, 4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 48, 53, 57, 61, 66, 70, 74, 79, 83, 87, 91, 95, 100, 104, 108, 112, 116, 120, 124, 128, 131, 135, 139, 143, 146, 150, 154, 157, 161, 164, 167, 171, 174, 177, 181, 184, 187, 190, 193, 196, 198, 201, 204, 207, 209, 212, 214, 217, 219, 221, 223, 226, 228, 230, 232, 233, 235, 237, 238, 240, 242, 243, 244, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255, 255, 256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4};
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4, 0, -4, -8, -13, -17, -22, -26, -31, -35, -40, -44, -48, -53, -57, -61, -66, -70, -74, -79, -83, -87, -91, -95, -100, -104, -108, -112, -116, -120, -124, -128, -131, -135, -139, -143, -146, -150, -154, -157, -161, -164, -167, -171, -174, -177, -181, -184, -187, -190, -193, -196, -198, -201, -204, -207, -209, -212, -214, -217, -219, -221, -223, -226, -228, -230, -232, -233, -235, -237, -238, -240, -242, -243, -244, -246, -247, -248, -249, -250, -251, -252, -252, -253, -254, -254, -255, -255, -255, -255, -255};

// Input wires to image_loader
logic [23:0]    image_dout;
logic           image_empty;
logic           image_rd_en;

// Output wires from image_loader to grayscale FIFO
logic           grayscale_wr_en;
logic           grayscale_full;
logic [23:0]    grayscale_din;

// // Output wires from image_loader to image_BRAM
// logic                           image_bram_wr_en;
// logic [23:0]                    image_bram_wr_data;
// logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_wr_addr;
// logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_rd_addr;
// logic [23:0]                    image_bram_rd_data;

// Input wires to grayscale function
logic [23:0]    grayscale_dout;
logic           grayscale_empty;
logic           grayscale_rd_en;

// Input wires to grayscale function for mask
logic [23:0]    mask_dout;
logic           mask_empty;
logic           mask_rd_en;

logic hough_done_internal, hough_done_registered;
assign hough_done = hough_done_internal;

// Output wires from grayscale function to gaussian_blur FIFO
logic           gaussian_wr_en;
logic           gaussian_full;
logic [7:0]     gaussian_din;

// Output wires from grayscale_mask function to mask_bram
logic                                   mask_bram_wr_en;
logic [7:0]                             mask_bram_wr_data;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  mask_bram_wr_addr;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  mask_bram_rd_addr;
logic [7:0]                             mask_bram_rd_data;

// Additional signals for reading from mask BRAM from hough and highlight
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  mask_bram_rd_addr_hough, mask_bram_rd_addr_highlight;
logic [7:0]                             mask_bram_rd_data_hough, mask_bram_rd_data_highlight;

// Logic to determine which mask BRAM read signals to use depending on the value of hough_done_registered
// assign mask_bram_rd_addr = (hough_done_registered == 1'b0) ? mask_bram_rd_addr_hough : mask_bram_rd_addr_highlight;
// assign mask_bram_rd_data = (hough_done_registered == 1'b0) ? mask_bram_rd_data_hough : mask_bram_rd_data_highlight;

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
logic                                   hysteresis_bram_wr_en;
logic [7:0]                             hysteresis_bram_wr_data;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  hysteresis_bram_wr_addr;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  hysteresis_bram_rd_addr;
logic [7:0]                             hysteresis_bram_rd_data;
logic                                   hough_start;

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

image_loader #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y)
) image_loader_inst (
    .clock(clock),
    .reset(reset),
    .in_rd_en(image_rd_en),
    .in_empty(image_empty),
    .in_dout(image_dout),
    .fifo_out_wr_en(grayscale_wr_en),
    .fifo_out_full(grayscale_full),
    .fifo_out_din(grayscale_din)
    // .bram_out_wr_en(image_bram_wr_en),
    // .bram_out_wr_addr(image_bram_wr_addr),
    // .bram_out_wr_data(image_bram_wr_data)
);

// bram #(
//     .BRAM_DATA_WIDTH(24),
//     .IMAGE_SIZE(IMAGE_SIZE)
// ) image_bram_inst (
//     .clock(clock),
//     .rd_addr(image_bram_rd_addr),
//     .wr_addr(image_bram_wr_addr),
//     .wr_en(image_bram_wr_en),
//     .wr_data(image_bram_wr_data),
//     .rd_data(image_bram_rd_data)
// );

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

grayscale_mask #(
    .REDUCED_IMAGE_SIZE(REDUCED_IMAGE_SIZE),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y)
) mask_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(mask_rd_en),
    .in_empty(mask_empty),
    .in_dout(mask_dout),
    .hough_done(hough_done_internal),
    .out_wr_en(mask_bram_wr_en),
    .out_wr_addr(mask_bram_wr_addr),
    .out_wr_data(mask_bram_wr_data)
);

bram #(
    .BRAM_DATA_WIDTH(8),
    .IMAGE_SIZE(REDUCED_IMAGE_SIZE)
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

gaussian_blur #(
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y)
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

sobel #(
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),   
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y)
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
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y)
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
    .REDUCED_IMAGE_SIZE(REDUCED_IMAGE_SIZE),
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y)
) hysteresis_inst (
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
    .IMAGE_SIZE(REDUCED_IMAGE_SIZE)
) hysteresis_bram_inst (
    .clock(clock),
    .rd_addr(hysteresis_bram_rd_addr),
    .wr_addr(hysteresis_bram_wr_addr),
    .wr_en(hysteresis_bram_wr_en),
    .wr_data(hysteresis_bram_wr_data),
    .rd_data(hysteresis_bram_rd_data)
);

hough #(
    .REDUCED_IMAGE_SIZE(REDUCED_IMAGE_SIZE),
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(ENDING_X),
    .ENDING_Y(ENDING_Y),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
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
    .BITS(BITS),
    .TRIG_DATA_SIZE(TRIG_DATA_SIZE),
    .SIN_QUANTIZED(SIN_QUANTIZED),
    .COS_QUANTIZED(COS_QUANTIZED)
) hough_inst (
    .clock(clock),
    .reset(reset),
    .start(hough_start),
    .hysteresis_bram_rd_data(hysteresis_bram_rd_data),
    .hysteresis_bram_rd_addr(hysteresis_bram_rd_addr),
    .mask_bram_rd_data(mask_bram_rd_data),
    .mask_bram_rd_addr(mask_bram_rd_addr),
    .accum_buff_done(accum_buff_done),
    .hough_done(hough_done_internal),
    .output_data(output_data),
    .left_rho_out(left_rho_out),
    .right_rho_out(right_rho_out),
    .left_theta_out(left_theta_out),
    .right_theta_out(right_theta_out)
);

// Block to assign value to hough_done_registered
always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        hough_done_registered <= 1'b0;
    end else begin
        // We want hough_done_registered to be 1 when hough_done_internal is 1 and stay as 1 (hough_done_internal will go back to 0)
        if (hough_done_internal == 1'b1) begin
            hough_done_registered <= 1'b1;
        end
    end
end

endmodule