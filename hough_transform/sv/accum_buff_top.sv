module accum_buff_top #(
    parameter THETAS,
    parameter RHO_RESOLUTION,
    parameter RHOS,
    parameter IMG_BITS,
    parameter THETA_BITS,
    parameter CORDIC_DATA_WIDTH,
    parameter BITS,
    parameter FIFO_BUFFER_SIZE // for quantization
) (
    input   logic                   clock,
    input   logic                   reset,
    output  logic                   theta_in_full,
    output  logic                   x_in_full,
    output  logic                   y_in_full,
    input   logic                   in_wr_en,
    input   logic [15:0]            theta_din,
    input   logic [15:0]            data_in_x,
    input   logic [15:0]            data_in_y,
    output  logic                   row_out_empty,
    input   logic                   row_out_rd_en,
    output  logic [15:0]    row_out
);

logic theta_rd_en;
logic [15:0] theta_out_din;
logic theta_out_empty;

logic x_rd_en, y_rd_en;
logic [15:0] x_out_din, y_out_din;
logic x_out_empty, y_out_empty;



fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(16)
) fifo_theta_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(theta_din),
    .full(theta_in_full),
    .rd_clk(clock),
    .rd_en(theta_rd_en),
    .dout(theta_out_din),
    .empty(theta_out_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(16)
) fifo_x_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(data_in_x),
    .full(x_in_full),
    .rd_clk(clock),
    .rd_en(x_rd_en),
    .dout(x_out_din),
    .empty(x_out_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(16)
) fifo_y_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(data_in_y),
    .full(y_in_full),
    .rd_clk(clock),
    .rd_en(y_rd_en),
    .dout(y_out_din),
    .empty(y_out_empty)
);

logic [15:0] row_out_din;
logic row_out_full;
logic row_out_wr_en;


accum_buff_calc #(
    .THETAS(THETAS),
    .RHO_RESOLUTION(RHO_RESOLUTION),
    .RHOS(RHOS),
    .IMG_BITS(IMG_BITS),
    .THETA_BITS(THETA_BITS),
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .BITS(BITS)
) accum_buff_inst (
    .clock(clock),
    .reset(reset),
    .data_in_x(x_out_din),
    .data_in_y(y_out_din),
    .x_rd_en(x_rd_en),
    .y_rd_en(y_rd_en),
    .theta_rd_en(theta_rd_en),
    .theta(theta_out_din),
    .row_out(row_out_din),
    .row_out_full(row_out_full),
    .row_out_wr_en(row_out_wr_en)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(16)
) fifo_row_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(row_out_wr_en),
    .din(row_out_din),
    .full(row_out_full),
    .rd_clk(clock),
    .rd_en(row_out_rd_en),
    .dout(row_out),
    .empty(row_out_empty)
);

endmodule