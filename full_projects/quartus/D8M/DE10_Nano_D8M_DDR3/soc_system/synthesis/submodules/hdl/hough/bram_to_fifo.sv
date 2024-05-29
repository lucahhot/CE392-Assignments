module bram_to_fifo #(
    parameter REDUCED_WIDTH = 512,
    parameter REDUCED_HEIGHT = 288
) (
    input  logic        clock,
    input  logic        reset,
    input  logic        start,
    // HYSTERESIS INPUTS from bram_2d
    input  logic [7:0]                                      hysteresis_bram_rd_data,
    output logic [$clog2(REDUCED_WIDTH*REDUCED_HEIGHT)-1:0] hysteresis_bram_rd_addr,
    output logic hysteresis_read_done,

    // Highlight output FIFO signals
    output logic [7:0]  highlight_din,
    output logic        highlight_wr_en,
    input  logic        highlight_full
);

typedef enum logic [1:0] {IDLE, SELECT_ADDR, OUTPUT} state_types;
state_types state, next_state;

logic [$clog2(REDUCED_WIDTH)-1:0] x, x_c;
logic [$clog2(REDUCED_HEIGHT)-1:0] y, y_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        x <= 0;
        y <= 0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
    end
end

always_comb begin

    next_state = state;
    x_c = x;
    y_c = y;

    hysteresis_bram_rd_addr = 0;
    hysteresis_read_done = 1'b0;
    highlight_din = '0;
    highlight_wr_en = 1'b0;


    case(state)

        IDLE: begin
            if (start == 1'b1)
                next_state = SELECT_ADDR;
        end

        SELECT_ADDR: begin
            hysteresis_bram_rd_addr = y * REDUCED_WIDTH + x;
            next_state = OUTPUT;
        end

        OUTPUT: begin
            
            if (highlight_full == 1'b0) begin
                highlight_din = hysteresis_bram_rd_data;
                // highlight_din = 8'hFF;
                highlight_wr_en = 1'b1;
                if (x == REDUCED_WIDTH-1) begin
                    if (y == REDUCED_HEIGHT-1) begin
                        hysteresis_read_done = 1'b1;
                        next_state = IDLE;
                        x_c = 0;
                        y_c = 0;
                    end else begin
                        x_c = 0;
                        y_c = y + 1;
                    end
                end else begin
                    x_c = x + 1;
                end
                next_state = SELECT_ADDR;
            end 
        end

    endcase
end


endmodule