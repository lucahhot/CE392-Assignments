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
parameter DENOMINATOR = 159;
parameter gaussian_filter[5][5] = '{'{2,4,5,4,2},
                                            '{4,9,912,9,4},
                                            '{5,12,15,12,5},
                                            '{4,9,912,9,4},
                                            '{2,4,5,4,2}};

typedef enum logic [1:0] {S0, S1, S2} state_types;
state_types state, next_state;
parameter SHIFT_REG_LEN = 4*WIDTH+5;
parameter PIXEL_COUNT = WIDTH*HEIGHT;

// Shift register
logic shift_reg [SHIFT_REG_LEN-1:0][7:0];
logic shift_reg_c [SHIFT_REG_LEN-1:0][7:0] ;

// Counters for prologue (to get the first pixel in the center of the 5x5 filter box)
logic [$clog2(2*WIDTH+3)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;

// Temp value
logic [23:0] numerator, numerator_c;

// Gaussian blur value
logic [23:0] gaussian_blur;

// Wires to hold temporary pixel values
logic [24:0][7:0] pixel_values;

// Pixel counter
logic [4:0] pixel_counter;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        numerator <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        col <= col_c;
        row <= row_c;
        counter <= counter_c;
        numerator <= numerator_c;
    end
end

always_comb begin
    next_state = state;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    numerator_c = numerator;
    in_rd_en = 1'b0;
    out_wr_en = 1'b0;
    out_din = '0;

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // gaussian_blur function can go through every single pixel
    // Only shift a new value in if state is not in S2 (writing sobel value to FIFO)
    if (state != S2) begin
        if (in_empty == 1'b0) begin
            // Implementing a shift right register
            shift_reg_c[SHIFT_REG_LEN-2:0] = shift_reg[SHIFT_REG_LEN-1:1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding
        // Basically for the last 2*WIDTH+3 pixels, shift in 0s since there are no more image pixels
        end else if ((row*HEIGHT) + col > (PIXEL_COUNT-1) - (2*WIDTH+3)) begin
            shift_reg_c[SHIFT_REG_LEN-2:0] = shift_reg[SHIFT_REG_LEN-1:1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
    end

    case(state)

        // Prologue
        S0: begin
            // Waiting for shift register to fill up enough to start gaussian filter
            if (counter < 2*WIDTH + 3) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = S1;
        end

        // Gaussian blurring
        S1: begin
            // If we are on an edge pixel, the sobel value will be zero
            if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
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

                // Calculate MAC for the numerator (might need to separate to speed up this cycle)
                for (int i = -2; i <= 2; i++) begin
                    for (int j = -2; j <= 2; j++) begin
                        numerator_c = numerator_c + pixel_values[pixel_counter] * gaussian_filter[i+2][j+2];
                        pixel_counter = pixel_counter + 1;
                    end
                end
            end else begin
                numerator_c = '0;
            end
            // Increment col and row trackers
            if (col == WIDTH - 1) begin
                col_c = 0;
                row_c++;
            end else
                col_c++;

            next_state = S2;

        end

        // Division and writing to FIFO
        S2: begin
            if (out_full == 1'b0) begin
                gaussian_blur = numerator / DENOMINATOR;
                // Accounting for saturation
                gaussian_blur = ($signed(gaussian_blur) > 8'hff) ? 8'hff : gaussian_blur;
                out_din = 8'(gaussian_blur);
                out_wr_en = 1'b1;
                next_state = S0;
            end
        end

        default: begin
            next_state = S0;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_din = '0;
            shift_reg_c = '{default: '{default: '0}};
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            numerator_c = 'X;
        end

    endcase

end

endmodule