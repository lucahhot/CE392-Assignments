// Comment this line out for synthesis but uncomment for simulations
// `include "globals.sv"

module sobel (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0] in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

typedef enum logic [1:0] {PROLOGUE, FILTER, OUTPUT} state_types;
state_types state, next_state;
parameter SHIFT_REG_LEN = 2*REDUCED_WIDTH+3;
parameter PIXEL_COUNT = REDUCED_WIDTH*REDUCED_HEIGHT;

// Shift register
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg ;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// Counters for prologue
logic [$clog2(REDUCED_WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(REDUCED_WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(REDUCED_HEIGHT)-1:0] row, row_c;

// Sobel value
logic [15:0] sobel;

// Horizontal and vertical gradient values
logic [15:0] cx, cx_c, cy, cy_c, cx_temp, cy_temp;

// Wires to hold temporary pixel values
logic [7:0] pixel1,pixel2,pixel3,pixel4,pixel5,pixel6,pixel7,pixel8,pixel9;

// X and Y wires to know where we are in reference to the actual image
logic [$clog2(WIDTH)-1:0] x;
logic [$clog2(HEIGHT)-1:0] y;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        cx <= '0;
        cy <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        counter <= counter_c;
        col <= col_c;
        row <= row_c;
        cx <= cx_c;
        cy <= cy_c;
    end
end

always_comb begin
    next_state = state;
    in_rd_en = 1'b0;
    out_wr_en = 1'b0;
    out_din = 8'h00;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    cx_c = cx;
    cy_c = cy;

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // sobel function can go through every single pixel
    // Only shift a new value in if state is not in OUTPUT (writing sobel value to FIFO)
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
            // Waiting for shift register to fill up enough to start sobel filter
            if (counter < REDUCED_WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = FILTER;
        end
        // Sobel filtering
        FILTER: begin
            x = col + STARTING_X;
            y = row + STARTING_Y;
            // Only calculate sobel value if we there is input from the input FIFO (to prevent calculations even if there is no input being shifted in ie. 
            // if the previous stage is still running (gaussian blur), then don't do any sobel calculations)
            if (in_empty == 1'b0 || ((row*REDUCED_WIDTH) + col > (PIXEL_COUNT-1) - (REDUCED_WIDTH+2) - 1)) begin
                // If we are on an edge pixel, the sobel value will be zero
                if (y != 0 && y != (HEIGHT - 1) && x != 0 && x != (WIDTH - 1)) begin
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
                    cx_c = $signed(pixel3 + 2*pixel6 + pixel9) - $signed(pixel1 + 2*pixel4 + pixel7);
                    cy_c = $signed(pixel7 + 2*pixel8 + pixel9) - $signed(pixel1 + 2*pixel2 + pixel3);
                    // Using the absolute value
                    // cx_c = ($signed(cx_c) < 0) ? -cx_c : cx_c;
                    // cy_c = ($signed(cy_c) < 0) ? -cy_c : cy_c;
                end else begin
                    cx_c = '0;
                    cy_c = '0;
                end
                // Increment col and row trackers
                if (col == REDUCED_WIDTH-1) begin
                    col_c = 0;
                    row_c++;
                end else
                    col_c++;

                next_state = OUTPUT;
            end

        end
        // Writing to FIFO
        OUTPUT: begin
            if (out_full == 1'b0) begin
                cx_temp = ($signed(cx) < 0) ? -cx : cx;
                cy_temp = ($signed(cy) < 0) ? -cy : cy;
                sobel = $unsigned((cx_temp + cy_temp)) >> 1;
                // Accounting for saturation
                sobel = ($signed(sobel) > 8'hff) ? 8'hff : sobel;
                out_din = 8'(sobel);
                out_wr_en = 1'b1;
                next_state = FILTER;
                // If we have reached the last pixel of the entire image, go back to PROLOGUE and reset everything
                if (row == REDUCED_HEIGHT-1 && col == REDUCED_WIDTH-1) begin
                    next_state = PROLOGUE;
                    row_c = 0;
                    col_c = 0;
                    counter_c = 0;
                    cx_c = 0;
                    cy_c = 0;
                    // shift_reg_c = '{default: '{default: '0}};
                end
            end
        end
        default: begin
            next_state = PROLOGUE;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_din = '0;
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            cx_c = 'X;
            cy_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
        end
    endcase
end

endmodule