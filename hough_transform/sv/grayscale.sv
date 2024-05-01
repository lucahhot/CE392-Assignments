// Comment this line out for synthesis but uncomment for simulations

module grayscale (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [23:0] in_dout,
    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

typedef enum logic [0:0] {S0, S1} state_types;
state_types state, next_state;

logic [7:0] gs, gs_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        gs <= 8'h0;
    end else begin
        state <= next_state;
        gs <= gs_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_din   = 8'b0;
    next_state   = state;
    gs_c = gs;

    case (state)
        S0: begin
            if (in_empty == 1'b0) begin
                gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                in_rd_en = 1'b1;
                next_state = S1;
            end
        end

        S1: begin
            if (out_full == 1'b0) begin
                out_din = gs;
                out_wr_en = 1'b1;
                next_state = S0;
            end
        end

        default: begin
            in_rd_en  = 1'b0;
            out_wr_en = 1'b0;
            out_din = 8'b0;
            next_state = S0;
            gs_c = 8'hX;
        end

    endcase
end

endmodule
