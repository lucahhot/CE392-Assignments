
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

typedef enum logic [1:0] {S0, S1, COUNT} state_types;
state_types state, next_state;

localparam COUNT_DELAY = 1000;

logic [7:0] gs, gs_c;

logic [$clog2(COUNT_DELAY)-1:0] counter, counter_c;


always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        gs <= 8'h0;
        counter <= '0;
    end else begin
        state <= next_state;
        gs <= gs_c;
        counter <= counter_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_din   = 8'b0;
    next_state   = state;
    gs_c = gs;
    counter_c = counter;

    case (state)
        S0: begin
            if (in_empty == 1'b0) begin
                // gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                gs_c = 8'(in_dout + 50);
                in_rd_en = 1'b1;
                next_state = COUNT;
            end
        end

        COUNT: begin
            // Loop through this stage for COUNT_DELAY cycles to simulate the same delay that the sobel filter would have
            if (counter == COUNT_DELAY-1)
                next_state = S1;
            else 
                counter_c = counter + 1;
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