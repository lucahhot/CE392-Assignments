// This module will take in the output of the hysteresis stage and the mask, and 
// calculate the accum_buff which will be a 2D array of all the possible rhos and thetas. 
// I think that it will be easiest to have the selection of lanes also in this module since 
// we only have one set of wires to access the BRAM data and they need to be driven within this
// module so we can't have another module drive them. This module will output the rho and theta
// values for the left and right lanes for the highlight module to draw them out. 

// Comment this line out for synthesis but uncomment for simulations
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
    output logic [$clog2(IMAGE_SIZE)-1:0]   mask_bram_rd_addr,
    // DONE signals
    output logic accum_buff_done,
    output logic hough_done,
    // LANE OUTPUTS
    output logic [ACCUM_BUFF_WIDTH-1:0] output_data,
    output logic signed [15:0] left_rho_out,
    output logic signed [15:0] right_rho_out,
    output logic [THETA_BITS-1:0] left_theta_out,
    output logic [THETA_BITS-1:0] right_theta_out
    // output logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff_out
);

typedef enum logic [3:0] {ZERO,IDLE,ACCUMULATE,THETA_LOOP,SELECT_LOOP,AVERAGE_1,AVERAGE_2,AVERAGE_3,OUTPUT} state_types;
state_types state, next_state;

// X and Y indices for the accumulation stage (using the adjusted width and height)
// Giving it 1 extra bit since we are making them signed for the dequantization to work
logic signed [$clog2(ENDING_X):0] x, x_c;
logic signed [$clog2(ENDING_Y):0] y, y_c;

// Read values from the hyseteresis and mask BRAMs 
logic [7:0] hysteresis, mask;

// Theta index for the accumulation stage 
logic [THETA_BITS-1:0] theta, theta_c;

// Register/wires to hold rho value (will be calculated using the x and y values)
logic signed [15:0] rho, rho_c, rho_unquantized_x, rho_unquantized_y;

// Wires to hold the quantized sin and cos values for the theta loop (for some reason it doesn't work when referencing
// the SIN_QUANTIZED and COS_QUANTIZED arrays directly from globals.sv)
logic signed [TRIG_DATA_SIZE-1:0] sin_quantized, cos_quantized;

// Rho index signal to be able to zero the BRAMs in the ZERO state
logic [$clog2(RHO_RANGE)-1:0] rho_index, rho_index_c;

// First cycle signals for THETA_LOOP
logic first_theta_cycle, first_theta_cycle_c;

// First cycle signals for the SELECT_LOOP
logic first_select_cycle, first_select_cycle_c;

// Variables for the SELECT_LOOP
logic [0:THETA_UNROLL-1][$clog2(NUM_LANES/THETA_UNROLL)-1:0] left_index, left_index_c, right_index, right_index_c;
logic signed [0:THETA_UNROLL-1][0:NUM_LANES/THETA_UNROLL-1][15:0] left_rhos, left_rhos_c, right_rhos, right_rhos_c;
logic [0:THETA_UNROLL-1][0:NUM_LANES/THETA_UNROLL-1][THETA_BITS-1:0] left_thetas, left_thetas_c, right_thetas, right_thetas_c;

// // Accumulator buffer BRAM signals
logic [0:THETA_UNROLL-1][$clog2(RHO_RANGE*THETAS/THETA_UNROLL)-1:0] accum_buff_rd_addr;
logic [0:THETA_UNROLL-1][$clog2(RHO_RANGE*THETAS/THETA_UNROLL)-1:0] accum_buff_wr_addr;
logic [0:THETA_UNROLL-1]                                            accum_buff_wr_en;
logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0]                      accum_buff_wr_data;
logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0]                      accum_buff_rd_data;

// 3D flip flop array for the accumulator buffer for testing only (not enough registers on the de10nano to synthesize this)
// logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff, accum_buff_c;

// Lane sums to be abel to average the values of rhos and thetas
logic signed [0:THETA_UNROLL-1][23:0] left_rho_sum, left_rho_sum_c, right_rho_sum, right_rho_sum_c, total_left_rho_sum, total_left_rho_sum_c, total_right_rho_sum, total_right_rho_sum_c;
logic [0:THETA_UNROLL-1][15:0] left_theta_sum, left_theta_sum_c, right_theta_sum, right_theta_sum_c, total_left_theta_sum, total_left_theta_sum_c, total_right_theta_sum, total_right_theta_sum_c;

// Wires to hold left and right rho/theta outputs
// logic signed [15:0] left_rho_out,
// logic signed [15:0] right_rho_out,
// logic [$clog2(THETAS)-1:0] left_theta_out,
// logic [$clog2(THETAS)-1:0] right_theta_out

// Accumulator buffer BRAM instantiation in generate loop
genvar i;
for (i = 0; i < THETA_UNROLL; i++) begin
    bram #(
        .BRAM_DATA_WIDTH(ACCUM_BUFF_WIDTH),
        .IMAGE_SIZE(RHO_RANGE*THETAS/THETA_UNROLL)
    ) accum_buff_bram (
        .clock(clock),
        .rd_addr(accum_buff_rd_addr[i]),
        .wr_addr(accum_buff_wr_addr[i]),
        .wr_en(accum_buff_wr_en[i]),
        .wr_data(accum_buff_wr_data[i]),
        .rd_data(accum_buff_rd_data[i])
    );
end

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= ZERO;
        x <= '0;
        y <= '0;
        theta <= '0;
        // accum_buff <= '{default: '{default: '{default: '0}}};
        rho_index <= '0;
        first_theta_cycle <= 1'b0;
        first_select_cycle <= 1'b0;
        rho <= '0;
        left_index <= '{default: '{default: '0}};
        right_index <= '{default: '{default: '0}};
        left_rhos <= '{default: '{default: '{default: '0}}};
        right_rhos <= '{default: '{default: '{default: '0}}};
        left_thetas <= '{default: '{default: '{default: '0}}};
        right_thetas <= '{default: '{default: '{default: '0}}};
        left_rho_sum <= '{default: '{default: '0}};
        right_rho_sum <= '{default: '{default: '0}};
        total_left_rho_sum <= '{default: '{default: '0}};
        total_right_rho_sum <= '{default: '{default: '0}};
        left_theta_sum <= '{default: '{default: '0}};
        right_theta_sum <= '{default: '{default: '0}};
        total_left_theta_sum <= '{default: '{default: '0}};
        total_right_theta_sum <= '{default: '{default: '0}};
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
        theta <= theta_c;
        // accum_buff <= accum_buff_c;
        rho_index <= rho_index_c;
        first_theta_cycle <= first_theta_cycle_c;
        first_select_cycle <= first_select_cycle_c;
        rho <= rho_c;
        left_index <= left_index_c;
        right_index <= right_index_c;
        left_rhos <= left_rhos_c;
        right_rhos <= right_rhos_c;
        left_thetas <= left_thetas_c;
        right_thetas <= right_thetas_c;
        left_rho_sum <= left_rho_sum_c;
        right_rho_sum <= right_rho_sum_c;
        total_left_rho_sum <= total_left_rho_sum_c;
        total_right_rho_sum <= total_right_rho_sum_c;
        left_theta_sum <= left_theta_sum_c;
        right_theta_sum <= right_theta_sum_c;
        total_left_theta_sum <= total_left_theta_sum_c;
        total_right_theta_sum <= total_right_theta_sum_c;
    end
end

always_comb begin
    next_state = state;
    x_c = x;
    y_c = y;
    theta_c = theta;
    rho_index_c = rho_index;
    first_theta_cycle_c = first_theta_cycle;
    first_select_cycle_c = first_select_cycle;
    rho_c = rho;
    // accum_buff_c = accum_buff;
    left_index_c = left_index;
    right_index_c = right_index;
    left_rhos_c = left_rhos;
    right_rhos_c = right_rhos;
    left_thetas_c = left_thetas;
    right_thetas_c = right_thetas;
    left_rho_sum_c = left_rho_sum;
    right_rho_sum_c = right_rho_sum;
    total_left_rho_sum_c = total_left_rho_sum;
    total_right_rho_sum_c = total_right_rho_sum;
    left_theta_sum_c = left_theta_sum;
    right_theta_sum_c = right_theta_sum;
    total_left_theta_sum_c = total_left_theta_sum;
    total_right_theta_sum_c = total_right_theta_sum;

    // Default values for the BRAM addresses
    hysteresis_bram_rd_addr = 0;
    mask_bram_rd_addr = 0;

    accum_buff_done = 1'b0;
    hough_done = 1'b0;
    
    for (int i = 0; i < THETA_UNROLL; i++) begin
        accum_buff_wr_en[i] = 1'b0;
    end

    case(state)

        // Zero state that executes at the beginning after a reset to initialize all the accum_buff BRAMs to zero,
        // and is then called at the end to reset the BRAMs to zero after the selection of lanes is also done for the next iamge frame
        ZERO: begin
            for (int i = theta; i < theta + THETA_UNROLL; i++) begin
                accum_buff_wr_en[i-theta] = 1'b1;
                accum_buff_wr_addr[i-theta] = (rho_index) * THETAS/THETA_UNROLL + i; 
                accum_buff_wr_data[i-theta] = '0;
            end
            // Increment theta by the unroll factor
            theta_c = theta + THETA_UNROLL;
            // If we've reached the end of thetas, increment the rho index
            if (theta_c >= THETAS) begin
                theta_c = 0;
                rho_index_c = rho_index + 1;
                // If we've reached the end of rhos, we're done zeroing the BRAMs
                if (rho_index_c == RHO_RANGE) begin
                    next_state = IDLE;
                    rho_index_c = 0;
                    theta_c = 0;
                end
            end
        end

        // Waits for the start signal to begin the accumulation stage 
        IDLE: begin
            if (start == 1'b1) begin
                next_state = ACCUMULATE;
                // Set the hysteresis and mask BRAM addresses so the BRAM output can be read in the next cycle
                // We start at STARTING_X and STARTING_Y to save cycles
                // Note: we start at STARTING_X + 5 and STARTING_Y + 5 because the mask is 5 pixels away from the edge
                // of our starting and ending points due to padding for the canny edge detection algorithm
                hysteresis_bram_rd_addr = (STARTING_Y+5) * WIDTH + (STARTING_X+5);
                mask_bram_rd_addr = (STARTING_Y+5) * WIDTH + (STARTING_X+5);
                // Set the initial x and y coordinates
                x_c = STARTING_X + 5;
                y_c = STARTING_Y + 5;
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
                first_theta_cycle_c = 1'b1;
            end else begin
                // Increment the x and y values to move to the next pixel
                if (x == ENDING_X - 5) begin
                    if (y == ENDING_Y - 5) begin
                        // We've reached the end of the image so we're done
                        next_state = SELECT_LOOP;
                        first_select_cycle_c = 1'b1;
                        rho_index_c = 0;
                        theta_c = 0;
                    end else begin
                        x_c = STARTING_X + 5;
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

        // THETA_LOOP stage to loop through all thetas for each pixel and calculate the rho value.
        // Will unroll this according to the THETA_UNROLL parameter to save cycles since none of the
        // calculations are dependent on each other. Will also pipeline the setting of BRAM read addresses
        // with the stage that is reading the BRAMs to essentially cut down the cycles needed for each pixel
        // by 2. 
        THETA_LOOP: begin
            first_theta_cycle_c = 1'b0; // Reset this flag to 0 as soon as we enter this loop
            // For loop to perform the unrolled theta loop
            for (int i = theta; i < theta + THETA_UNROLL; i++) begin
                if (theta < THETAS) begin
                    // Calculate the rho value using the x, y, and quantized trig values in globals.sv
                    sin_quantized = SIN_QUANTIZED[i];
                    cos_quantized = COS_QUANTIZED[i];
                    rho_unquantized_x = DEQUANTIZE(x * cos_quantized);
                    rho_unquantized_y = DEQUANTIZE(y * sin_quantized);
                    rho_c = (rho_unquantized_x + rho_unquantized_y);
                    // Once we have calculated the rho value, we can set the addresses to read from the accum_buff BRAMs in the next cycle
                    accum_buff_rd_addr[i-theta] = (rho_c+RHOS) * THETAS/THETA_UNROLL + i; 
                    // accum_buff_c[rho_c + RHOS][i] = accum_buff[rho_c + RHOS][i] + 1;
                end
                // Only accumulate if we are not in the first cycle since we have not read the first value from the BRAMs (happens in cycle 2)
                if (first_theta_cycle == 1'b0) begin
                    accum_buff_wr_en[i-theta] = 1'b1;
                    // The write address is using the previous value of rho (not the current cycle's one that is used in the new read address)
                    accum_buff_wr_addr[i-theta] = (rho+RHOS) * THETAS/THETA_UNROLL + i - THETA_UNROLL; 
                    
                    // If we are going to go past 2^ACCUM_BUFF_WIDTH - 1, we will just saturate the value to 2^ACCUM_BUFF_WIDTH-1
                    // This is okay as long as the max value of the accum_buff is larger than HOUGH_TRANSFORM_THRESHOLD and it will save us resources for the BRAMs
                    // (might make it faster too)
                    if (accum_buff_rd_data[i-theta] >= (2**ACCUM_BUFF_WIDTH - 1)) begin
                        accum_buff_wr_data[i-theta] = 2**ACCUM_BUFF_WIDTH - 1;
                    end else begin
                        accum_buff_wr_data[i-theta] = accum_buff_rd_data[i-theta] + 1;
                    end
                    // accum_buff_wr_data[i-theta] = accum_buff_rd_data[i-theta] + 1;
                end
            end
            // Increment the theta value by the unroll factor
            theta_c = theta + THETA_UNROLL;
            // If we've reached the end of thetas, do one more iteration of this loop to accumulate the last value read (theta = 179)
            // before switching back to the ACCUMULATE stage
            if (theta_c >= THETAS + THETA_UNROLL) begin
                next_state = ACCUMULATE;
                theta_c = 0;
                // We need to update the x and y coordinates to and set the addresses for the next pixel
                // so the BRAM outputs can be ready in the next cycle
                if (x == ENDING_X - 5) begin
                    if (y == ENDING_Y - 5) begin
                        // We've reached the end of the image so we're done
                        next_state = SELECT_LOOP;
                        first_select_cycle_c = 1'b1;
                        rho_index_c = 0;
                        theta_c = 0;
                    end else begin
                        x_c = STARTING_X + 5;
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

        // SELECT_LOOP stage that goes through the accum_buff BRAMs and select lines that pass a certain threshold and 
        // add them to arrays to keep before averaging them later
        SELECT_LOOP: begin
            first_select_cycle_c = 1'b0; // Reset this flag to 0 as soon as we enter this loop 
            for (int i = theta; i < theta + THETA_UNROLL; i++) begin
                if (theta < THETAS)
                    // Set addresses to read from accum_buff BRAMs
                    accum_buff_rd_addr[i-theta] = (rho_index) * THETAS/THETA_UNROLL + i;
            end
            // Only check the values inside the accum_buff BRAMs after the first cycle
            if (first_select_cycle == 1'b0) begin
                accum_buff_done = 1'b1;
                // Check if the value is greater than HOUGH_TRANSFORM_THRESHOLD
                for (int i = theta; i < theta + THETA_UNROLL; i++) begin
                    output_data = accum_buff_rd_data[i-theta];
                    if (accum_buff_rd_data[i-theta] >= HOUGH_TRANSFORM_THRESHOLD) begin
                        // Determine if this "lane" should be a left or right lane
                        if (i > (90 + 10)) begin
                            left_rhos_c[i-theta][left_index] = rho_index-RHOS;
                            left_thetas_c[i-theta][left_index] = i - THETA_UNROLL;
                            left_index_c[i-theta] = left_index[i-theta] + 1;
                        end else if (i < (90 - 10)) begin
                            right_rhos_c[i-theta][right_index] = rho_index-RHOS;
                            right_thetas_c[i-theta][right_index] = i - THETA_UNROLL;
                            right_index_c[i-theta] = right_index[i-theta] + 1;
                        end
                    end
                end
            end
            // Increment the theta value by the unroll factor
            theta_c = theta + THETA_UNROLL;
            // If we've reached the end of thetas, do one more iteration to check the last value read (theta = 179)
            // before incrementing the rho_index
            if (theta_c >= THETAS + THETA_UNROLL) begin
                theta_c = 0;
                rho_index_c = rho_index + 1;
                // If we've reached the end of rhos, we can move on to the next stage
                if (rho_index_c == RHO_RANGE) begin
                    next_state = AVERAGE_1;
                    rho_index_c = 0;
                end 
            end 
        end 
        
        // The AVERAGE states takes the selected left and right lanes and averages them to ouput a single left and right lane
        AVERAGE_1: begin
            // // First accumulate the sum of rhos and thetas for the left and right lanes for each set of UNROLL rhos and thetas
            for (int unroll_index = 0; unroll_index < THETA_UNROLL; unroll_index++) begin
                // Summing up the left rhos and thetas
                for (int i = 0; i < left_index[unroll_index]; i++) begin
                    left_rho_sum_c[unroll_index] = $signed(left_rho_sum_c[unroll_index]) + $signed(left_rhos[unroll_index][i]);
                    left_theta_sum_c[unroll_index] = $unsigned(left_theta_sum_c[unroll_index]) + $unsigned(left_thetas[unroll_index][i]);
                end
                // Summing up the right rhos and thetas
                for (int i = 0; i < right_index[unroll_index]; i++) begin
                    right_rho_sum_c[unroll_index] = $signed(right_rho_sum_c[unroll_index]) + $signed(right_rhos[unroll_index][i]);
                    right_theta_sum_c[unroll_index] = $unsigned(right_theta_sum_c[unroll_index]) + $unsigned(right_thetas[unroll_index][i]);
                end
            end
            next_state = AVERAGE_2; 
        end
        
        AVERAGE_2: begin
            // Now sum up the left and right rhos and thetas for all the unrolled sets
            for (int unroll_index = 0; unroll_index < THETA_UNROLL; unroll_index++) begin
                total_left_rho_sum_c = $signed(total_left_rho_sum_c) + $signed(left_rho_sum[unroll_index]);
                total_left_theta_sum_c = $unsigned(total_left_theta_sum_c) + $unsigned(left_theta_sum[unroll_index]);
                total_right_rho_sum_c = $signed(total_right_rho_sum_c) + $signed(right_rho_sum[unroll_index]);
                total_right_theta_sum_c = $unsigned(total_right_theta_sum_c) + $unsigned(right_theta_sum[unroll_index]);
            end
            next_state = AVERAGE_3;
        end

        AVERAGE_3: begin
            // Now we can divide the total sums by the number of lanes to get the average
            left_theta_out = $unsigned(total_left_theta_sum) / $unsigned(left_index);
            left_rho_out = $signed(total_left_rho_sum) / $signed(left_index);
            right_theta_out = $unsigned(total_right_theta_sum) / $unsigned(right_index);
            right_rho_out = $signed(total_right_rho_sum) / $signed(right_index);
            next_state = OUTPUT;
        end

        // OUTPUT stage which loops until the divisions are complete (have to wait until all 4 divisions are complete)
        OUTPUT: begin
            hough_done = 1'b1;
        end

    endcase
end



endmodule