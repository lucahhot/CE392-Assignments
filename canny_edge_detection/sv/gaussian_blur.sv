module gaussian_blur #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
)(
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0] in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

// The sum of the Gaussian matrix
parameter integer DENOMINATOR = 159;
parameter ingeger gaussian_filter[5][5] = {{2,4,5,4,2},
                                           {4,9,912,9,4},
                                           {5,12,15,12,5},
                                           {4,9,912,9,4},
                                           {2,4,5,4,2}};

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
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel5,
            pixel6, pixel7, pixel8, pixel9, pixel10,
            pixel11, pixel12, pixel13, pixel14, pixel15,
            pixel16, pixel17, pixel18, pixel19, pixel20,
            pixel21, pixel22, pixel23, pixel24, pixel25;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        shift_reg <= '{default: '{default; '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        numerator <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        col <= col_c;
        row <= row_c;
        temp_value_c;
        numerator <= numerator_c;
    end
end

always_comb begin
    next_state = state;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
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

        // If we are on an edge pixel, the sobel value will be zero
            if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                // Grabbing correct pixel values from the shift register
                pixel1 = shift_reg[0];
                pixel2 = shift_reg[1];
                pixel3 = shift_reg[2];
                pixel4 = shift_reg[3];
                pixel5 = shift_reg[4];
                pixel6 = shift_reg[WIDTH];
                pixel7 = shift_reg[WIDTH+1];
                pixel8 = shift_reg[WIDTH+2];
                pixel9 = shift_reg[WIDTH+3];
                pixel10 = shift_reg[WIDTH+4];
                pixel11 = shift_reg[WIDTH*2];
                pixel12 = shift_reg[WIDTH*2+1];
                pixel13 = shift_reg[WIDTH*2+2];
                pixel14 = shift_reg[WIDTH*2+3];
                pixel15 = shift_reg[WIDTH*2+4];
                pixel16 = shift_reg[WIDTH*3];
                pixel17 = shift_reg[WIDTH*3+1];
                pixel18 = shift_reg[WIDTH*3+2];
                pixel19 = shift_reg[WIDTH*3+3];
                pixel20 = shift_reg[WIDTH*3+4];
                pixel21 = shift_reg[WIDTH*4];
                pixel22 = shift_reg[WIDTH*4+1];
                pixel23 = shift_reg[WIDTH*4+2];
                pixel24 = shift_reg[WIDTH*4+3];
                pixel25 = shift_reg[WIDTH*4+4];
                // Calculate MAC for the numerator
                for (int i = 0; i < 4; i++) begin
                    for (int j = 0; j < 4; j++) begin
                    end
                end
                // Using the absolute value
                cx_c = ($signed(cx_c) < 0) ? -cx_c : cx_c;
                cy_c = ($signed(cy_c) < 0) ? -cy_c : cy_c;
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

    endcase

end
 


endmodule