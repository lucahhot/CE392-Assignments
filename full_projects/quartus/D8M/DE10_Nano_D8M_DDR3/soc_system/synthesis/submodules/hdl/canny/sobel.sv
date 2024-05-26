
// Modified sobel filter to try and work with the Intel VIP Suite IP cores.

module sobel #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720
) (
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

localparam SHIFT_REG_LEN = 2*WIDTH+3;
localparam PIXEL_COUNT = WIDTH*HEIGHT;
localparam STOP_SHIFTING_PIXEL_COUNT = (PIXEL_COUNT-1) - (WIDTH+2) - 1;

// Shift register
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg ;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// Counters for prologue
logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;

// Sobel value
logic [15:0] sobel, sobel_c;

// Horizontal and vertical gradient values
logic [15:0] cx, cx_c, cy, cy_c, cx_temp, cx_temp_c, cy_temp, cy_temp_c;

// Wires to hold temporary pixel values
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel6, pixel7, pixel8, pixel9;
logic [7:0] pixel1_c, pixel2_c, pixel3_c, pixel4_c, pixel6_c, pixel7_c, pixel8_c, pixel9_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        cx <= '0;
        cy <= '0;
        sobel <= '0;
        cx_temp <= '0;
        cy_temp <= '0;
        pixel1 <= '0;
        pixel2 <= '0;
        pixel3 <= '0;
        pixel4 <= '0;
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
        cx <= cx_c;
        cy <= cy_c;
        sobel <= sobel_c;
        cx_temp <= cx_temp_c;
        cy_temp <= cy_temp_c;
        pixel1 <= pixel1_c;
        pixel2 <= pixel2_c;
        pixel3 <= pixel3_c;
        pixel4 <= pixel4_c;
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
    out_din = 8'h00;
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    cx_c = cx;
    cy_c = cy;
    sobel_c = sobel;
    cx_temp_c = cx_temp;
    cy_temp_c = cy_temp;
    pixel1_c = pixel1;
    pixel2_c = pixel2;
    pixel3_c = pixel3;
    pixel4_c = pixel4;
    pixel6_c = pixel6;
    pixel7_c = pixel7;
    pixel8_c = pixel8;
    pixel9_c = pixel9;

    // Need to change the below shifting logic since we are going to potentially have continuous input from the FIFO so we cannot
    // rely on it being empty to know when to start shifting in zeros; let's try and use a counter.

    // Keep shifting in values into the shift register until we reach the end of the image where we shift in zeros so that the
    // sobel function can go through every single pixel
    // Only shift a new value in if state is not in OUTPUT (writing sobel value to FIFO)
    if (state != OUTPUT) begin
        // Added another condition so that we only shift in values from the input FIFO that belong to this frame or else we will
        // start filling up the FIFO with pixels from the next frame potentially.
        if ((in_empty == 1'b0) && ((row*WIDTH) + col <= STOP_SHIFTING_PIXEL_COUNT)) begin
            // Implementing a shift right register
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding (Had to add a -1 here or else it would stall;
        // maybe it's because of the new dimensions of the reduced image
        end else if ((row*WIDTH) + col > STOP_SHIFTING_PIXEL_COUNT) begin
            shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
            shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
        end
    end
    
    case(state) 
        // Prologue
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start sobel filter
            if (counter < WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else 
                next_state = FILTER;
        end
        // Sobel filtering
        FILTER: begin

            // Only calculate sobel value if we there is input from the input FIFO (to prevent calculations even if there is no input being shifted in ie. 
            // if the previous stage is still running (gaussian blur), then don't do any sobel calculations)
            if (((in_empty == 1'b0) && ((row*WIDTH) + col <= STOP_SHIFTING_PIXEL_COUNT)) || ((row*WIDTH) + col > STOP_SHIFTING_PIXEL_COUNT)) begin
                // If we are on an edge pixel, the sobel value will be zero
                if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                    // Grabbing correct pixel values from the shift register
                    pixel1_c = shift_reg[0];
                    pixel2_c = shift_reg[1];
                    pixel3_c = shift_reg[2];
                    pixel4_c = shift_reg[WIDTH];
                    // pixel5 = shift_reg[WIDTH+1];
                    pixel6_c = shift_reg[WIDTH+2];
                    pixel7_c = shift_reg[WIDTH*2];
                    pixel8_c = shift_reg[WIDTH*2+1];
                    pixel9_c = shift_reg[WIDTH*2+2];
                    cx_c = 16'($signed(pixel3_c + 2*pixel6_c + pixel9_c) - $signed(pixel1_c + 2*pixel4_c + pixel7_c));
                    cy_c = 16'($signed(pixel7_c + 2*pixel8_c + pixel9_c) - $signed(pixel1_c + 2*pixel2_c + pixel3_c));
                    // Using the absolute value
                    // cx_c = ($signed(cx_c) < 0) ? -cx_c : cx_c;
                    // cy_c = ($signed(cy_c) < 0) ? -cy_c : cy_c;
                end else begin
                    cx_c = '0;
                    cy_c = '0;
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
        // Writing to FIFO
        OUTPUT: begin
            if (out_full == 1'b0) begin
                cx_temp_c = ($signed(cx) < 0) ? -cx : cx;
                cy_temp_c = ($signed(cy) < 0) ? -cy : cy;
                sobel_c = $unsigned((cx_temp_c + cy_temp_c)) >> 1;
                // Accounting for saturation
                sobel_c = ($signed(sobel_c) > 8'hff) ? 8'hff : sobel_c;
                out_din = 8'(sobel_c);
                out_wr_en = 1'b1;
                next_state = FILTER;
                // If we have reached the last pixel of the entire image, go back to PROLOGUE and reset everything
                if (row == HEIGHT-1 && col == WIDTH-1) begin
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
            sobel_c = 'X;
            cx_temp_c = 'X;
            cy_temp_c = 'X;
            pixel1_c = 'X;
            pixel2_c = 'X;
            pixel3_c = 'X;
            pixel4_c = 'X;
            pixel6_c = 'X;
            pixel7_c = 'X;
            pixel8_c = 'X;
            pixel9_c = 'X;
        end
    endcase
end

endmodule