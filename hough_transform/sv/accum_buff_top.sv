module accum_buff_top #(
    parameter THETAS,
    parameter RHO_RESOLUTION,
    parameter RHOS,
    parameter IMG_BITS,
    parameter THETA_BITS,
    parameter CORDIC_DATA_WIDTH,
    parameter BITS  // for quantization
) (
    input   logic                   clock,
    input   logic                   reset,
    output  logic                   in_full,
    input   logic                   in_wr_en,
    input   logic [15:0]            theta_din,
    output  logic                   row_out_empty,
    input   logic                   row_out_rd_en,
    output  logic [IMG_BITS-1:0]    row_out
);

logic theta_rd_en;
logic [15:0] theta_out_din;
logic theta_out_empty;


fifo #(
    .FIFO_BUFFER_SIZE(16),
    .FIFO_DATA_WIDTH(16)
) fifo_theta_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(theta_din),
    .full(in_full),
    .rd_clk(clock),
    .rd_en(theta_rd_en),
    .dout(theta_out_din),
    .empty(theta_out_empty)
);

accum_buff_calc #(
    .THETAS(),
    .RHO_RESOLUTION(),
    .RHOS(),
    .IMG_BITS(),
    .THETA_BITS(),
    .CORDIC_DATA_WIDTH(),
    .BITS()
) accum_buff_inst (
    
);

endmodule