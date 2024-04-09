module cordic_top #(
    CORDIC_DATA_WIDTH = 16
) (
    input   logic                           clock,
    input   logic                           reset,
    output  logic                           radians_full,
    input   logic                           radians_wr_en,
    input   logic [2*CORDIC_DATA_WIDTH-1:0] radians_din,

    output  logic                           sin_empty,
    input   logic                           sin_rd_en,
    output  logic [CORDIC_DATA_WIDTH-1:0]   sin_dout,
    output  logic                           cos_empty,
    input   logic                           cos_rd_en,
    output  logic [CORDIC_DATA_WIDTH-1:0]   cos_dout
);

// Logic wires from radians FIFO to cordic module
logic radians_rd_en;
logic radians_empty;
logic [2*CORDIC_DATA_WIDTH-1:0] radians_dout;

// Radians input FIFO
fifo #(
    .FIFO_DATA_WIDTH(2*CORDIC_DATA_WIDTH),
    .FIFO_BUFFER_SIZE(32)
) fifo_radians_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(radians_wr_en),
    .din(radians_din),
    .full(radians_full),
    .rd_clk(clock),
    .rd_en(radians_rd_en),
    .dout(radians_dout),
    .empty(radians_empty)
);

// Logic wires from cordic module to all output FIFOs
logic sin_wr_en;
logic [CORDIC_DATA_WIDTH-1:0] sin_din;
logic sin_full;

logic cos_wr_en;
logic [CORDIC_DATA_WIDTH-1:0] cos_din;
logic cos_full;

// Cordic module
cordic #(
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH)
) cordic_inst (
    .clk(clock),
    .reset(reset),
    .radians_dout(radians_dout),
    .radians_rd_en(radians_rd_en),
    .radians_empty(radians_empty),
    .sin_out_din(sin_din),
    .sin_wr_en(sin_wr_en),
    .sin_full(sin_full),
    .cos_out_din(cos_din),
    .cos_wr_en(cos_wr_en),
    .cos_full(cos_full)
);

// Output FIFOs
fifo #(
    .FIFO_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .FIFO_BUFFER_SIZE(32)
) fifo_sin_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(sin_wr_en),
    .din(sin_din),
    .full(sin_full),
    .rd_clk(clock),
    .rd_en(sin_rd_en),
    .dout(sin_dout),
    .empty(sin_empty)
);

fifo #(
    .FIFO_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .FIFO_BUFFER_SIZE(32)
) fifo_cos_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(cos_wr_en),
    .din(cos_din),
    .full(cos_full),
    .rd_clk(clock),
    .rd_en(cos_rd_en),
    .dout(cos_dout),
    .empty(cos_empty)
);

endmodule