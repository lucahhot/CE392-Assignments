
module non_maximum_suppressor #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

localparam SHIFT_REG_LEN = 2*WIDTH+3;
localparam PIXEL_COUNT = WIDTH*HEIGHT;

typedef enum logic [1:0] {PROLOGUE, SUPPRESSION, OUTPUT} state_types;
state_types state, next_state;

// Shift register
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// output values
logic [7:0] out, out_c;

// Counters for prologue
logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;

// Wires to hold temporary pixel values
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel5, pixel6, pixel7, pixel8, pixel9;
logic [7:0] pixel1_c, pixel2_c, pixel3_c, pixel4_c, pixel5_c, pixel6_c, pixel7_c, pixel8_c, pixel9_c;

// Wires to hold gradient values (9 bits wide to account for overflow)
logic [8:0] north_south, east_west, north_west, north_east;
logic [8:0] north_south_c, east_west_c, north_west_c, north_east_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: 0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        out <= '0;
        pixel1 <= '0;
        pixel2 <= '0;
        pixel3 <= '0;
        pixel4 <= '0;
        pixel5 <= '0;
        pixel6 <= '0;
        pixel7 <= '0;
        pixel8 <= '0;
        pixel9 <= '0;
        north_south <= '0;
        east_west <= '0;
        north_west <= '0;
        north_east <= '0;
    end else begin
        state <= next_state;
        shift_reg <= shift_reg_c;
        counter <= counter_c;
        col <= col_c;
        row <= row_c;
        out <= out_c;
        pixel1 <= pixel1_c;
        pixel2 <= pixel2_c;
        pixel3 <= pixel3_c;
        pixel4 <= pixel4_c;
        pixel5 <= pixel5_c;
        pixel6 <= pixel6_c;
        pixel7 <= pixel7_c;
        pixel8 <= pixel8_c;
        pixel9 <= pixel9_c;
        north_south <= north_south_c;
        east_west <= east_west_c;
        north_west <= north_west_c;
        north_east <= north_east_c;
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
    out_c = out;
    pixel1_c = pixel1;
    pixel2_c = pixel2;
    pixel3_c = pixel3;
    pixel4_c = pixel4;
    pixel5_c = pixel5;
    pixel6_c = pixel6;
    pixel7_c = pixel7;
    pixel8_c = pixel8;
    pixel9_c = pixel9;
    north_south_c = north_south;
    east_west_c = east_west;
    north_west_c = north_west;
    north_east_c = north_east;

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // sobel function can go through every single pixel
    // Only shift a new value in if state is not in OUTPUT (writing NMS value to FIFO)
    if (state != OUTPUT) begin
        if (in_empty == 1'b0) begin
            // Implementing a shift right register
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding (Had to add a -1 here or else it would stall;
        // maybe it's because of the new dimensions of the reduced image
        end else if ((row*WIDTH) + col > (PIXEL_COUNT-1) - (WIDTH+2) - 1) begin
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
        out_wr_en = 1'b0;
    end

    case (state)
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start NMS filter
            if (counter < WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = SUPPRESSION;
        end

        // non_maximum suppressor
        SUPPRESSION: begin

            if (in_empty == 1'b0 || ((row*WIDTH) + col > (PIXEL_COUNT-1) - (WIDTH+2) - 1)) begin
                // If we are on an edge pixel, the NMS value will be zero
                if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                    
                    // Grabbing pixel values from the shift register
                    pixel1_c = shift_reg[0];
                    pixel2_c = shift_reg[1];
                    pixel3_c = shift_reg[2];
                    pixel4_c = shift_reg[WIDTH];
                    pixel5_c = shift_reg[WIDTH+1];
                    pixel6_c = shift_reg[WIDTH+2];
                    pixel7_c = shift_reg[WIDTH*2];
                    pixel8_c = shift_reg[WIDTH*2+1];
                    pixel9_c = shift_reg[WIDTH*2+2];

                    // Calculate the gradient values
                    north_south_c = pixel2_c + pixel8_c;
                    east_west_c = pixel4_c + pixel6_c;
                    north_west_c = pixel1_c + pixel9_c;
                    north_east_c = pixel3_c + pixel7_c;

                    out_c = '0;

                    // if statements for non_maximum_suppressor
                    // consider if having multiple states instead of nested loops will impact performance
                    if (north_south_c >= east_west_c && north_south_c >= north_west_c && north_south_c >= north_east_c) begin
                        if (pixel5_c > pixel4_c && pixel5_c >= pixel6_c) begin
                            out_c = pixel5_c;
                        end
                    end else if (east_west_c >= north_west_c && east_west_c >= north_east_c) begin
                        if (pixel5_c > pixel2_c && pixel5_c >= pixel8_c) begin
                            out_c = pixel5_c;
                        end
                    end else if (north_west_c >= north_east_c) begin
                        if (pixel5_c > pixel3_c && pixel5_c >= pixel7_c) begin
                            out_c = pixel5_c;
                        end
                    end else begin
                        if (pixel5_c > pixel1_c && pixel5_c >= pixel9_c) begin
                            out_c = pixel5_c;
                        end
                    end

                end else begin
                    out_c = '0;
                end
                // Increment col and row trackers
                if (col == WIDTH-1) begin
                    col_c = 0;
                    row_c++;
                end else
                    col_c++;

                next_state = OUTPUT;
            end
        end

        OUTPUT: begin
            if (out_full == 1'b0) begin
                out_din = out;
                out_wr_en = 1'b1;
                next_state = SUPPRESSION;
                // If we have reached the last pixel of the entire image, go back to PROLOGUE and reset everything
                if (row == HEIGHT-1 && col == WIDTH-1) begin
                    next_state = PROLOGUE;
                    row_c = 0;
                    col_c = 0;
                    counter_c = 0;
                    out_c = 0;
                    // shift_reg_c = '{default: '{default: '0}};
                end
            end
        end

        default: begin
            next_state = PROLOGUE;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_din = 8'h00;
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            out_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
            pixel1_c = 'X;
            pixel2_c = 'X;
            pixel3_c = 'X;
            pixel4_c = 'X;
            pixel5_c = 'X;
            pixel6_c = 'X;
            pixel7_c = 'X;
            pixel8_c = 'X;
            pixel9_c = 'X;
            north_south_c = 'X;
            east_west_c = 'X;
            north_west_c = 'X;
            north_east_c = 'X;
        end
    endcase

end

endmodule