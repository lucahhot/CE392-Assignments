// Comment this line out for synthesis but uncomment for simulations
`include "globals.sv"

module hysteresis (
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

parameter HIGH_THRESHOLD = 48;
parameter LOW_THRESHOLD = 12;  

typedef enum logic [1:0] {PROLOGUE, HYSTERESIS, OUTPUT} state_types;
state_types state, next_state;
parameter SHIFT_REG_LEN = 2*REDUCED_WIDTH+3;
parameter PIXEL_COUNT = REDUCED_WIDTH*REDUCED_HEIGHT;

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
logic [7:0] pixel1,pixel2,pixel3,pixel4,pixel5,pixel6,pixel7,pixel8,pixel9;

// X and Y registers to know where we are in reference to the actual image
logic [$clog2(WIDTH)-1:0] x, x_c;
logic [$clog2(HEIGHT)-1:0] y, y_c;

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
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        counter <= counter_c;
        col <= col_c;
        row <= row_c;
        hysteresis <= hysteresis_c;
        x <= x_c;
        y <= y_c;
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
            x_c = col + STARTING_X;
            y_c = row + STARTING_Y;
            // Only calculate hysteresis value if there is input from the input FIFO 
            if (in_empty == 1'b0 || ((row*REDUCED_WIDTH) + col > (PIXEL_COUNT-1) - (REDUCED_WIDTH+2) - 1)) begin
                
                // If we are on an edge pixel, the hysteresis value will be zero 
                // NOTE: we have to check the adjusted row and col (taking into account STARTING_X and STARTING_Y)
                if (y_c != 0 && y_c != (HEIGHT - 1) && x_c != 0 && x_c != (WIDTH - 1)) begin
                    // Grabbing correct pixel values from the shift register
                    pixel1 = shift_reg[0];
                    pixel2 = shift_reg[1];
                    pixel3 = shift_reg[2];
                    pixel4 = shift_reg[REDUCED_WIDTH];
                    pixel5 = shift_reg[REDUCED_WIDTH+1];
                    pixel6 = shift_reg[REDUCED_WIDTH+2];
                    pixel7 = shift_reg[REDUCED_WIDTH*2];
                    pixel8 = shift_reg[REDUCED_WIDTH*2+1];
                    pixel9 = shift_reg[REDUCED_WIDTH*2+2];

                    // If pixel is strong or it is somewhat strong and at least one 
			        // neighbouring pixel is strong, keep it. Otherwise zero it.
                    if (pixel5 > HIGH_THRESHOLD || (pixel5 > LOW_THRESHOLD && 
                        (pixel1 > HIGH_THRESHOLD || pixel2 > HIGH_THRESHOLD || pixel3 > HIGH_THRESHOLD || 
                        pixel4 > HIGH_THRESHOLD || pixel6 > HIGH_THRESHOLD || pixel7 > HIGH_THRESHOLD || 
                        pixel8 > HIGH_THRESHOLD || pixel9 > HIGH_THRESHOLD))) begin
                            hysteresis_c = pixel5;
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
            out_wr_addr = (row * REDUCED_WIDTH) + col;
            next_state = HYSTERESIS;
            // Calculate the next address to write to (if we are at the end, reset everything and go back to PROLOGUE)
            if (col == REDUCED_WIDTH-1) begin
                if (row == REDUCED_HEIGHT-1) begin
                    next_state = PROLOGUE; 
                    row_c = 0;
                    col_c = 0;
                    counter_c = 0;
                    hysteresis_c = 0;
                    hough_start = 1'b1;
                end else begin
                    col_c = 0;
                    row_c = row + 1;
                end                
            end else begin
                col_c = col + 1;
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
        end
    endcase
end

endmodule
