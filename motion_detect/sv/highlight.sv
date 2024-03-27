module highlight (
    input  logic        clock,
    input  logic        reset,

    output logic        mask_rd_en,
    input  logic        mask_empty,
    input  logic [7:0]  mask_dout, // Mask input

    output logic        original_rd_en,
    input  logic        original_empty,
    input  logic [23:0] original_dout, // Original image

    output logic        img_out_wr_en,
    input  logic        img_out_full,
    output logic [23:0] img_out_din // Image output
    
);

localparam WHITE = 8'h0000;
localparam BLACK = 8'hffff;

typedef enum logic [0:0] {S0, S1} state_types;
state_types state, next_state;

logic [23:0] highlight, highlight_c; 

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        highlight <= 24'h0;
    end else begin
        state <= next_state;
        highlight <= highlight_c;
    end
end

always_comb begin

    mask_rd_en = 1'b0;
    original_rd_en = 1'b0;
    img_out_wr_en = 1'b0;
    img_out_din = 24'h0;
    next_state = state;
    highlight_c = highlight;

    case (state)

        // Read from the FIFOs 
        S0: begin
            if (mask_empty == 1'b0 && original_empty == 1'b0) begin
                mask_rd_en = 1'b1;
                original_rd_en = 1'b1;
                // If mask is white, the pixel will be all red, if not, the original pixel map
                highlight_c = (mask_dout == WHITE) ? {8'h00,8'h00,8'hff} : original_dout;
                next_state = S1;
            end
        end

        S1: begin
            if (img_out_full == 1'b0) begin
                img_out_wr_en = 1'b1;
                img_out_din = highlight;
                next_state = S0;
            end
        end

        default: begin
            next_state = S0;
            mask_rd_en = 1'b0;
            original_rd_en = 1'b0;
            img_out_wr_en = 1'b0;
            img_out_din = 24'h0;
            highlight_c = 24'hx;
        end

    endcase

end

endmodule