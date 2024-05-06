
module hysteresis #(
    parameter REDUCED_IMAGE_SIZE = 233910,
    parameter REDUCED_WIDTH = 1035,
    parameter REDUCED_HEIGHT = 226,
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter STARTING_X = 123,
    parameter STARTING_Y = 31
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    // Output wires to write to BRAM
    output logic                                    out_wr_en,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   out_wr_addr,
    output logic [7:0]                              out_wr_data,
    // Start signal to tell hough that it can start 
    output logic hough_start
);

localparam HIGH_THRESHOLD = 48;
localparam LOW_THRESHOLD = 12;  

localparam OUT_ADDR_WIDTH = $clog2(REDUCED_IMAGE_SIZE);

typedef enum logic [1:0] {PROLOGUE, HYSTERESIS, OUTPUT} state_types;
state_types state, next_state;

localparam SHIFT_REG_LEN = 2*REDUCED_WIDTH+3;
localparam PIXEL_COUNT = REDUCED_WIDTH*REDUCED_HEIGHT;

// Shift register
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// Counters for prologue
logic [$clog2(REDUCED_WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(REDUCED_WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(REDUCED_HEIGHT)-1:0] row, row_c;

// Hysteresis value
logic [7:0] hysteresis, hysteresis_c;

// Wires to hold temporary pixel values
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel5, pixel6, pixel7, pixel8, pixel9;
logic [7:0] pixel1_c, pixel2_c, pixel3_c, pixel4_c, pixel5_c, pixel6_c, pixel7_c, pixel8_c, pixel9_c;

localparam X_WIDTH = $clog2(WIDTH);
localparam Y_WIDTH = $clog2(HEIGHT);

// X and Y wires to know where we are in reference to the actual image
logic [X_WIDTH-1:0] x, x_c;
logic [Y_WIDTH-1:0] y, y_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        hysteresis <= '0;
        x <= '0;
        y <= '0;
        pixel1 <= '0;
        pixel2 <= '0;
        pixel3 <= '0;
        pixel4 <= '0;
        pixel5 <= '0;
        pixel6 <= '0;
        pixel7 <= '0;
        pixel8 <= '0;
        pixel9 <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        counter <= counter_c;
        col <= col_c;
        row <= row_c;
        hysteresis <= hysteresis_c;
        x <= x_c;
        y <= y_c;
        pixel1 <= pixel1_c;
        pixel2 <= pixel2_c;
        pixel3 <= pixel3_c;
        pixel4 <= pixel4_c;
        pixel5 <= pixel5_c;
        pixel6 <= pixel6_c;
        pixel7 <= pixel7_c;
        pixel8 <= pixel8_c;
        pixel9 <= pixel9_c;
    end
end

always_comb begin
    next_state = state;
    in_rd_en = 1'b0;
    out_wr_en = 1'b0;
    out_wr_data = 8'h00;
    out_wr_addr = 0;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    hysteresis_c = hysteresis;
    hough_start = 1'b0;
    x_c = x;
    y_c = y;
    pixel1_c = pixel1;
    pixel2_c = pixel2;
    pixel3_c = pixel3;
    pixel4_c = pixel4;
    pixel5_c = pixel5;
    pixel6_c = pixel6;
    pixel7_c = pixel7;
    pixel8_c = pixel8;
    pixel9_c = pixel9;

    if (state != OUTPUT) begin
        if (in_empty == 1'b0) begin
            // Implementing a shift right register
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding (Had to add a -1 here or else it would stall;
        // maybe it's because of the new dimensions of the reduced image
        end else if ((row*REDUCED_WIDTH) + col > (PIXEL_COUNT-1) - (REDUCED_WIDTH+2) - 1) begin
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
    end

case(state) 
        // Prologue
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start hysteresis
            if (counter < REDUCED_WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else begin
                next_state = HYSTERESIS;
            end
        end
        // HYSTERESIS
        HYSTERESIS: begin

            x_c = X_WIDTH'(col + STARTING_X);
            y_c = Y_WIDTH'(row + STARTING_Y);

            // Only calculate hysteresis value if there is input from the input FIFO 
            if (in_empty == 1'b0 || ((row*REDUCED_WIDTH) + col > (PIXEL_COUNT-1) - (REDUCED_WIDTH+2) - 1)) begin
                
                // If we are on an edge pixel, the hysteresis value will be zero 
                // NOTE: we have to check the adjusted row and col (taking into account STARTING_X and STARTING_Y)
                if (y_c != 0 && y_c != (HEIGHT - 1) && x_c != 0 && x_c != (WIDTH - 1)) begin
                    // Grabbing correct pixel values from the shift register
                    pixel1_c = shift_reg[0];
                    pixel2_c = shift_reg[1];
                    pixel3_c = shift_reg[2];
                    pixel4_c = shift_reg[REDUCED_WIDTH];
                    pixel5_c = shift_reg[REDUCED_WIDTH+1];
                    pixel6_c = shift_reg[REDUCED_WIDTH+2];
                    pixel7_c = shift_reg[REDUCED_WIDTH*2];
                    pixel8_c = shift_reg[REDUCED_WIDTH*2+1];
                    pixel9_c = shift_reg[REDUCED_WIDTH*2+2];

                    // If pixel is strong or it is somewhat strong and at least one 
			        // neighbouring pixel is strong, keep it. Otherwise zero it.
                    if (pixel5_c > HIGH_THRESHOLD || (pixel5_c > LOW_THRESHOLD && 
                        (pixel1_c > HIGH_THRESHOLD || pixel2_c > HIGH_THRESHOLD || pixel3_c > HIGH_THRESHOLD || 
                        pixel4_c > HIGH_THRESHOLD || pixel6_c > HIGH_THRESHOLD || pixel7_c > HIGH_THRESHOLD || 
                        pixel8_c > HIGH_THRESHOLD || pixel9_c > HIGH_THRESHOLD))) begin
                            hysteresis_c = pixel5_c;
                        end else begin
                            hysteresis_c = '0;
                        end

                end else begin
                    // Hysteresis output is 0 if we are on the image border
                    hysteresis_c = '0;
                end

                next_state = OUTPUT;
            end

        end
        // Writing to BRAM instead of FIFO
        OUTPUT: begin
            out_wr_data = hysteresis;
            out_wr_en = 1'b1;
            // Write to hysteresis BRAM in terms of the reduced image dimensions since we do not need the hysteresis values outside of the mask
            // later in the hough transform
            out_wr_addr = OUT_ADDR_WIDTH'((row * REDUCED_WIDTH) + col);
            next_state = HYSTERESIS;
            // Calculate the next address to write to (if we are at the end, reset everything and go back to PROLOGUE)
            if (col == REDUCED_WIDTH-1) begin
                if (row == REDUCED_HEIGHT-1) begin
                    next_state = PROLOGUE; 
                    row_c = '0;
                    col_c = '0;
                    counter_c = '0;
                    hysteresis_c = '0;
                    hough_start = 1'b1;
                end else begin
                    col_c = '0;
                    row_c = row + 1'b1;
                end                
            end else begin
                col_c = col + 1'b1;
            end
        end
        
        default: begin
            next_state = PROLOGUE;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_wr_data = '0;
            out_wr_addr = '0;
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
            hysteresis_c = 'X;
            hough_start = 1'b0;
            x_c = 'X;
            y_c = 'X;
            pixel1_c = 'X;
            pixel2_c = 'X;
            pixel3_c = 'X;
            pixel4_c = 'X;
            pixel5_c = 'X;
            pixel6_c = 'X;
            pixel7_c = 'X;
            pixel8_c = 'X;
            pixel9_c = 'X;
        end
    endcase
end

endmodule
