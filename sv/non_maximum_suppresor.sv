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

// Counters for prologue
logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;



always_comb begin
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
                pixel5 = shift_reg[WIDTH+1];
                pixel6 = shift_reg[WIDTH+2];
                pixel7 = shift_reg[WIDTH*2];
                pixel8 = shift_reg[WIDTH*2+1];
                pixel9 = shift_reg[WIDTH*2+2]; // bottom right

                north_south = pixel2 + pixel8;
                east_west = pixel4 + pixel6;
                north_west = pixel1 + pixel9;
                north_east = pixel3 + pixel7;

                // if statements for non_maximum_suppressor


                // Using the absolute value
                cx_c = ($signed(cx_c) < 0) ? -cx_c : cx_c;
                cy_c = ($signed(cy_c) < 0) ? -cy_c : cy_c;
            end else begin
                cx_c = '0;
                cy_c = '0;
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