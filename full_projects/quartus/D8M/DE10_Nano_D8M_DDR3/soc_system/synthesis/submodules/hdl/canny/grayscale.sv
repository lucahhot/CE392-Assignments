
module grayscale (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [23:0] in_dout,

    // DDR3 Ports
    output logic [31:0]     sdram_address,
    output logic            rd_en,
    output logic            wr_en,
    output logic [127:0]    write_data_input,
    input  logic [127:0]    read_data,
    input  logic            write_complete,
    input  logic            read_complete,

    output logic        out_wr_en,
    input  logic        out_full,
    output logic [7:0]  out_din
);

typedef enum logic [2:0] {S0, DDR3_WRITE, WRITE_WAIT, DDR3_READ, READ_WAIT, OUTPUT} state_types;
state_types state, next_state;

logic [7:0] gs, gs_c, hysteresis_ddr3, hysteresis_ddr3_c;

localparam BASE_ADDRESS = 32'h04000000;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= S0;
        gs <= 8'h0;
        hysteresis_ddr3 <= '0;
    end else begin
        state <= next_state;
        gs <= gs_c;
        hysteresis_ddr3 <= hysteresis_ddr3_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_din   = 8'b0;
    next_state   = state;
    gs_c = gs;
    hysteresis_ddr3_c = hysteresis_ddr3;

    // Default DDR3 signal assignments
    sdram_address = '0;
    rd_en = 1'b0;
    wr_en = 1'b0;
    write_data_input = '0;

    case (state)
        S0: begin
            if (in_empty == 1'b0) begin
                gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                in_rd_en = 1'b1;
                next_state = DDR3_WRITE;
            end
        end

        // Testing DDR3 memory access by writing and reading value into DDR3
        DDR3_WRITE: begin
            write_data_input = gs;
            sdram_address = BASE_ADDRESS;
            wr_en = 1'b1;
            next_state = WRITE_WAIT;
        end

        // Wait for write_complete to be asserted before moving on to DDR3_READ
        WRITE_WAIT: begin
            if (write_complete == 1'b1) begin
                next_state = DDR3_READ;
            end
        end

        // Read the value from DDR3
        DDR3_READ: begin
            sdram_address = BASE_ADDRESS;
            rd_en = 1'b1;
            next_state = READ_WAIT;
        end

        // Wait for read_complete to be asserted before moving on to OUTPUT
        READ_WAIT: begin
            if (read_complete == 1'b1) begin
                hysteresis_ddr3_c = read_data[7:0];
                next_state = OUTPUT;
            end
        end

        OUTPUT: begin
            if (out_full == 1'b0) begin
                // out_din = gs;
                out_din = hysteresis_ddr3;
                out_wr_en = 1'b1;
                next_state = S0;
            end
        end

        default: begin
            in_rd_en  = 1'b0;
            out_wr_en = 1'b0;
            out_din = 8'b0;
            next_state = S0;
            gs_c = 8'h0;
            hysteresis_ddr3_c = '0;
        end

    endcase
end

endmodule
