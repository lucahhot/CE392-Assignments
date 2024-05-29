
// Modified highlight module to write out red highlighted pixels to a smaller image BRAM (while canny and hough are running, it should write default values
// of 0 or black to the BRAM)

// Will also account for left/right lanes not being present and not writing anything if that's the case. Might be a strong possibility with real world data input
// where there may not be any "lane" available to highlight

module highlight #(
    parameter STARTING_X = 0,
    parameter STARTING_Y = 0,
    parameter ENDING_X = 568,
    parameter ENDING_Y = 320,
    parameter REDUCED_WIDTH = ENDING_X - STARTING_X,
    parameter REDUCED_HEIGHT = ENDING_Y - STARTING_Y,
    parameter REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT,
    parameter THETA_BITS = 9,
    parameter BITS = 8,
    parameter TRIG_DATA_SIZE = 12,
    // These bottom 2 parameters control the line length of the lanes (NEED TO ADJUST)
    parameter K_START = -1000,
    parameter K_END = 1000,
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

    // Ports to image BRAM
    output logic                                   bram_out_wr_en,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  bram_out_wr_addr,
    output logic [7:0]                             bram_out_wr_data,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  bram_out_rd_addr,
    input  logic [7:0]                             bram_out_rd_data,

    // Highlight output FIFO signals
    output logic [7:0]  highlight_din,
    output logic        highlight_wr_en,
    input  logic        highlight_full
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

typedef enum logic [3:0] {ZERO,IDLE,LANE_SELECT,K_LOOP,CHECK,PIXEL_LOOP,OUTPUT,LAST_OUTPUT} state_types;
state_types state, next_state;

// Calculated X and Y values for both lanes
// Giving it 1 extra bit since we are making them signed for the dequantization to work
localparam X_WIDTH = $clog2(REDUCED_WIDTH) + 1;
localparam Y_WIDTH = $clog2(REDUCED_HEIGHT) + 1;

logic signed [X_WIDTH:0] x, x_c;
logic signed [Y_WIDTH-1:0] y, y_c;

// Offset value of x to make the lane highlights wider than 1 pixel wide
logic signed [X_WIDTH:0] offset, offset_c;

// K index
// Giving it 1 extra bit to make it signed for the dequantization to work
logic signed [$clog2(K_END-K_START):0] k, k_c;

// Internal sin/cos values, and rho depending on the lane being highlighted
logic signed [TRIG_DATA_SIZE-1:0] sin_val, sin_val_c, cos_val, cos_val_c;
logic signed [15:0] rho, rho_c;

// Signal to indicate the left lane has been highlighted
logic left_done, left_done_c;

// First cycle for OUTPUT
logic first_output_cycle, first_output_cycle_c;

// Registers to hold lane values
logic signed [15:0] left_rho, left_rho_c, right_rho, right_rho_c;
logic [THETA_BITS-1:0] left_theta, left_theta_c, right_theta, right_theta_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= ZERO;
        x <= 0;
        y <= 0;
        offset <= 0;
        k <= 0;
        sin_val <= 0;
        cos_val <= 0;
        rho <= 0;
        left_done <= 0;
        first_output_cycle <= 1'b0;
        left_rho <= 0;
        left_theta <= 0;
        right_rho <= 0;
        right_theta <= 0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
        offset <= offset_c;
        k <= k_c;
        sin_val <= sin_val_c;
        cos_val <= cos_val_c;
        rho <= rho_c;
        left_done <= left_done_c;
        first_output_cycle <= first_output_cycle_c;
        left_rho <= left_rho_c;
        left_theta <= left_theta_c;
        right_rho <= right_rho_c;
        right_theta <= right_theta_c;
    end
end

always_comb begin
    // BRAM outputs
    bram_out_wr_en = 1'b0;
    bram_out_wr_addr = 0;
    bram_out_wr_data = '0;
    bram_out_rd_addr = 0;

    // FIFO outputs
    highlight_din = '0;
    highlight_wr_en = 1'b0;
    
    next_state = state;
    x_c = x;
    y_c = y;
    offset_c = offset;
    k_c = k;
    sin_val_c = sin_val;
    cos_val_c = cos_val;
    rho_c = rho;
    left_done_c = left_done;

    first_output_cycle_c = first_output_cycle;
    left_rho_c = left_rho;
    left_theta_c = left_theta;
    right_rho_c = right_rho;
    right_theta_c = right_theta;

    case (state)
        
        // Zero all the BRAM values or make black and then move to IDLE
        ZERO: begin
            bram_out_wr_en = 1'b1;
            bram_out_wr_addr = y * REDUCED_WIDTH + x;
            bram_out_wr_data = 24'h000000; // Write a black pixel

            // Increment the x and y values to move to the next pixel
            if (x == ENDING_X - 1) begin
                if (y == ENDING_Y - 1) begin
                    // We've reached the end of the image so we're done
                    next_state = IDLE;
                end else begin
                    x_c = 0;
                    y_c = Y_WIDTH'(y + 1'b1);
                end 
            end else begin
                x_c = X_WIDTH'(x + 1'b1);
            end
        end

        // Wait for hough_done to be asserted to move on to the next state
        IDLE: begin
            if (hough_done == 1'b1) begin
                next_state = LANE_SELECT;
                left_rho_c = left_rho_in;
                left_theta_c = left_theta_in;
                right_rho_c = right_rho_in;
                right_theta_c = right_theta_in;
            end
        end

        // Make sure to check if there are any lanes to highlight (theta and highlight will both be 0 if the lane doesn't exist)
        // If there are no lanes to highlight, we just go back to IDLE
        LANE_SELECT: begin
            // Set the internal variables to the left lane values
            if (left_done == 1'b0) begin
                // Check if this lane exists or not
                if (left_theta == 0 && left_rho == 0) begin
                    left_done_c = 1'b1;
                    next_state = LANE_SELECT;
                end else begin
                    sin_val_c = SIN_QUANTIZED[left_theta];
                    cos_val_c = COS_QUANTIZED[left_theta];
                    rho_c = left_rho;
                    next_state = K_LOOP;
                    // Initialize k value to K_START
                    k_c = K_START;
                end
            end else begin
                // If the left lane is done, then move on to the right lane
                // Check if this lane exists or not
                if (right_theta == 0 && right_rho == 0) begin
                    next_state = OUTPUT;
                    first_output_cycle_c = 1'b1;
                    // Reset x and y coordiantes for OUTPUT stage
                    x_c = 0;
                    y_c = 0;
                end else begin
                    sin_val_c = SIN_QUANTIZED[right_theta];
                    cos_val_c = COS_QUANTIZED[right_theta];
                    rho_c = right_rho;
                    next_state = K_LOOP;
                    // Initialize k value to K_START
                    k_c = K_START;
                end 
            end
        end

        // Loop through the K values, calculate x and y (had to split up this stage to make it run faster)
        K_LOOP: begin
            if (k_c < K_END) begin
                // Calculate x and y values
                x_c = DEQUANTIZE($signed(rho) * $signed(cos_val) - $signed(k) * $signed(sin_val));
                y_c = DEQUANTIZE($signed(rho) * $signed(sin_val) + $signed(k) * $signed(cos_val));
                next_state = CHECK;
            end else begin
                // If we are done with the K values, then move on to the next lane
                if (left_done == 1'b0) begin
                    left_done_c = 1'b1;
                    next_state = LANE_SELECT;
                end else begin
                    // If we are done with the right lane, then we are done highlighting
                    next_state = OUTPUT;
                    first_output_cycle_c = 1'b1;
                    // Reset x and y coordinates for OUTPUT stage
                    x_c = 0;
                    y_c = 0;
                end
            end
        end

        // Check if we are within the reduced image size bounds
        CHECK: begin
            if (x >= STARTING_X && x < ENDING_X && y >= STARTING_Y && y < ENDING_Y) begin
                next_state = PIXEL_LOOP;
                offset_c = x - OFFSET;
            end else begin
                k_c = k + 1;
                next_state = K_LOOP;
            end
        end

        // Loop where we write the highlighted pixels into the external BRAM
        PIXEL_LOOP: begin
            // Check if the offset value is within the image bounds
            if (offset >= 0 && offset < REDUCED_WIDTH) begin
                // Write the highlighted pixel into the BRAM
                bram_out_wr_en = 1'b1;
                bram_out_wr_addr = y * REDUCED_WIDTH + offset;
                bram_out_wr_data = 24'h0000FF; // Write a red only pixel
            end
            // Increment offset
            offset_c = offset + 1;
            if ((offset) == ((x + OFFSET) - 1)) begin
                // If we have written all the highlighted pixels, then move on to the next k value
                k_c = k + 1;
                next_state = K_LOOP;
            end else begin
                next_state = PIXEL_LOOP;
            end  
        end

        // Output data into FIFO in pipelined format to save cycles
        OUTPUT: begin
            // Reset first cycle flag
            first_output_cycle_c = 1'b0;
            // Set BRAM address
            bram_out_rd_addr = y * REDUCED_WIDTH + x;

            // Only output the values inside the BRAM after the first cycle
            if (first_output_cycle == 1'b0) begin
                if (highlight_full == 1'b0) begin
                    highlight_wr_en = 1'b1;
                    highlight_din = bram_out_rd_data;
                    // Increment x and y values
                    if (x == ENDING_X - 1) begin
                        if (y == ENDING_Y - 1) begin
                            // We still have one last value to output
                            next_state = LAST_OUTPUT;
                        end else begin
                            x_c = 0;
                            y_c = Y_WIDTH'(y + 1'b1);
                        end
                    end else begin
                        x_c = X_WIDTH'(x + 1'b1);
                    end
                end
            end
        end

        // Because of the pipelining, we have one last value to output
        LAST_OUTPUT: begin 
            if (highlight_full == 1'b0) begin
                highlight_wr_en = 1'b1;
                highlight_din = bram_out_rd_data;
                // Reset everything and go back to ZERO state
                next_state = ZERO;
                x_c = 0;
                y_c = 0;
            end
        end

        default: begin
            bram_out_wr_en = 1'b0;
            bram_out_wr_addr = 0;
            bram_out_wr_data = '0;
            bram_out_rd_addr = '0;
            highlight_din = '0;
            highlight_wr_en = 1'b0;
            next_state = ZERO;
            x_c = 'X;
            y_c = 'X;
            offset_c = 'X;
            k_c = 'X;
            sin_val_c = 'X;
            cos_val_c = 'X;
            rho_c = 'X;
            left_done_c = 'X;
            first_output_cycle_c = 'X;
            left_rho_c = 'X;
            left_theta_c = 'X;
            right_rho_c = 'X;
            right_theta_c = 'X;
        end
        
    endcase
end


endmodule