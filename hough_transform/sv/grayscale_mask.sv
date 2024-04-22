// Same as the grayscale for the image but to write the grayscaled mask to a 2D BRAM

`include "globals.sv"

module grayscale_mask (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [23:0] in_dout,
    // Output wires to write to BRAM
    output logic                            out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0]   out_wr_addr,
    output logic [7:0]                      out_wr_data
);

typedef enum logic [1:0] {IDLE, GS, OUTPUT} state_types;
state_types state, next_state;

logic [7:0] gs, gs_c;

// Variables to track the x and y indices to write to BRAM
logic [$clog2(WIDTH)-1:0] x, x_c;
logic [$clog2(HEIGHT)-1:0] y, y_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        gs <= 8'h0;
        x <= '0;
        y <= '0;
    end else begin
        state <= next_state;
        gs <= gs_c;
        x <= x_c;
        y <= y_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_wr_data = 8'b0;
    out_wr_addr = 0;
    next_state = state;
    gs_c = gs;
    x_c = x;
    y_c = y;

    case (state)
        IDLE: begin
            // Reset the x and y coordinates once we are in the IDLE state and we see there is a value inside the input FIFO
            if (in_empty == 1'b0) begin
                next_state = GS;
                x_c = 0; 
                y_c = 0;
            end
        end
        GS: begin
            if (in_empty == 1'b0) begin
                gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                in_rd_en = 1'b1;
                next_state = OUTPUT;
            end
        end

        OUTPUT: begin
            // Writing to BRAM instead of FIFO
            out_wr_addr = (y * WIDTH) + x;
            out_wr_data = gs;
            out_wr_en = 1'b1;
            next_state = GS;
            // Calculate the next address to write to (if we are at the end, go back to IDLE)
            if (x == WIDTH-1) begin
                if (y == HEIGHT-1) 
                    next_state = IDLE;    
                else begin
                    x_c = 0;
                    y_c = y + 1;
                end                
            end else begin
                x_c = x + 1;
            end
        end

        default: begin
            in_rd_en  = 1'b0;
            out_wr_en = 1'b0;
            out_wr_data = 8'b0;
            out_wr_addr = '0;
            next_state = IDLE;
            gs_c = 8'hX;
            x_c = 'X;
            y_c = 'X;
        end

    endcase
end

endmodule