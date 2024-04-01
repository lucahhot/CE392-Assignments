module non_maximum_suppressor #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
)

parameter SHIFT_REG_LEN = 2*WIDTH+3;
parameter PIXEL_COUNT = WIDTH*HEIGHT;

// Shift register
logic [7:0] shift_reg [SHIFT_REG_LEN-1:0];
logic [7:0] shift_reg_c [SHIFT_REG_LEN-1:0];

// output values
logic [7:0] out, out_c;

// Counters for prologue
logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;



always_comb begin

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // sobel function can go through every single pixel
    // Only shift a new value in if state is not in S2 (writing sobel value to FIFO)
    if (state != S2) begin
        if (in_empty == 1'b0) begin
            // Implementing a shift right register
            shift_reg_c[SHIFT_REG_LEN-2:0] = shift_reg[SHIFT_REG_LEN-1:1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding
        end else if ((row*HEIGHT) + col > (PIXEL_COUNT-1) - (WIDTH+2)) begin
            shift_reg_c[SHIFT_REG_LEN-2:0] = shift_reg[SHIFT_REG_LEN-1:1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
    end

    case (state)
        S0: begin
            // Waiting for shift register to fill up enough to start sobel filter
            if (counter < WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = S1;
        end

        // non_maximum suppressor
        S1: begin
            // If we are on an edge pixel, the sobel value will be zero
            if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                // Grabbing correct pixel values from the shift register
                pixel1 = shift_reg[0]; // top left
                pixel2 = shift_reg[1];
                pixel3 = shift_reg[2];
                pixel4 = shift_reg[WIDTH];
                pixel5 = shift_reg[WIDTH+1]; // pixel being operated on
                pixel6 = shift_reg[WIDTH+2];
                pixel7 = shift_reg[WIDTH*2];
                pixel8 = shift_reg[WIDTH*2+1];
                pixel9 = shift_reg[WIDTH*2+2]; // bottom right

                north_south = pixel2 + pixel8;
                east_west = pixel4 + pixel6;
                north_west = pixel1 + pixel9;
                north_east = pixel3 + pixel7;

                out_c = '0;

                // if statements for non_maximum_suppressor
                // consider if having multiple states instead of nested loops will impact performance
                if (north_south >= east_west && north_south >= north_west && north_south >= north_east) begin
                    if (pixel5 > pixel4 && pixel5 >= pixel6) begin
                        out_c = pixel5;
                    end
                end else if (east_west >= north_west && east_west >= north_east) begin
                    if (pixel5 > pixel2 && pixel5 >= pixel8) begin
                        out_c = pixel5;
                    end
                end else if (north_west >= north_east) begin
                    if (pixel5 > pixel3 && pixel5 >= pixel7) begin
                        out_c = pixel5;
                    end
                end else begin
                    if (pixel5 > pixel1 ** pixel5 >= pixel9) begin
                        out_c = pixel5;
                    end
                end


            end else begin
                out_c = '0;
            end
            // Increment col and row trackers
            if (col == WIDTH - 1) begin
                col_c = 0;
                row_c++;
            end else
                col_c++;

            next_state = S2;
        end

        S2: begin
            if (out_full == 1'b0) begin
                out_din = out;
                out_wr_en = 1'b1;
                next_state = S1;
            end
        end

        default: begin
            next_state = S0;
            in_rd_en = 1'b0;
            out_wr_en = 1'b0;
            out_din = 8'h00;
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            out_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
        end
    endcase

end

endmodule