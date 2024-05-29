
// This module loads in hysteresis values into a BRAM

module hysteresis_loader #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter STARTING_X = 128,
    parameter STARTING_Y = 30,
    parameter ENDING_X = 1152,
    parameter ENDING_Y = 270,
    parameter REDUCED_IMAGE_SIZE = (ENDING_X - STARTING_X) * (ENDING_Y - STARTING_Y)
)(
    input  logic            clock,
    input  logic            reset,
    output logic            in_rd_en,
    input  logic            in_empty,
    input  logic [23:0]     in_dout,

    // OUTPUT to hysteresis BRAM
    output logic                                    bram_out_wr_en,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   bram_out_wr_addr,
    output logic [7:0]                              bram_out_wr_data,

    output logic            hough_start
);

typedef enum logic [1:0] {IDLE, OUTPUT} state_types;
state_types state, next_state;

// Variables to track the x and y indices to write to BRAM
logic [$clog2(WIDTH)-1:0] x, x_c;
logic [$clog2(HEIGHT)-1:0] y, y_c;

logic [$clog2(WIDTH)-1:0] x_reduced;
logic [$clog2(HEIGHT)-1:0] y_reduced;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        x <= '0;
        y <= '0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
    end
end

always_comb begin
    x_c = x;
    y_c = y;
    next_state = state;

    in_rd_en = 1'b0;
;
    bram_out_wr_en = 1'b0;
    bram_out_wr_data = '0;
    bram_out_wr_addr = 0;

    hough_start = 1'b0;

    case(state)
        IDLE: begin
            // Reset the x and y coordinates once we are in the IDLE state and we see there is a value inside the input FIFO
            if (in_empty == 1'b0) begin
                next_state = OUTPUT;
                x_c = 0; 
                y_c = 0;
            end
        end

        OUTPUT: begin

            if (in_empty == 1'b0) begin
                in_rd_en = 1'b1;
                // Write into BRAM only the pixels within the reduced image
                if (x >= STARTING_X && x <= ENDING_X && y >= STARTING_Y && y <= ENDING_Y) begin
                    // Reduced coordinates to calculate BRAM address
                    x_reduced = x - STARTING_X;
                    y_reduced = y - STARTING_Y;

                    bram_out_wr_en = 1'b1;
                    bram_out_wr_data = in_dout[7:0];
                    bram_out_wr_addr = (y_reduced * (ENDING_X - STARTING_X)) + x_reduced;
                end

                // Calculate the next address to write to (if we are at the end, go back to IDLE)
                if (x == WIDTH-1) begin
                    if (y == HEIGHT-1) begin
                        next_state = IDLE;  
                        hough_start = 1'b1;  
                    end else begin
                        x_c = 0;
                        y_c = y + 1'b1;
                    end                
                end else begin
                    x_c = x + 1'b1;
                end
            end
        end

        default: begin
            x_c = 'X;
            y_c = 'X;
            next_state = IDLE;
            bram_out_wr_en = 1'b0;
            bram_out_wr_data = '0;
            bram_out_wr_addr = 0;
            in_rd_en = 1'b0;
        end

    endcase
end
   
endmodule