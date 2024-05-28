
module hysteresis #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter REDUCED_IMAGE_SIZE = WIDTH * HEIGHT
) (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [7:0]  in_dout,
    output logic                                    bram_out_wr_en,
    output  logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]  bram_out_wr_addr,
    output logic [7:0]                              bram_out_wr_data,
    output logic                                    hough_start,

    // Wires to read from BRAM
    input  logic [7:0]  hysteresis_bram_rd_data,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0] hysteresis_bram_rd_addr,

    // Highlight output FIFO signals
    output logic [7:0]  highlight_din,
    output logic        highlight_wr_en,
    input  logic        highlight_full,

    input  logic         hysteresis_read_done
);

localparam HIGH_THRESHOLD = 48;
localparam LOW_THRESHOLD = 12;  

typedef enum logic [2:0] {IDLE, PROLOGUE, HYSTERESIS, OUTPUT, SELECT_ADDR, READ} state_types;
state_types state, next_state;

localparam SHIFT_REG_LEN = 2*WIDTH+3;
localparam PIXEL_COUNT = WIDTH*HEIGHT;
localparam STOP_SHIFTING_PIXEL_COUNT = (PIXEL_COUNT-1) - (WIDTH+2) - 1;

// Shift register
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg;
logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// Counters for prologue
logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// Column counter to know when to jump
logic [$clog2(WIDTH)-1:0] col, col_c;

// Row counter to know when we need to enter epilogue and push more zeros
logic [$clog2(HEIGHT)-1:0] row, row_c;

// Hysteresis value
logic [7:0] hysteresis, hysteresis_c;

// Wires to hold temporary pixel values
logic [7:0] pixel1, pixel2, pixel3, pixel4, pixel5, pixel6, pixel7, pixel8, pixel9;
logic [7:0] pixel1_c, pixel2_c, pixel3_c, pixel4_c, pixel5_c, pixel6_c, pixel7_c, pixel8_c, pixel9_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= PROLOGUE;
        shift_reg <= '{default: '{default: '0}};
        counter <= '0;
        col <= '0;
        row <= '0;
        hysteresis <= '0;
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
    counter_c = counter;
    col_c = col;
    row_c = row;
    shift_reg_c = shift_reg;
    hysteresis_c = hysteresis;
    pixel1_c = pixel1;
    pixel2_c = pixel2;
    pixel3_c = pixel3;
    pixel4_c = pixel4;
    pixel5_c = pixel5;
    pixel6_c = pixel6;
    pixel7_c = pixel7;
    pixel8_c = pixel8;
    pixel9_c = pixel9;

    bram_out_wr_en = 1'b0;
    bram_out_wr_data = '0;
    bram_out_wr_addr = 0;

    hough_start = 1'b0;

    in_rd_en = 1'b0;

    highlight_din = '0;
    highlight_wr_en = 1'b0;
    hysteresis_bram_rd_addr = 0;

    // Modifying below to not only rely on in_empty == 1'b0 to shift in new values (doesn't work with continuous input)

    if (state == PROLOGUE && state == HYSTERESIS) begin
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

        // Idle 
        IDLE: begin
            // if (hysteresis_read_done == 1'b1)
                next_state = PROLOGUE;
        end

        // Prologue
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start hysteresis
            if (counter < WIDTH + 2) begin
                if (in_empty == 1'b0)
                    counter_c++;
            end else begin
                next_state = HYSTERESIS;
            end
        end
        // HYSTERESIS
        HYSTERESIS: begin

            // Modified to accomodate for new above shifting logic

            // Only calculate hysteresis value if there is input from the input FIFO 
            if (((in_empty == 1'b0) && ((row*WIDTH) + col <= STOP_SHIFTING_PIXEL_COUNT)) || ((row*WIDTH) + col > STOP_SHIFTING_PIXEL_COUNT)) begin
                
                // If we are on an edge pixel, the hysteresis value will be zero 
                // NOTE: we have to check the adjusted row and col (taking into account STARTING_X and STARTING_Y)
                if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
                    // Grabbing correct pixel values from the shift register
                    pixel1_c = shift_reg[0];
                    pixel2_c = shift_reg[1];
                    pixel3_c = shift_reg[2];
                    pixel4_c = shift_reg[WIDTH];
                    pixel5_c = shift_reg[WIDTH+1];
                    pixel6_c = shift_reg[WIDTH+2];
                    pixel7_c = shift_reg[WIDTH*2];
                    pixel8_c = shift_reg[WIDTH*2+1];
                    pixel9_c = shift_reg[WIDTH*2+2];

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

        OUTPUT: begin
            next_state = SELECT_ADDR;
            bram_out_wr_en = 1'b1;
            bram_out_wr_data = hysteresis;
            bram_out_wr_addr = row * WIDTH + col;

            // if (highlight_full == 1'b0) begin
            //     highlight_din = hysteresis;
            //     highlight_wr_en = 1'b1;
                // Calculate the next address to write to (if we are at the end, reset everything and go back to PROLOGUE)
                // if (col == WIDTH-1) begin
                //     if (row == HEIGHT-1) begin
                //         // Signal that we're done
                //         hough_start = 1'b1;
                //         next_state = IDLE; 
                //         row_c = '0;
                //         col_c = '0;
                //         counter_c = '0;
                //         hysteresis_c = '0;
                //     end else begin
                //         col_c = '0;
                //         row_c = row + 1'b1;
                //     end                
                // end else begin
                //     col_c = col + 1'b1;
                // end
            // end
        end

        SELECT_ADDR: begin
            hysteresis_bram_rd_addr = row * WIDTH + col;
            next_state = READ;
        end

        READ: begin
            if (highlight_full == 1'b0) begin
                next_state = HYSTERESIS;
                highlight_din = hysteresis;
                highlight_wr_en = 1'b1;
                // Calculate the next address to write to (if we are at the end, reset everything and go back to PROLOGUE)
                if (col == WIDTH-1) begin
                    if (row == HEIGHT-1) begin
                        // Signal that we're done
                        hough_start = 1'b1;
                        next_state = IDLE; 
                        row_c = '0;
                        col_c = '0;
                        counter_c = '0;
                        hysteresis_c = '0;
                    end else begin
                        col_c = '0;
                        row_c = row + 1'b1;
                    end                
                end else begin
                    col_c = col + 1'b1;
                end
            end
        end
        
        default: begin
            next_state = PROLOGUE;
            counter_c = 'X;
            col_c = 'X;
            row_c = 'X;
            shift_reg_c = '{default: '{default: '0}};
            hysteresis_c = 'X;
            pixel1_c = 'X;
            pixel2_c = 'X;
            pixel3_c = 'X;
            pixel4_c = 'X;
            pixel5_c = 'X;
            pixel6_c = 'X;
            pixel7_c = 'X;
            pixel8_c = 'X;
            pixel9_c = 'X;
            bram_out_wr_en = 1'b0;
            bram_out_wr_data = '0;
            bram_out_wr_addr = 0;
            hough_start = 1'b0;
            in_rd_en = 1'b0;
        end
    endcase
end

endmodule
