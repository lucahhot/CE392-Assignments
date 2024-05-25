
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

typedef enum logic [2:0] {PROLOGUE, S0, S1, COUNT} state_types;
state_types state, next_state;

localparam COUNT_DELAY = WIDTH;

logic [7:0] gs, gs_c;

logic [$clog2(COUNT_DELAY)-1:0] counter, counter_c;

// Shift register
logic [0:COUNT_DELAY-1][7:0] shift_reg ;
logic [0:COUNT_DELAY-1][7:0] shift_reg_c;


always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        gs <= 8'h0;
        counter <= '0;
        shift_reg <= '{default: '{default: '0}};
    end else begin
        state <= next_state;
        gs <= gs_c;
        counter <= counter_c;
        shift_reg <= shift_reg_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_din   = 8'b0;
    next_state   = state;
    gs_c = gs;
    counter_c = counter;
    shift_reg_c = shift_reg;

    case (state)

        // Shift in 1 row before starting to process 
        PROLOGUE: begin
            if (in_empty == 1'b0) begin
                shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
                shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
                in_rd_en = 1'b1;
                if (counter == COUNT_DELAY-1)
                    next_state = S0;
                else
                    counter_c = counter + 1;
            end
        end

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
            if (counter == COUNT_DELAY)
                next_state = S1;
            else 
                counter_c = counter + 1;
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