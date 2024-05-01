// This module will take in the output of the hysteresis stage and the mask, and 
// calculate the accum_buff which will be a 2D array of all the possible rhos and thetas. 
// I think that it will be easiest to have the selection of lanes also in this module since 
// we only have one set of wires to access the BRAM data and they need to be driven within this
// module so we can't have another module drive them. This module will output the rho and theta
// values for the left and right lanes for the highlight module to draw them out. 

// Comment this line out for synthesis but uncomment for simulations
// `include "globals.sv"

module hough (
    input  logic        clock,
    input  logic        reset,
    input  logic        start,
    // HYSTERESIS INPUTS from bram_2d
    input  logic [7:0]                              hysteresis_bram_rd_data,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   hysteresis_bram_rd_addr,
    // MASK INPUTs from bram_2d
    input  logic [7:0]                              mask_bram_rd_data,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   mask_bram_rd_addr,
    // DONE signals
    output logic accum_buff_done,
    output logic hough_done,
    // LANE OUTPUTS
    output logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0] output_data,
    output logic signed [15:0] left_rho_out,
    output logic signed [15:0] right_rho_out,
    output logic [THETA_BITS-1:0] left_theta_out,
    output logic [THETA_BITS-1:0] right_theta_out
    // output logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff_out
);

parameter LANES_PER_BRAM = NUM_LANES/THETA_UNROLL + 1;
parameter LANE_INDEX_LENGTH = $clog2(LANES_PER_BRAM) + 1;

typedef enum logic [3:0] {ZERO,IDLE,ACCUMULATE,THETA_LOOP_MULTIPLY,THETA_LOOP_ACCUM,SELECT_LOOP,AVERAGE_1,AVERAGE_2,DIVIDE_START,DIVIDE_WAIT,OUTPUT} state_types;
state_types state, next_state;

// X and Y indices for the accumulation stage (using the adjusted width and height)
// Giving it 1 extra bit since we are making them signed for the dequantization to work
logic signed [$clog2(ENDING_X):0] x, x_c;
logic signed [$clog2(ENDING_Y):0] y, y_c;

// Indices to read the hysteresis and mask values from the BRAMs (will be from 0 to REDUCED_WIDTH-1 / REDUCED_HEIGHT-1)
logic [$clog2(REDUCED_WIDTH)-1:0] x_mask, x_mask_c;
logic [$clog2(REDUCED_HEIGHT)-1:0] y_mask, y_mask_c;

// Read values from the hyseteresis and mask BRAMs 
logic [7:0] hysteresis, mask;

// Theta index for the accumulation stage 
logic [THETA_BITS-1:0] theta, theta_c;

// Register/wires to hold rho value (will be calculated using the x and y values)
logic signed [0:THETA_UNROLL-1][15:0] rho, rho_c, rho_unquantized_x, rho_unquantized_x_c, rho_unquantized_y, rho_unquantized_y_c;

// Wires to hold the quantized sin and cos values for the theta loop (for some reason it doesn't work when referencing
// the SIN_QUANTIZED and COS_QUANTIZED arrays directly from globals.sv)
logic signed [0:THETA_UNROLL-1][TRIG_DATA_SIZE-1:0] sin_quantized, cos_quantized;

// Rho index signal to be able to zero the BRAMs in the ZERO state
logic [$clog2(RHO_RANGE)-1:0] rho_index, rho_index_c;

// First cycle signals for THETA_LOOP
logic first_theta_cycle, first_theta_cycle_c;

// First cycle signals for the SELECT_LOOP
logic first_select_cycle, first_select_cycle_c;

// // Accumulator buffer BRAM signals
logic [0:THETA_UNROLL-1][$clog2(RHO_RANGE*THETA_FACTOR)-1:0] accum_buff_rd_addr;
logic [0:THETA_UNROLL-1][$clog2(RHO_RANGE*THETA_FACTOR)-1:0] accum_buff_wr_addr;
logic [0:THETA_UNROLL-1]                                            accum_buff_wr_en;
logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0]                      accum_buff_wr_data;
logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0]                      accum_buff_rd_data;

// Variables for the SELECT_LOOP
logic [0:THETA_UNROLL-1][LANE_INDEX_LENGTH-1:0] left_index, left_index_c, right_index, right_index_c;
logic signed [0:THETA_UNROLL-1][0:LANES_PER_BRAM-1][15:0] left_rhos, left_rhos_c, right_rhos, right_rhos_c;
logic [0:THETA_UNROLL-1][0:LANES_PER_BRAM-1][THETA_BITS-1:0] left_thetas, left_thetas_c, right_thetas, right_thetas_c;

// 3D flip flop array for the accumulator buffer for testing only (not enough registers on the de10nano to synthesize this)
// logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff, accum_buff_c;

// Lane sums to be able to average the values of rhos and thetas
logic signed [0:THETA_UNROLL-1][23:0] left_rho_sum, left_rho_sum_c, right_rho_sum, right_rho_sum_c;
logic [0:THETA_UNROLL-1][15:0] left_theta_sum, left_theta_sum_c, right_theta_sum, right_theta_sum_c;

// Total sums across all the UNROLL sets (including the index sums)
logic signed [23:0] total_left_rho_sum, total_left_rho_sum_c, total_right_rho_sum, total_right_rho_sum_c;
logic [15:0] total_left_theta_sum, total_left_theta_sum_c, total_right_theta_sum, total_right_theta_sum_c;
logic [$clog2(NUM_LANES)-1:0] total_left_index_sum, total_left_index_sum_c, total_right_index_sum, total_right_index_sum_c;

// Summation counters for the left and right lanes
logic [LANE_INDEX_LENGTH-1:0] left_sum_counter, left_sum_counter_c, right_sum_counter, right_sum_counter_c;
logic [$clog2(THETA_UNROLL)-1:0] theta_unroll_counter, theta_unroll_counter_c;

// Accumulator buffer BRAM instantiation in generate loop
genvar i;
for (i = 0; i < THETA_UNROLL; i++) begin
    bram #(
        .BRAM_DATA_WIDTH(ACCUM_BUFF_WIDTH),
        .IMAGE_SIZE(RHO_RANGE*THETA_FACTOR)
    ) accum_buff_bram (
        .clock(clock),
        .rd_addr(accum_buff_rd_addr[i]),
        .wr_addr(accum_buff_wr_addr[i]),
        .wr_en(accum_buff_wr_en[i]),
        .wr_data(accum_buff_wr_data[i]),
        .rd_data(accum_buff_rd_data[i])
    );
end

// Divider modules and signals to divide at the end of the averaging stages
logic start_div_left_rho, start_div_right_rho, start_div_left_theta, start_div_right_theta;
logic div_valid_out_left_rho, div_valid_out_right_rho, div_valid_out_left_theta, div_valid_out_right_theta;
logic signed [23:0] dividend_left_rho, dividend_right_rho, div_quotient_out_left_rho, div_quotient_out_right_rho;
logic [15:0] dividend_left_theta, dividend_right_theta, div_quotient_out_left_theta, div_quotient_out_right_theta;
logic [LANE_INDEX_LENGTH-1:0] divisor_left_rho, divisor_right_rho, divisor_left_theta, divisor_right_theta;

// Divide done signals (need these because div_valid_out are only asserted for 1 clock cycle)
logic div_done_left_rho, div_done_left_rho_c, div_done_right_rho, div_done_right_rho_c, div_done_left_theta, div_done_left_theta_c, div_done_right_theta, div_done_right_theta_c;

// Registers to keep the quotients until all 4 divides are completed
logic signed [23:0] left_rho_quotient, left_rho_quotient_c, right_rho_quotient, right_rho_quotient_c;
logic [15:0] left_theta_quotient, left_theta_quotient_c, right_theta_quotient, right_theta_quotient_c;

// Left and right rho divides are SIGNED
div_signed #(
    .DIVIDEND_WIDTH(24),
    .DIVISOR_WIDTH(LANE_INDEX_LENGTH)
) div_left_rho (
    .clk(clock),
    .reset(reset),
    .valid_in(start_div_left_rho),
    .dividend(dividend_left_rho),
    .divisor(divisor_left_rho),
    .quotient(div_quotient_out_left_rho),
    .valid_out(div_valid_out_left_rho)
);

div_signed #(
    .DIVIDEND_WIDTH(24),
    .DIVISOR_WIDTH(LANE_INDEX_LENGTH)
) div_right_rho (
    .clk(clock),
    .reset(reset),
    .valid_in(start_div_right_rho),
    .dividend(dividend_right_rho),
    .divisor(divisor_right_rho),
    .quotient(div_quotient_out_right_rho),
    .valid_out(div_valid_out_right_rho)
);

// Left and right theta divides are UNSIGNED
div_unsigned #(
    .DIVIDEND_WIDTH(16),
    .DIVISOR_WIDTH(LANE_INDEX_LENGTH)
) div_left_theta (
    .clk(clock),
    .reset(reset),
    .valid_in(start_div_left_theta),
    .dividend(dividend_left_theta),
    .divisor(divisor_left_theta),
    .quotient(div_quotient_out_left_theta),
    .valid_out(div_valid_out_left_theta)
);

div_unsigned #(
    .DIVIDEND_WIDTH(16),
    .DIVISOR_WIDTH(LANE_INDEX_LENGTH)
) div_right_theta (
    .clk(clock),
    .reset(reset),
    .valid_in(start_div_right_theta),
    .dividend(dividend_right_theta),
    .divisor(divisor_right_theta),
    .quotient(div_quotient_out_right_theta),
    .valid_out(div_valid_out_right_theta)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= ZERO;
        x <= '0;
        y <= '0;
        theta <= '0;
        x_mask <= '0;
        y_mask <= '0;
        // accum_buff <= '{default: '{default: '{default: '0}}};
        rho_index <= '0;
        first_theta_cycle <= 1'b0;
        first_select_cycle <= 1'b0;
        rho <= '0;
        rho_unquantized_x <= '0;
        rho_unquantized_y <= '0;
        // Lane selection
        left_index <= '{default: '{default: '0}};
        right_index <= '{default: '{default: '0}};
        left_rhos <= '{default: '{default: '{default: '0}}};
        right_rhos <= '{default: '{default: '{default: '0}}};
        left_thetas <= '{default: '{default: '{default: '0}}};
        right_thetas <= '{default: '{default: '{default: '0}}};
        // Lane averaging
        left_rho_sum <= '{default: '{default: '0}};
        right_rho_sum <= '{default: '{default: '0}};
        total_left_rho_sum <= '0;
        total_right_rho_sum <= '0;
        left_theta_sum <= '{default: '{default: '0}};
        right_theta_sum <= '{default: '{default: '0}};
        total_left_theta_sum <= '0;
        total_right_theta_sum <= '0;
        total_left_index_sum <= '0;
        total_right_index_sum <= '0;
        left_sum_counter <= '0;
        right_sum_counter <= '0;
        theta_unroll_counter <= '0;
        // Division
        left_rho_quotient <= '0;
        right_rho_quotient <= '0;
        left_theta_quotient <= '0;
        right_theta_quotient <= '0;
        div_done_left_rho <= 1'b0;
        div_done_right_rho <= 1'b0;
        div_done_left_theta <= 1'b0;
        div_done_right_theta <= 1'b0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
        theta <= theta_c;
        x_mask <= x_mask_c;
        y_mask <= y_mask_c;
        // accum_buff <= accum_buff_c;
        rho_index <= rho_index_c;
        first_theta_cycle <= first_theta_cycle_c;
        first_select_cycle <= first_select_cycle_c;
        rho <= rho_c;
        rho_unquantized_x <= rho_unquantized_x_c;
        rho_unquantized_y <= rho_unquantized_y_c;
        // Lane selection
        left_index <= left_index_c;
        right_index <= right_index_c;
        left_rhos <= left_rhos_c;
        right_rhos <= right_rhos_c;
        left_thetas <= left_thetas_c;
        right_thetas <= right_thetas_c;
        // Lane averaging
        left_rho_sum <= left_rho_sum_c;
        right_rho_sum <= right_rho_sum_c;
        total_left_rho_sum <= total_left_rho_sum_c;
        total_right_rho_sum <= total_right_rho_sum_c;
        left_theta_sum <= left_theta_sum_c;
        right_theta_sum <= right_theta_sum_c;
        total_left_theta_sum <= total_left_theta_sum_c;
        total_right_theta_sum <= total_right_theta_sum_c;
        total_left_index_sum <= total_left_index_sum_c;
        total_right_index_sum <= total_right_index_sum_c;
        left_sum_counter <= left_sum_counter_c;
        right_sum_counter <= right_sum_counter_c;
        theta_unroll_counter <= theta_unroll_counter_c;
        // Division
        left_rho_quotient <= left_rho_quotient_c;
        right_rho_quotient <= right_rho_quotient_c;
        left_theta_quotient <= left_theta_quotient_c;
        right_theta_quotient <= right_theta_quotient_c;
        div_done_left_rho <= div_done_left_rho_c;
        div_done_right_rho <= div_done_right_rho_c;
        div_done_left_theta <= div_done_left_theta_c;
        div_done_right_theta <= div_done_right_theta_c;
    end
end

always_comb begin
    next_state = state;
    x_c = x;
    y_c = y;
    theta_c = theta;
    x_mask_c = x_mask;
    y_mask_c = y_mask;
    rho_index_c = rho_index;
    first_theta_cycle_c = first_theta_cycle;
    first_select_cycle_c = first_select_cycle;
    rho_c = rho;
    rho_unquantized_x_c = rho_unquantized_x;
    rho_unquantized_y_c = rho_unquantized_y;
    // accum_buff_c = accum_buff;
    // Lane selection
    left_index_c = left_index;
    right_index_c = right_index;
    left_rhos_c = left_rhos;
    right_rhos_c = right_rhos;
    left_thetas_c = left_thetas;
    right_thetas_c = right_thetas;
    // Lane averaging
    left_rho_sum_c = left_rho_sum;
    right_rho_sum_c = right_rho_sum;
    total_left_rho_sum_c = total_left_rho_sum;
    total_right_rho_sum_c = total_right_rho_sum;
    left_theta_sum_c = left_theta_sum;
    right_theta_sum_c = right_theta_sum;
    total_left_theta_sum_c = total_left_theta_sum;
    total_right_theta_sum_c = total_right_theta_sum;
    total_left_index_sum_c = total_left_index_sum;
    total_right_index_sum_c = total_right_index_sum;
    left_sum_counter_c = left_sum_counter;
    right_sum_counter_c = right_sum_counter;
    theta_unroll_counter_c = theta_unroll_counter;
    // Division
    left_rho_quotient_c = left_rho_quotient;
    right_rho_quotient_c = right_rho_quotient;
    left_theta_quotient_c = left_theta_quotient;
    right_theta_quotient_c = right_theta_quotient;
    div_done_left_rho_c = div_done_left_rho;
    div_done_right_rho_c = div_done_right_rho;
    div_done_left_theta_c = div_done_left_theta;
    div_done_right_theta_c = div_done_right_theta;

    // Default signals for the accum_buff BRAMs
    for (int j = 0; j < THETA_UNROLL; j++) begin
        accum_buff_wr_en[j] = 1'b0;
        // accum_buff_rd_addr[j] = 0; // We need the read addresses to remain as they were since we are reading across clock cycles
        accum_buff_wr_addr[j] = 0;
        accum_buff_wr_data[j] = '0;
    end

    output_data = '{default: '{default: '0}};
    left_rho_out = '0;
    right_rho_out = '0;
    left_theta_out = '0;
    right_theta_out = '0;

    // Divider default signal assignment
    start_div_left_rho = 1'b0;
    start_div_right_rho = 1'b0;
    start_div_left_theta = 1'b0;
    start_div_right_theta = 1'b0;
    dividend_left_rho = '0;
    dividend_right_rho = '0;
    dividend_left_theta = '0;
    dividend_right_theta = '0;
    divisor_left_rho = '0;
    divisor_right_rho = '0;
    divisor_left_theta = '0;
    divisor_right_theta = '0;

    // Default values for the BRAM addresses
    hysteresis_bram_rd_addr = 0;
    mask_bram_rd_addr = 0;

    // Done signals to the testbench
    accum_buff_done = 1'b0;
    hough_done = 1'b0;

    case(state)
        // Zero state that executes at the beginning after a reset to initialize all the accum_buff BRAMs to zero,
        // and is then called at the end to reset the BRAMs to zero after the selection of lanes is also done for the next iamge frame
        ZERO: begin
            for (int j = 0; j < THETA_UNROLL; j++) begin
                if ((j+theta) < THETAS) begin
                    accum_buff_wr_en[j] = 1'b1;
                    accum_buff_wr_addr[j] = (rho_index) * THETA_FACTOR + ((j+theta) >> THETA_DIVIDE_BITS);
                    // accum_buff_wr_addr[j] = (rho_index) * THETAS/THETA_UNROLL + ((j+theta) / THETA_UNROLL);
                    accum_buff_wr_data[j] = '0;
                end
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
                // Set the initial x and y coordinates. Note: we start at STARTING_X + 5 and STARTING_Y + 5 because the 
                // mask is 5 pixels away from the edge of our starting and ending points due to padding for the canny edge detection algorithm.
                // These coordinates will be used to calculate the rho value for each pixel.
                x_c = STARTING_X + 5;
                y_c = STARTING_Y + 5;
                // Set the initial x and y mask coordinates (start at 5 since we have 5 pixels of padding). These coordinates will be used to 
                // read from both the hysteresis and mask BRAMs since they are different dimensions than the original image.
                x_mask_c = 5;
                y_mask_c = 5;
                // Set the hysteresis and mask BRAM addresses so the BRAM output can be read in the next cycle
                hysteresis_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
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
                next_state = THETA_LOOP_MULTIPLY;
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
                        // The mask coordinates will be changed at the same time as x and y since they follow the same width and height but different actual values
                        x_mask_c = 5;
                        y_mask_c = y_mask + 1;
                        // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                        hysteresis_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                        mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                    end 
                end else begin
                    x_c = x + 1;
                    x_mask_c = x_mask + 1;
                    // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                    hysteresis_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                    mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                end
            end
        end

        // THETA_LOOP stage to loop through all thetas for each pixel and calculate the rho value.
        // Will unroll this according to the THETA_UNROLL parameter to save cycles since none of the
        // calculations are dependent on each other. Will also pipeline the setting of BRAM read addresses
        // with the stage that is reading the BRAMs to essentially cut down the cycles needed for each pixel
        // by 2. Need to split it up to run faster. 
        THETA_LOOP_MULTIPLY: begin
            for (int j = 0; j < THETA_UNROLL; j++) begin
                if (theta < THETAS) begin
                    // // Calculate the rho value using the x, y, and quantized trig values in globals.sv
                    sin_quantized[j] = SIN_QUANTIZED[j+theta];
                    cos_quantized[j] = COS_QUANTIZED[j+theta];
                    // rho_unquantized_x[j-theta] = 16'(32'($signed(x) * $signed(cos_quantized[j-theta]))/256);
                    rho_unquantized_x_c[j] = DEQUANTIZE($signed(x) * $signed(cos_quantized[j]));
                    rho_unquantized_y_c[j] = DEQUANTIZE($signed(y) * $signed(sin_quantized[j]));
                end
            end
            next_state = THETA_LOOP_ACCUM;
        end

        THETA_LOOP_ACCUM: begin
            first_theta_cycle_c = 1'b0; // Reset this flag to 0 as soon as we enter this loop
            for (int j = 0; j < THETA_UNROLL; j++) begin
                if ((j+theta) < THETAS) begin
                    rho_c[j] = ($signed(rho_unquantized_x[j]) + $signed(rho_unquantized_y[j]));
                    // Once we have calculated the rho value, we can set the addresses to read from the accum_buff BRAMs in the next cycle
                    accum_buff_rd_addr[j] = ($signed(rho_c[j])+$signed(RHOS)) * $signed(THETA_FACTOR) + ($signed(j+theta) >> THETA_DIVIDE_BITS); 
                    // accum_buff_rd_addr[j] = ($signed(rho_c[j])+$signed(RHOS)) * $signed(THETAS/THETA_UNROLL) + ($signed(j+theta) / THETA_UNROLL); 
                end
                // Only accumulate if we are not in the first cycle since we have not read the first value from the BRAMs (happens in cycle 2)
                if (first_theta_cycle == 1'b0) begin
                    accum_buff_wr_en[j] = 1'b1;
                    // The write address is using the previous value of rho (not the current cycle's one that is used in the new read address)
                    accum_buff_wr_addr[j] = ($signed(rho[j])+$signed(RHOS)) * $signed(THETA_FACTOR) + (($signed(j+theta) - $signed(THETA_UNROLL)) >> THETA_DIVIDE_BITS); 
                    // accum_buff_wr_addr[j] = ($signed(rho[j])+$signed(RHOS)) * $signed(THETAS/THETA_UNROLL) + (($signed(j+theta) - $signed(THETA_UNROLL)) / THETA_UNROLL); 

                    // If we are going to go past 2^ACCUM_BUFF_WIDTH - 1, we will just saturate the value to 2^ACCUM_BUFF_WIDTH-1
                    // This is okay as long as the max value of the accum_buff is larger than HOUGH_TRANSFORM_THRESHOLD and it will save us resources for the BRAMs
                    // (might make it faster too)
                    if (accum_buff_rd_data[j] >= (2**ACCUM_BUFF_WIDTH - 1)) begin
                        accum_buff_wr_data[j] = 2**ACCUM_BUFF_WIDTH - 1;
                    end else begin
                        accum_buff_wr_data[j] = accum_buff_rd_data[j] + 1;
                    end
                    // accum_buff_wr_data[j-theta] = accum_buff_rd_data[j-theta] + 1;
                end
            end
            // Increment the theta value by the unroll factor
            theta_c = theta + THETA_UNROLL;
            // If we've reached the end of thetas, do one more iteration of this loop to accumulate the last value read (theta = 179)
            // before switching back to the ACCUMULATE stage
            if (theta_c >= THETAS + THETA_UNROLL) begin
                next_state = ACCUMULATE;
                theta_c = 0;
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
                        // The mask coordinates will be changed at the same time as x and y since they follow the same width and height but different actual values
                        x_mask_c = 5;
                        y_mask_c = y_mask + 1;
                        // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                        hysteresis_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                        mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                    end 
                end else begin
                    x_c = x + 1;
                    x_mask_c = x_mask + 1;
                    // Set the addresses for the next pixel so the BRAM outputs can be ready in the next cycle
                    hysteresis_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                    mask_bram_rd_addr = y_mask_c * REDUCED_WIDTH + x_mask_c;
                end
            end else
                // Go back to THETA_LOOP_MULTIPLY
                next_state = THETA_LOOP_MULTIPLY;
        end

        // SELECT_LOOP stage that goes through the accum_buff BRAMs and select lines that pass a certain threshold and 
        // add them to arrays to keep before averaging them later
        SELECT_LOOP: begin
            first_select_cycle_c = 1'b0; // Reset this flag to 0 as soon as we enter this loop 
            for (int j = 0; j < THETA_UNROLL; j++) begin
                if ((j+theta) < THETAS)
                    // Set addresses to read from accum_buff BRAMs
                    accum_buff_rd_addr[j] = (rho_index) * THETA_FACTOR + ((j+theta) >> THETA_DIVIDE_BITS);
                    // accum_buff_rd_addr[j] = (rho_index) * THETAS/THETA_UNROLL + ((j+theta) / THETA_UNROLL);
            end
            // Only check the values inside the accum_buff BRAMs after the first cycle
            if (first_select_cycle == 1'b0) begin
                accum_buff_done = 1'b1;
                // Check if the value is greater than HOUGH_TRANSFORM_THRESHOLD
                for (int j = 0; j < THETA_UNROLL; j++) begin
                    output_data[j] = accum_buff_rd_data[j];
                    if (accum_buff_rd_data[j] >= HOUGH_TRANSFORM_THRESHOLD) begin
                        // Determine if this "lane" should be a left or right lane
                        if ((j+theta - THETA_UNROLL) > (90 + 10)) begin
                            left_rhos_c[j][left_index[j]] = rho_index - RHOS;
                            left_thetas_c[j][left_index[j]] = (j+theta) - THETA_UNROLL;
                            left_index_c[j] = left_index[j] + 1;
                        end else if ((j+theta - THETA_UNROLL) < (90 - 10)) begin
                            right_rhos_c[j][right_index[j]] = rho_index - RHOS;
                            right_thetas_c[j][right_index[j]] = (j+theta) - THETA_UNROLL;
                            right_index_c[j] = right_index[j] + 1;
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
            // First accumulate the sum of rhos and thetas for the left and right lanes for each set of UNROLL rhos and thetas
            // Check left_index and right_index to see if we have any more lanes to average (checking before in case there are no lanes)
            // Will move to the next set of UNROLL rhos and thetas once both left and right lanes are done
            if (left_sum_counter == left_index[theta_unroll_counter] && right_sum_counter == right_index[theta_unroll_counter]) begin
                // We're done averaging lanes in this UNROLL set so we can increment the theta_unroll_counter
                theta_unroll_counter_c = theta_unroll_counter + 1;
                if (theta_unroll_counter == THETA_UNROLL-1) begin
                    // We have finished going through all the UNROLL sets so we can move to the next stage
                    theta_unroll_counter_c = 0;
                    left_sum_counter_c = 0;
                    right_sum_counter_c = 0;
                    next_state = AVERAGE_2;
                end else begin
                    // If not, increment theta_unroll_counter and reset left and right sum counters
                    left_sum_counter_c = 0;
                    right_sum_counter_c = 0;
                    theta_unroll_counter_c = theta_unroll_counter + 1;
                end
            end else begin
                // If we have more left lanes to average
                if (left_sum_counter < left_index[theta_unroll_counter]) begin
                    // Summing up the left rhos and thetas
                    left_rho_sum_c[theta_unroll_counter] = $signed(left_rho_sum_c[theta_unroll_counter]) + $signed(left_rhos[theta_unroll_counter][left_sum_counter]);
                    left_theta_sum_c[theta_unroll_counter] = left_theta_sum_c[theta_unroll_counter] + left_thetas[theta_unroll_counter][left_sum_counter];
                    left_sum_counter_c = left_sum_counter + 1;
                end
                // If we have more right lanes to average
                if (right_sum_counter < right_index[theta_unroll_counter]) begin
                    // Summing up the right rhos and thetas
                    right_rho_sum_c[theta_unroll_counter] = $signed(right_rho_sum_c[theta_unroll_counter]) + $signed(right_rhos[theta_unroll_counter][right_sum_counter]);
                    right_theta_sum_c[theta_unroll_counter] = right_theta_sum_c[theta_unroll_counter] + right_thetas[theta_unroll_counter][right_sum_counter];
                    right_sum_counter_c = right_sum_counter + 1;
                end
            end
        end
        
        AVERAGE_2: begin
            // Now sum up the left and right rhos and thetas for all the unrolled sets
            total_left_rho_sum_c = total_left_rho_sum + left_rho_sum[theta_unroll_counter];
            total_left_theta_sum_c = total_left_theta_sum + left_theta_sum[theta_unroll_counter];
            total_right_rho_sum_c = total_right_rho_sum + right_rho_sum[theta_unroll_counter];
            total_right_theta_sum_c = total_right_theta_sum + right_theta_sum[theta_unroll_counter];
            total_left_index_sum_c = total_left_index_sum + left_index[theta_unroll_counter];
            total_right_index_sum_c = total_right_index_sum + right_index[theta_unroll_counter];
            // Change to AVERAGE_3 when we're done summing up all the unrolled sets
            if (theta_unroll_counter == THETA_UNROLL-1) 
                next_state = DIVIDE_START;
            else 
                theta_unroll_counter_c = theta_unroll_counter + 1;
        end

        // Start the divisions
        DIVIDE_START: begin
            // Now we can divide the total sums by the number of lanes to get the average
            // Set the divide signals to start divisions
            start_div_left_rho = 1'b1;
            start_div_right_rho = 1'b1;
            start_div_left_theta = 1'b1;
            start_div_right_theta = 1'b1;
            dividend_left_rho = total_left_rho_sum;
            dividend_right_rho = total_right_rho_sum;
            dividend_left_theta = total_left_theta_sum;
            dividend_right_theta = total_right_theta_sum;
            divisor_left_rho = total_left_index_sum;
            divisor_right_rho = total_right_index_sum;
            divisor_left_theta = total_left_index_sum;
            divisor_right_theta = total_right_index_sum;
            next_state = DIVIDE_WAIT;
        end

        // Wait for all 4 divides to be finished before switching to OUTPUT
        DIVIDE_WAIT: begin
            if (div_done_left_rho == 1'b1 && div_done_right_rho == 1'b1 && div_done_left_theta == 1'b1 && div_done_right_theta == 1'b1) begin
                next_state = OUTPUT;
            end else begin
                // If a divide is finished, set the div_done flag to 1, clock the quotients, and wait for the other divides to finish
                if (div_valid_out_left_rho == 1'b1) begin
                    div_done_left_rho_c = 1'b1;
                    left_rho_quotient_c = div_quotient_out_left_rho;
                end
                if (div_valid_out_right_rho == 1'b1) begin
                    div_done_right_rho_c = 1'b1;
                    right_rho_quotient_c = div_quotient_out_right_rho;
                end
                if (div_valid_out_left_theta == 1'b1) begin
                    div_done_left_theta_c = 1'b1;
                    left_theta_quotient_c = div_quotient_out_left_theta;
                end
                if (div_valid_out_right_theta == 1'b1) begin
                    div_done_right_theta_c = 1'b1;
                    right_theta_quotient_c = div_quotient_out_right_theta;
                end
            end
        end

        // Assign the output signals to the quotient register values and assert hough_done
        OUTPUT: begin
            left_rho_out = left_rho_quotient;
            right_rho_out = right_rho_quotient;
            left_theta_out = left_theta_quotient;
            right_theta_out = right_theta_quotient;
            hough_done = 1'b1;
            next_state = ZERO;
        end

        default: begin
            next_state = ZERO;
            x_c = 'X;
            y_c = 'X;
            theta_c = 'X;
            x_mask_c = 'X;
            y_mask_c = 'X;
            rho_index_c = 'X;
            first_theta_cycle_c = 'X;
            first_select_cycle_c = 'X;
            rho_c = 'X;
            // accum_buff_c = accum_buff;
            left_index_c = '{default: '{default: '0}};
            right_index_c = '{default: '{default: '0}};
            left_rhos_c = '{default: '{default: '{default: '0}}};
            right_rhos_c = '{default: '{default: '{default: '0}}};
            left_thetas_c = '{default: '{default: '{default: '0}}};
            right_thetas_c = '{default: '{default: '{default: '0}}};
            left_rho_sum_c = '{default: '{default: '0}};
            right_rho_sum_c = '{default: '{default: '0}};
            total_left_rho_sum_c = 'X;
            total_right_rho_sum_c = 'X;
            left_theta_sum_c = '{default: '{default: '0}};
            right_theta_sum_c = '{default: '{default: '0}};
            total_left_theta_sum_c = 'X;
            total_right_theta_sum_c = 'X;
            total_left_index_sum_c = 'X;
            total_right_index_sum_c = 'X;
            left_sum_counter_c = 'X;
            right_sum_counter_c = 'X;
            theta_unroll_counter_c = 'X;
            left_rho_quotient_c = 'X;
            right_rho_quotient_c = 'X;
            left_theta_quotient_c = 'X;
            right_theta_quotient_c = 'X;
            div_done_left_rho_c = 'X;
            div_done_right_rho_c = 'X;
            div_done_left_theta_c = 'X;
            div_done_right_theta_c = 'X;
            for (int j = 0; j < THETA_UNROLL; j++) begin
                accum_buff_wr_en[j] = 1'b0;
                accum_buff_rd_addr[j] = 0;
                accum_buff_wr_addr[j] = 0;
                accum_buff_wr_data[j] = '0;
            end
            output_data = '{default: '{default: '0}};
            left_rho_out = 'X;
            right_rho_out = 'X;
            left_theta_out = 'X;
            right_theta_out = 'X;
            start_div_left_rho = 1'b0;
            start_div_right_rho = 1'b0;
            start_div_left_theta = 1'b0;
            start_div_right_theta = 1'b0;
            dividend_left_rho = 'X;
            dividend_right_rho = 'X;
            dividend_left_theta = 'X;
            dividend_right_theta = 'X;
            divisor_left_rho = 'X;
            divisor_right_rho = 'X;
            divisor_left_theta = 'X;
            divisor_right_theta = 'X;
            hysteresis_bram_rd_addr = 0;
            mask_bram_rd_addr = 0;
            accum_buff_done = 1'b0;
            hough_done = 1'b0;
        end

    endcase
end



endmodule