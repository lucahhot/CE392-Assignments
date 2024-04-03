module sobel #(
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

typedef enum logic [1:0] {S0, S1, S2} state_types;
state_types state, next_state;
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

// Sobel value
logic [15:0] sobel;

// Horizontal and vertical gradient values
logic [15:0] cx, cx_c, cy, cy_c;

// Wires to hold temporary pixel values
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel5, pixel6, pixel7, pixel8, pixel9;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
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
    
    case(state) 
        // Prologue
        S0: begin
            // Waiting for shift register to fill up enough to start sobel filter
            if (counter < WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = S1;
        end
        // Sobel filtering
        S1: begin
            // If we are on an edge pixel, the sobel value will be zero
            if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                // Grabbing correct pixel values from the shift register
                pixel1 = shift_reg[0];
                pixel2 = shift_reg[1];
                pixel3 = shift_reg[2];
                pixel4 = shift_reg[WIDTH];
                pixel5 = shift_reg[WIDTH+1];
                pixel6 = shift_reg[WIDTH+2];
                pixel7 = shift_reg[WIDTH*2];
                pixel8 = shift_reg[WIDTH*2+1];
                pixel9 = shift_reg[WIDTH*2+2];
                cx_c = $signed(pixel3 + 2*pixel6 + pixel9) - $signed(pixel1 + 2*pixel4 + pixel7);
                cy_c = $signed(pixel7 + 2*pixel8 + pixel9) - $signed(pixel1 + 2*pixel2 + pixel3);
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
        // Writing to FIFO
        S2: begin
            if (out_full == 1'b0) begin
                sobel = $unsigned((cx + cy)) >> 1;
                // Accounting for saturation
                sobel = ($signed(sobel) > 8'hff) ? 8'hff : sobel;
                out_din = 8'(sobel);
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
            cx_c = 'X;
            cy_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
        end
    endcase
end

endmodule