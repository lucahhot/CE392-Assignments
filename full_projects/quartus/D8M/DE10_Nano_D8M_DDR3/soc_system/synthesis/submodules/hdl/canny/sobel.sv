
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
localparam PIXEL_COUNT = WIDTH*HEIGHT;
localparam STOP_SHIFTING_PIXEL_COUNT = PIXEL_COUNT - COUNT_DELAY;

logic [7:0] gs, gs_c;

logic [$clog2(PIXEL_COUNT)-1:0] counter, counter_c;

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

    if (state != S1) begin
        // Shift in new values if input FIFO is not empty and we are not at the end of the pixels
        if ((in_empty == 1'b0) && (counter <= STOP_SHIFTING_PIXEL_COUNT)) begin
            shift_reg_c[0:COUNT_DELAY-2] = shift_reg[1:COUNT_DELAY-1];
            shift_reg_c[COUNT_DELAY-1] = in_dout;
            in_rd_en = 1'b1;
        // If we have reached the end of the pixels from the FIFO, shift in zeros for padding the rest of the image
        end else if (counter > STOP_SHIFTING_PIXEL_COUNT) begin
            shift_reg_c[0:COUNT_DELAY-2] = shift_reg[1:COUNT_DELAY-1];
            shift_reg_c[COUNT_DELAY-1] = 8'h00;
        end
    end

    case (state)

        // Load in COUNT_DELAY values before doing any processing
        PROLOGUE: begin
            // Waiting for shift register to fill up enough to start sobel filter
            if (counter < COUNT_DELAY) begin
                if (in_empty == 1'b0)
                    counter_c = counter + 1'b1;
            end else 
                next_state = S0;
        end
        S0: begin
            // Only calculate sobel value if we there is input from the input FIFO (to prevent calculations even if there is no input being shifted in ie. 
            // if the previous stage is still running (gaussian blur), then don't do any sobel calculations)
            if (((in_empty == 1'b0) && (counter <= STOP_SHIFTING_PIXEL_COUNT)) || (counter > STOP_SHIFTING_PIXEL_COUNT)) begin
                // gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                gs_c = shift_reg[0];
                in_rd_en = 1'b1;
                next_state = S1;
                counter_c = counter + 1'b1;
            end
        end

        S1: begin
            if (out_full == 1'b0) begin
                out_din = gs;
                out_wr_en = 1'b1;
                // Reset everything
                next_state = PROLOGUE;
                counter_c = '0;
            end
        end

        default: begin
            in_rd_en  = 1'b0;
            out_wr_en = 1'b0;
            out_din = 8'b0;
            next_state = PROLOGUE;
            gs_c = 8'hX;
            counter_c = '0;
            shift_reg_c <= '{default: '{default: '0}};
        end

    endcase
end

endmodule