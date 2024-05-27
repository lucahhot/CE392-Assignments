// This module will take in the rho/theta values for both the left and right lanes from the hough.sv module
// and will highlight the lanes on the image. 

// FOR NOW: this module will write the highlighted pixels into an external BRAM that will hopefully be the 
// off-FPGA DDR3 memory on the de10nano where the original image will be stored before being pushed into the 
// frame buffer. This means that if a pixel is not highlighted, then we will not write anything into the BRAM,
// since we are assuming the original pixels are already in the BRAM.

// Currently, I don't think I can highlight 2 lanes at the same time since that would mean not only reading from
// 2 difference addresses in the mask BRAM, but also writing to 2 different addresses in the image BRAM. 
// This also means that unrolling the K_LOOP and the PIXEL_LOOP might not be possible since we are writing to a pixel
// every iteration of the loop.  

module highlight #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter IMAGE_SIZE = WIDTH * HEIGHT,
    parameter REDUCED_WIDTH = 1035,
    parameter REDUCED_HEIGHT = 226,
    parameter REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT,
    parameter STARTING_X = 123,
    parameter STARTING_Y = 31,
    parameter ENDING_X = 1157,
    parameter ENDING_Y = 256,
    parameter THETA_BITS = 9,
    parameter BITS = 8,
    parameter TRIG_DATA_SIZE = 12,
    // These bottom 2 parameters control the line length of the lanes (need to tune)
    parameter K_START = -1000,
    parameter K_END = 0,
    parameter OFFSET = 8,
    parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{default: '{default: '0}},
    parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{default: '{default: '0}}
) (
    input  logic        clock,
    input  logic        reset,
    input  logic        hough_done, // Done signal from hough module 
    // INPUTS from hough
    input logic signed [15:0]       left_rho_in,
    input logic signed [15:0]       right_rho_in,
    input logic [THETA_BITS-1:0]    left_theta_in,
    input logic [THETA_BITS-1:0]    right_theta_in,
    // MASK INPUTs from bram_2d
    input  logic [7:0]                              mask_bram_rd_data,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   mask_bram_rd_addr,
    // OUTPUTs to image BRAM
    output logic                            bram_out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0]   bram_out_wr_addr,
    output logic [23:0]                     bram_out_wr_data,
    // Done signal
    output logic highlight_done
);

// DEQUANTIZE function
function logic signed [15:0] DEQUANTIZE(logic signed [31:0] i);
    // Arithmetic right shift doesn't work well with negative number rounding so switch the sign 
    // to perform the right shift then apply the negative sign to the results
    if (i < 0) 
        DEQUANTIZE = (16'(-(-i >>> BITS)));
    else 
        DEQUANTIZE = 16'(i >>> BITS);
endfunction

typedef enum logic [2:0] {IDLE,LANE_SELECT,K_LOOP,MASK_ADDR,MASK,PIXEL_LOOP} state_types;
state_types state, next_state;

// Calculated X and Y values for both lanes
// Giving it 1 extra bit since we are making them signed for the dequantization to work
localparam X_WIDTH = $clog2(WIDTH) + 1;
localparam Y_WIDTH = $clog2(HEIGHT) + 1;

logic signed [X_WIDTH-1:0] x, x_c;
logic signed [Y_WIDTH-1:0] y, y_c;

// Mask coordinate values to be able to read from the mask BRAM
logic [$clog2(REDUCED_WIDTH)-1:0] x_mask, x_mask_c;
logic [$clog2(REDUCED_HEIGHT)-1:0] y_mask, y_mask_c;

// Value of mask
logic [7:0] mask, mask_c;

// Offset value of x to make the lane highlights wider than 1 pixel wide
logic signed [X_WIDTH-1:0] offset, offset_c;

// K index
// Giving it 1 extra bit to make it signed for the dequantization to work
logic signed [$clog2(K_END-K_START):0] k, k_c;

// Internal sin/cos values, and rho depending on the lane being highlighted
logic signed [TRIG_DATA_SIZE-1:0] sin_val, sin_val_c, cos_val, cos_val_c;
logic signed [15:0] rho, rho_c;

// Signal to indicate the left lane has been highlighted
logic left_done, left_done_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        x <= 0;
        y <= 0;
        x_mask <= 0;
        y_mask <= 0;
        mask <= 0;
        offset <= 0;
        k <= 0;
        sin_val <= 0;
        cos_val <= 0;
        rho <= 0;
        left_done <= 0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
        x_mask <= x_mask_c;
        y_mask <= y_mask_c;
        mask <= mask_c;
        offset <= offset_c;
        k <= k_c;
        sin_val <= sin_val_c;
        cos_val <= cos_val_c;
        rho <= rho_c;
        left_done <= left_done_c;
    end
end

always_comb begin
    // Outputs
    bram_out_wr_en = 1'b0;
    bram_out_wr_addr = 0;
    bram_out_wr_data = '0;
    highlight_done = 1'b0;
    
    next_state = state;
    x_c = x;
    y_c = y;
    x_mask_c = x_mask;
    y_mask_c = y_mask;
    mask_c = mask;
    offset_c = offset;
    k_c = k;
    sin_val_c = sin_val;
    cos_val_c = cos_val;
    rho_c = rho;
    left_done_c = left_done;

    case (state)
        // Wait for hough_done to be asserted to move on to the next state
        IDLE: begin
            if (hough_done == 1'b1) begin
                next_state = LANE_SELECT;
            end
        end

        // Select the left lane first
        LANE_SELECT: begin
            // Set the internal variables to the left lane values
            if (left_done == 1'b0) begin
                sin_val_c = SIN_QUANTIZED[left_theta_in];
                cos_val_c = COS_QUANTIZED[left_theta_in];
                rho_c = left_rho_in;
            end else begin
                sin_val_c = SIN_QUANTIZED[right_theta_in];
                cos_val_c = COS_QUANTIZED[right_theta_in];
                rho_c = right_rho_in;
            end
            next_state = K_LOOP;
            // Initialize k value to K_START
            k_c = K_START;
        end

        // Loop through the K values, calculate x and y (had to split up this stage to make it run faster)
        K_LOOP: begin
            if (k_c < K_END) begin
                // Calculate x and y values
                x_c = DEQUANTIZE($signed(rho) * $signed(cos_val) - $signed(k) * $signed(sin_val));
                y_c = DEQUANTIZE($signed(rho) * $signed(sin_val) + $signed(k) * $signed(cos_val));
                next_state = MASK_ADDR;
            end else begin
                // If we are done with the K values, then move on to the next lane
                if (left_done == 1'b0) begin
                    left_done_c = 1'b1;
                    next_state = LANE_SELECT;
                end else begin
                    // If we are done with the right lane, then we are done highlighting
                    highlight_done = 1'b1;
                    next_state = IDLE;
                end
            end
        end

        // Calculate the mask address to read from the mask BRAM
        MASK_ADDR: begin
            // If the mask addresses are outside of STARTING_X/Y AND ENDING_X/Y, then move on to the next k value
            // (The mask is within these bounds so if the x and y values are outside of these bounds, then the mask value will be 0)
            if (x >= STARTING_X && x <= ENDING_X && y >= STARTING_Y && y <= ENDING_Y) begin
                // Set the mask read address to be read in the next state
                x_mask_c = x - STARTING_X;
                y_mask_c = y - STARTING_Y;
                mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                next_state = MASK;
            end else begin
                k_c = k + 1;
                next_state = K_LOOP;
            end
        end

        // Check the mask value of the calculated pixel from the mask BRAM
        MASK: begin
            mask_c = mask_bram_rd_data;
            // If the pixel is in the mask, then move to PIXEL_LOOP
            if (mask_c >= 8'h0F) begin
                next_state = PIXEL_LOOP;
                // Set the offset value to x - OFFSET
                offset_c = x - OFFSET;
            end else begin
                // If the pixel is not in the mask, then move on to the next k value
                k_c = k + 1;
                next_state = K_LOOP;
            end
        end

        // Loop where we write the highlighted pixels into the external BRAM
        PIXEL_LOOP: begin
            // Check if the offset value is within the image bounds
            if (offset >= 0 && offset < WIDTH) begin
                // Write the highlighted pixel into the BRAM
                bram_out_wr_en = 1'b1;
                bram_out_wr_addr = y * WIDTH + offset;
                bram_out_wr_data = 24'h0000FF; // Write a red only pixel
            end
            // Increment offset
            offset_c = offset + 1;
            if (offset == (x + OFFSET) - 1) begin
                // If we have written all the highlighted pixels, then move on to the next k value
                k_c = k + 1;
                next_state = K_LOOP;
            end else begin
                next_state = PIXEL_LOOP;
            end  
        end

        default: begin
            bram_out_wr_en = 1'b0;
            bram_out_wr_addr = 0;
            bram_out_wr_data = '0;
            highlight_done = 1'b0;
            
            next_state = IDLE;
            x_c = 'X;
            y_c = 'X;
            x_mask_c = 'X;
            y_mask_c = 'X;
            mask_c = 'X;
            offset_c = 'X;
            k_c = 'X;
            sin_val_c = 'X;
            cos_val_c = 'X;
            rho_c = 'X;
            left_done_c = 'X;
        end
        
    endcase
end


endmodule