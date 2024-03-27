module mask (
    input  logic        clock,
    input  logic        reset,

    output logic        base_rd_en,
    input  logic        base_empty,
    input  logic [7:0]  base_dout, // Base input (grayscaled)

    output logic        img_in_rd_en,
    input  logic        img_in_empty,
    input  logic [7:0]  img_in_dout, // Image input

    output logic        mask_out_wr_en,
    input  logic        mask_out_full,
    output logic [7:0]  mask_out_din // Image output
    
);
localparam THRESHOLD = 50;
localparam WHITE = 8'h0000;
localparam BLACK = 8'hffff;

typedef enum logic [0:0] {S0, S1} state_types;
state_types state, next_state;

logic [7:0] mask, mask_c; // Mask values 
logic [7:0] diff; // Wire to hold difference between grayscale values

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        mask <= BLACK;
    end else begin
        state <= next_state;
        mask <= mask_c;
    end
end

always_comb begin

    base_rd_en = 1'b0;
    img_in_rd_en = 1'b0;
    mask_out_wr_en = 1'b0;
    mask_out_din = 24'h0;
    next_state = state;
    mask_c = mask;

    case (state)

        // Read from the FIFOs 
        S0: begin
            if (base_empty == 1'b0 && img_in_empty == 1'b0) begin
                base_rd_en = 1'b1;
                img_in_rd_en = 1'b1;
                // Subtract grayscaled bit values
                diff = ($unsigned(img_in_dout) > $unsigned(base_dout)) ? ($unsigned(img_in_dout) - $unsigned(base_dout)) : ($unsigned(base_dout) - $unsigned(img_in_dout));
                // Assign mask value
                mask_c = ($unsigned(diff) > THRESHOLD) ? WHITE : BLACK;
                next_state = S1;
            end
        end

        S1: begin
            if (mask_out_full == 1'b0) begin
                mask_out_wr_en = 1'b1;
                mask_out_din = mask;
                next_state = S0;
            end
        end

        default: begin
            next_state = S0;
            base_rd_en = 1'b0;
            img_in_rd_en = 1'b0;
            mask_out_wr_en = 1'b0;
            mask_out_din = 24'h0;
            mask_c = 8'hxx;
        end

    endcase

end

endmodule