module gaussian_blur #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
)(
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

// The sum of the Gaussian matrix
parameter logic [3:0] gaussian_filter[5][5] = '{'{2,4,5,4,2},
                                                '{4,9,12,9,4},
                                                '{5,12,15,12,5},
                                                '{4,9,12,9,4},
                                                '{2,4,5,4,2}};

typedef enum logic [1:0] {PROLOGUE,FILTER,DIVIDE,OUTPUT} state_types;
state_types state, next_state;
parameter SHIFT_REG_LEN = 4*WIDTH+5;
parameter PIXEL_COUNT = WIDTH*HEIGHT;

// Shift register
logic [0:SHIFT_REG_LEN-1] [7:0] shift_reg;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// Counters for prologue (to get the first pixel in the center of the 5x5 filter box)
logic [$clog2(2*WIDTH+3)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;

// Numerator and denominator values 
logic [23:0] numerator, numerator_c, denominator, denominator_c;

// Gaussian blur value
logic [23:0] gaussian_blur;

// Wires to hold temporary pixel values
logic [24:0][7:0] pixel_values;

// Pixel counter
logic [4:0] pixel_counter;

// Divider signals
logic start_div, div_overflow_out, div_valid_out;
logic [23:0] dividend, divisor, div_quotient_out, div_remainder_out;

div #(
    .DIVIDEND_WIDTH(24),
    .DIVISOR_WIDTH(24)
) divider_inst (
    .clk(clock),
    .reset(reset),
    .valid_in(start_div),
    .dividend(dividend),
    .divisor(divisor),
    .quotient(div_quotient_out),
    .remainder(div_remainder_out),
    .overflow(div_overflow_out),
    .valid_out(div_valid_out)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        numerator <= '0;
        denominator <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        col <= col_c;
        row <= row_c;
        counter <= counter_c;
        numerator <= numerator_c;
        denominator <= denominator_c;
    end
end

always_comb begin
    next_state = state;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    numerator_c = numerator;
    denominator_c = denominator;
    in_rd_en = 1'b0;
    out_wr_en = 1'b0;
    out_din = '0;

    start_div = 1'b0;
    dividend = 0;
    divisor = 0;

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // gaussian_blur function can go through every single pixel
    // Only shift a new value in if state is not in S2 (writing gaussian blur value to FIFO)
    if (state != OUTPUT && state != DIVIDE) begin
        if (in_empty == 1'b0) begin
            // Implementing a shift right register
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding
        // Basically for the last 2*WIDTH+3 pixels, shift in 0s since there are no more image pixels
        end else if ((row*WIDTH) + col > (PIXEL_COUNT-1) - (2*WIDTH+3)) begin
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
    end

    case(state)

        // Prologue
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start gaussian filter
            if (counter < 2*WIDTH + 3) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = FILTER;
        end

        // Gaussian blurring
        FILTER: begin

            // Grabbing correct pixel values from the shift register
            pixel_values[0] = shift_reg[0];
            pixel_values[1] = shift_reg[1];
            pixel_values[2] = shift_reg[2];
            pixel_values[3] = shift_reg[3];
            pixel_values[4] = shift_reg[4];
            pixel_values[5] = shift_reg[WIDTH];
            pixel_values[6] = shift_reg[WIDTH+1];
            pixel_values[7] = shift_reg[WIDTH+2];
            pixel_values[8] = shift_reg[WIDTH+3];
            pixel_values[9] = shift_reg[WIDTH+4];
            pixel_values[10] = shift_reg[WIDTH*2];
            pixel_values[11] = shift_reg[WIDTH*2+1];
            pixel_values[12] = shift_reg[WIDTH*2+2];
            pixel_values[13] = shift_reg[WIDTH*2+3];
            pixel_values[14] = shift_reg[WIDTH*2+4];
            pixel_values[15] = shift_reg[WIDTH*3];
            pixel_values[16] = shift_reg[WIDTH*3+1];
            pixel_values[17] = shift_reg[WIDTH*3+2];
            pixel_values[18] = shift_reg[WIDTH*3+3];
            pixel_values[19] = shift_reg[WIDTH*3+4];
            pixel_values[20] = shift_reg[WIDTH*4];
            pixel_values[21] = shift_reg[WIDTH*4+1];
            pixel_values[22] = shift_reg[WIDTH*4+2];
            pixel_values[23] = shift_reg[WIDTH*4+3];
            pixel_values[24] = shift_reg[WIDTH*4+4];

            pixel_counter = 0;
            numerator_c = 0;
            denominator_c = 0;

            // Calculate MAC for the numerator (might need to separate to speed up this cycle)
            for (int i = -2; i <= 2; i++) begin
                for (int j = -2; j <= 2; j++) begin
                    // Checking if the pixel +/- the 5x5 offset value is within the image coordinates and ignore if not
                    if ((row+i) >= 0 && (row+i) < HEIGHT && (col+j) >= 0 && (col+j) < WIDTH) begin
                        numerator_c = numerator_c + pixel_values[pixel_counter] * gaussian_filter[i+2][j+2];
                        denominator_c = denominator_c + gaussian_filter[i+2][j+2];
                    end
                    pixel_counter = pixel_counter + 1;
                end
            end

            // Increment col and row trackers
            if (col == WIDTH - 1) begin
                col_c = 0;
                row_c++;
            end else
                col_c++;

            start_div = 1'b1;
            dividend = numerator_c;
            divisor = denominator_c;
            next_state = OUTPUT;
            
        end

        // Waiting for division and writing to FIFO
        OUTPUT: begin
            // Wait for division to complete
            if (div_valid_out == 1'b1) begin
                if (out_full == 1'b0) begin
                    gaussian_blur = div_quotient_out;
                    // Accounting for saturation
                    gaussian_blur = (gaussian_blur > 8'hff) ? 8'hff : gaussian_blur;
                    out_din = 8'(gaussian_blur);
                    out_wr_en = 1'b1;
                    next_state = FILTER;
                    // If we have reached the last pixel of the entire image, go back to S0 and reset everything
                    if (row == HEIGHT && col == WIDTH) begin
                        next_state = PROLOGUE;
                        row_c = 0;
                        col_c = 0;
                        counter_c = 0;
                        numerator_c = 0;
                        denominator_c = 0;
                        shift_reg_c = '{default: '{default: '0}};
                    end
                end
            end else begin
                // Cycle through this state
                next_state = OUTPUT;
            end
        end

        default: begin
            next_state = PROLOGUE;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_din = '0;
            shift_reg_c = '{default: '{default: '0}};
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            numerator_c = 'X;
            denominator_c = 'X;
            start_div = 1'b0;
        end

    endcase

end

endmodule