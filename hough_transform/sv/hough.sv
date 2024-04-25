// This module will take in the output of the hysteresis stage and the mask, and 
// calculate the accum_buff which will be a 2D array of all the possible rhos and thetas.

// (Might just output the resulting left and right lanes (their rhos, thetas/trig values) as it will
// prevent the issue of sending the accum_buff values to another module which might create a lot of wires
// on the top level if we're not storing the values inside of a BRAM).

// Hysteresis inputs will be streamed in pixel by pixel, but we need to loop through 0 to THETAS
// PER pixel, therefore this hough module will be stalled per pixel and it might stall the entire canny edge
// pipeline before this. Making the hysteresis output FIFO super big is obviously not a good idea,
// so another idea might be to store the hysteresis, initial image, and mask into some time of memory,
// so we can read them as we want to inside of hough. Will try to store the images (including the mask)
// and the hysteresis output in a BRAM and read them as we want to. The accum_buff will currenly be a 2D
// array of flip flops as it'll be easier to implement since I don't know how to zero or reset the BRAM
// and also we would need to read and write to each accum_buff array value in 1 clock cycle, which is not
// possible with the BRAM.

`include "globals.sv"

module hough (
    input  logic        clock,
    input  logic        reset,
    input  logic        start,
    // HYSTERESIS INPUTS from bram_2d
    input  logic [7:0]                      hysteresis_bram_rd_data,
    output logic [$clog2(IMAGE_SIZE)-1:0]   hysteresis_bram_rd_addr,
    // MASK INPUTs from bram_2d
    input  logic [7:0]                      mask_bram_rd_data,
    output logic [$clog2(IMAGE_SIZE)-1:0]  mask_bram_rd_addr,
    // UNSURE OF OUTPUTS FOR NOW
    output logic done,
    output logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff_out

);

typedef enum logic [1:0] {IDLE, ACCUMULATE, THETA_LOOP, SELECT} state_types;
state_types state, next_state;

// Unroll factor for the accumulation stage (the theta loop)
parameter THETA_UNROLL = 1;

// X and Y indices for the accumulation stage (using the adjusted width and height)
// Giving it 1 extra bit since we are making them signed for the dequantization to work
logic signed [$clog2(WIDTH_ADJUSTED):0] x, x_c;
logic signed [$clog2(HEIGHT_ADJUSTED):0] y, y_c;

// Read values from the hyseteresis and mask BRAMs 
logic [7:0] hysteresis, mask;

// Theta index for the accumulation stage
logic [$clog2(THETAS)-1:0] theta, theta_c;

// Wire to hold rho value (will be calculated using the x and y values)
logic signed [15:0] rho, rho_unquantized_x, rho_unquantized_y, rho_quantized_x, rho_quantized_y;

// Wires to hold the quantized sin and cos values for the theta loop (for some reason it doesn't work when referencing
// the SIN_QUANTIZED and COS_QUANTIZED arrays directly from globals.sv)
logic signed [15:0] sin_quantized, cos_quantized;

// Accumulator buffer (2D array of all possible rhos and thetas)
// Each entry will be a 16 bit value as specified in the C code by Professor Zaretsky
logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff, accum_buff_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        accum_buff <= '{default: '{default: '{default: '0}}};
        x <= '0;
        y <= '0;
        theta <= '0;
    end else begin
        state <= next_state;
        accum_buff <= accum_buff_c;
        x <= x_c;
        y <= y_c;
        theta <= theta_c;
    end
end

always_comb begin
    next_state = state;
    accum_buff_c = accum_buff;
    x_c = x;
    y_c = y;
    theta_c = theta;
    // Default values for the BRAM addresses
    hysteresis_bram_rd_addr = 0;
    mask_bram_rd_addr = 0;

    done = 1'b0;
    accum_buff_out = '{default: '{default: '{default: '0}}};

    case(state)
        // Waits for the start signal to begin the accumulation stage 
        IDLE: begin
            if (start == 1'b1) begin
                next_state = ACCUMULATE;
                // Set the hysteresis and mask BRAM addresses so the BRAM output can be read in the next cycle
                // We start at STARTING_X and STARTING_Y to save cycles
                hysteresis_bram_rd_addr = STARTING_Y * WIDTH + STARTING_X;
                mask_bram_rd_addr = STARTING_Y * WIDTH + STARTING_X;
                // Set the initial x and y coordinates
                x_c = STARTING_X;
                y_c = STARTING_Y;
                // Zero out the accum_buff array
                accum_buff_c = '{default: '{default: '{default: '0}}};
            end
        end

        // Stage to find out if we jump into the THETA_LOOP stage or not (and update BRAM addresses for the next pixel)
        // Not performing the accumulation here as we need to loop through all thetas for each pixel and it might get messy
        ACCUMULATE: begin
            // Read the hysteresis and mask values from the BRAMs (from addresses in the last cycle)
            hysteresis = hysteresis_bram_rd_data;
            mask = mask_bram_rd_data;
            // Only jump into the THETA stage if the pixel is an edge pixel (hysteresis != 0x00) and
            // the pixel is inside the mask (mask >= 0x0F because some mask values are like 0xFE, 0xFD but some are 0x03)
            if (hysteresis != 8'h00 && mask >= 8'h0F) begin
                next_state = THETA_LOOP;
            end else begin
                // Increment the x and y values to move to the next pixel
                if (x == WIDTH_ADJUSTED-1) begin
                    if (y == HEIGHT_ADJUSTED-1) begin
                        // We've reached the end of the image so we're done
                        next_state = SELECT;
                    end else begin
                        x_c = STARTING_X;
                        y_c = y + 1;
                        // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                        hysteresis_bram_rd_addr = y_c * WIDTH + x_c;
                        mask_bram_rd_addr = y_c * WIDTH + x_c;
                    end 
                end else begin
                    x_c = x + 1;
                    // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                    hysteresis_bram_rd_addr = y_c * WIDTH + x_c;
                    mask_bram_rd_addr = y_c * WIDTH + x_c;
                end
            end
        end

        // THETA_LOOP stage to loop through all thetas for each pixel and calculate the rho value
        // Will unroll this according to the THETA_UNROLL parameter to save cycles since none of the 
        // calculations are dependent on each other
        THETA_LOOP: begin
            // For loop to perform the unrolled theta loop
            for (int theta_index = theta; theta_index < theta + THETA_UNROLL; theta_index++) begin
                // Calculate the rho value using the x, y, and quantized trig values in globals.sv
                sin_quantized = SIN_QUANTIZED[theta_index];
                cos_quantized = COS_QUANTIZED[theta_index];
                rho_unquantized_x = DEQUANTIZE(x * cos_quantized);
                rho_unquantized_y = DEQUANTIZE(y * sin_quantized);
                // rho_quantized_x = (x * cos_quantized);
                // rho_quantized_y = (y * sin_quantized);
                rho = (rho_unquantized_x + rho_unquantized_y);
                // Increment the accumulator buffer value at the rho and theta index by 1
                accum_buff_c[rho+RHOS][theta_index] = accum_buff[rho+RHOS][theta_index] + 1;
            end
            // Increment the theta value by the unroll factor
            theta_c = theta + THETA_UNROLL;
            // If we've reached the end of thetas, go back to the ACCUMULATE stage to move to the next pixel
            if (theta_c > THETAS) begin
                next_state = ACCUMULATE;
                theta_c = 0;
                // We need to update the x and y coordinates to and set the addresses for the next pixel
                // so the BRAM outputs can be ready in the next cycle
                if (x == WIDTH_ADJUSTED-1) begin
                    if (y == HEIGHT_ADJUSTED-1) begin
                        // We've reached the end of the image so we're done
                        next_state = SELECT;
                    end else begin
                        x_c = 0;
                        y_c = y + 1;
                        // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                        hysteresis_bram_rd_addr = y_c * WIDTH + x_c;
                        mask_bram_rd_addr = y_c * WIDTH + x_c;
                    end 
                end else begin
                    x_c = x + 1;
                    // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                    hysteresis_bram_rd_addr = y_c * WIDTH + x_c;
                    mask_bram_rd_addr = y_c * WIDTH + x_c;
                end
            end
        end

        // SELECT stage to output the left and right lanes (their rhos, thetas/trig values)
        SELECT: begin
            next_state = IDLE;
            accum_buff_out = accum_buff;
            done = 1'b1;
        end

        default: begin
            next_state = IDLE;
            accum_buff_c = '{default: '{default: '{default: '0}}};
            x_c = 'X;
            y_c = 'X;
            theta_c = 'X;
            hysteresis_bram_rd_addr = 0;
            mask_bram_rd_addr = 0;
        end

    endcase
end



endmodule