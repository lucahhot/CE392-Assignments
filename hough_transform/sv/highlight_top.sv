// Module just to test the highlight module in isolation

module highlight_top #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter IMAGE_SIZE = WIDTH * HEIGHT,
    parameter REDUCED_WIDTH = 1035,
    parameter REDUCED_HEIGHT = 226,
    parameter REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT,
    parameter STARTING_X = 123,
    parameter STARTING_Y = 31,
    parameter THETA_BITS = 9,
    parameter BITS = 8,
    parameter TRIG_DATA_SIZE = 12,
    // These bottom 2 parameters control the line length of the lanes (need to tune)
    parameter K_START = -1000,
    parameter K_END = 1000,
    parameter OFFSET = 8
) (
    input  logic        clock,
    input  logic        reset,
    // INPUTS from hough
    input logic signed [15:0]       left_rho_in,
    input logic signed [15:0]       right_rho_in,
    input logic [THETA_BITS-1:0]    left_theta_in,
    input logic [THETA_BITS-1:0]    right_theta_in,
    // IMAGE INPUT
    output  logic           image_full,
    input   logic           image_wr_en,
    input   logic [23:0]    image_din,
    // MASK INPUT
    output  logic           mask_full,
    input   logic           mask_wr_en,
    input   logic [23:0]    mask_din,
    // Done signal
    output logic            highlight_done,
    // OUTPUT from image BRAM to TB
    output logic [23:0]     output_data
);

// Trig values to be used by both hough and highlight as parameters
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{0, 4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 48, 53, 57, 61, 66, 70, 74, 79, 83, 87, 91, 95, 100, 104, 108, 112, 116, 120, 124, 128, 131, 135, 139, 143, 146, 150, 154, 157, 161, 164, 167, 171, 174, 177, 181, 184, 187, 190, 193, 196, 198, 201, 204, 207, 209, 212, 214, 217, 219, 221, 223, 226, 228, 230, 232, 233, 235, 237, 238, 240, 242, 243, 244, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255, 255, 256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4};
localparam logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4, 0, -4, -8, -13, -17, -22, -26, -31, -35, -40, -44, -48, -53, -57, -61, -66, -70, -74, -79, -83, -87, -91, -95, -100, -104, -108, -112, -116, -120, -124, -128, -131, -135, -139, -143, -146, -150, -154, -157, -161, -164, -167, -171, -174, -177, -181, -184, -187, -190, -193, -196, -198, -201, -204, -207, -209, -212, -214, -217, -219, -221, -223, -226, -228, -230, -232, -233, -235, -237, -238, -240, -242, -243, -244, -246, -247, -248, -249, -250, -251, -252, -252, -253, -254, -254, -255, -255, -255, -255, -255};

typedef enum logic [1:0] {ZERO,HIGHLIGHT,READOUT_ADDR,READOUT} state_types;
state_types state, next_state;

logic [$clog2(WIDTH)-1:0] x, x_c;
logic [$clog2(HEIGHT)-1:0] y, y_c;

logic                            bram_out_wr_en_highlight;
logic [$clog2(IMAGE_SIZE)-1:0]   bram_out_wr_addr_highlight;
logic [23:0]                     bram_out_wr_data_highlight;

logic hough_done; 
logic highlight_done_internal;
assign highlight_done = highlight_done_internal;

// Input wires to grayscale function for mask
logic [23:0]    mask_dout;
logic           mask_empty;
logic           mask_rd_en;

// Input wires to image BRAM
logic [23:0]    image_dout;
logic           image_empty;
logic           image_rd_en;

// Output wires from grayscale_mask function to mask_bram
logic                                   mask_bram_wr_en;
logic [7:0]                             mask_bram_wr_data;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  mask_bram_wr_addr;
logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  mask_bram_rd_addr;
logic [7:0]                             mask_bram_rd_data;

logic                           image_bram_wr_en;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_wr_addr;
logic [23:0]                    image_bram_wr_data;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_rd_addr;
logic [23:0]                    image_bram_rd_data;

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
    .FIFO_BUFFER_SIZE(8)
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

fifo #(
    .FIFO_DATA_WIDTH(24),
    .FIFO_BUFFER_SIZE(8)
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

grayscale_mask #(
    .REDUCED_IMAGE_SIZE(REDUCED_IMAGE_SIZE),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .REDUCED_WIDTH(REDUCED_WIDTH),
    .REDUCED_HEIGHT(REDUCED_HEIGHT),
    .STARTING_X(STARTING_X),
    .STARTING_Y(STARTING_Y),
    .ENDING_X(1157),
    .ENDING_Y(256)
) mask_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(mask_rd_en),
    .in_empty(mask_empty),
    .in_dout(mask_dout),
    .hough_done(1'b0),
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

highlight #(
    .SIN_QUANTIZED(SIN_QUANTIZED),
    .COS_QUANTIZED(COS_QUANTIZED)
) highlight_inst (
    .clock(clock),
    .reset(reset),
    .hough_done(hough_done),
    .left_rho_in(left_rho_in),
    .right_rho_in(right_rho_in),
    .left_theta_in(left_theta_in),
    .right_theta_in(right_theta_in),
    .mask_bram_rd_data(mask_bram_rd_data),
    .mask_bram_rd_addr(mask_bram_rd_addr),
    .bram_out_wr_en(bram_out_wr_en_highlight),
    .bram_out_wr_addr(bram_out_wr_addr_highlight),
    .bram_out_wr_data(bram_out_wr_data_highlight),
    .highlight_done(highlight_done_internal)
);


always_ff @(posedge clock) begin
    if (reset) begin
        state <= ZERO;
        x <= 0;
        y <= 0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
    end
end

always_comb begin
    next_state = state;

    x_c = x;
    y_c = y;

    hough_done = 1'b0;

    image_rd_en = 1'b0;

    case(state)

        ZERO: begin
            // Write into image BRAM from the image FIFO
            if (image_empty == 1'b0) begin
                image_rd_en = 1'b1;
                image_bram_wr_en = 1'b1;
                image_bram_wr_addr = y * WIDTH + x;
                // Writing in image data from the image FIFO
                image_bram_wr_data = image_dout;
                // image_bram_wr_data = 24'b0;
                if (x == WIDTH - 1) begin
                    if (y == HEIGHT - 1) begin
                        next_state = HIGHLIGHT;
                        hough_done = 1'b1;
                        x_c = 0;
                        y_c = 0;
                    end else begin
                        x_c = 0;
                        y_c = y + 1;
                    end
                end else begin
                    x_c = x + 1;
                end
            end
        end

        HIGHLIGHT: begin
            image_bram_wr_en = bram_out_wr_en_highlight;
            image_bram_wr_addr = bram_out_wr_addr_highlight;
            image_bram_wr_data = bram_out_wr_data_highlight;
            if (highlight_done_internal) begin
                next_state = READOUT_ADDR;
            end
        end

        READOUT_ADDR: begin
            image_bram_rd_addr = y * WIDTH + x;
            next_state = READOUT;
        end

        READOUT: begin
            output_data = image_bram_rd_data;
            next_state = READOUT_ADDR;
            if (x == WIDTH - 1) begin
                if (y == HEIGHT - 1) begin
                    next_state = ZERO;
                end else begin
                    x_c = 0;
                    y_c = y + 1;
                end
            end else begin
                x_c = x + 1;
            end
        end
        
    endcase
end

endmodule