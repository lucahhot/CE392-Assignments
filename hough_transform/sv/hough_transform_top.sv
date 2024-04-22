module hough_transform_top #(
    parameter WIDTH,
    parameter HEIGHT,
    parameter X_WIDTH,
    parameter Y_WIDTH,
    parameter X_START,
    parameter Y_START,
    parameter X_END,
    parameter Y_END,
    parameter THETAS,
    parameter RHO_RESOLUTION,
    parameter RHOS,
    parameter IMG_BITS,
    parameter THETA_BITS,
    parameter CORDIC_DATA_WIDTH,
    parameter BITS,
    parameter FIFO_BUFFER_SIZE,
    parameter ACCUM_BUFF_SIZE,
    parameter ACCUM_BITS
) (
    input   logic           clock,
    input   logic           reset,
    output  logic           in_full,
    input   logic           in_wr_en,
    input   logic [7:0]     data_in,
    output  logic           out_empty,
    input   logic           out_rd_en,
    output  logic [15:0]    data_out,
    output  logic           hough_done
);

// Wires
logic in_fifo_rd_en;
logic in_fifo_empty;
logic [7:0] out_din;


fifo #(
    .FIFO_DATA_WIDTH(8),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) input_fifo_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(in_wr_en),
    .din(data_in),
    .full(in_full),
    .rd_clk(clock),
    .rd_en(in_fifo_rd_en),
    .dout(out_din),
    .empty(in_fifo_empty)
);

// Wires
logic hough_wr_en;
logic hough_out_full;
logic [7:0] hough_out;

hough_transform #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .X_WIDTH(X_WIDTH),
    .Y_WIDTH(Y_WIDTH),
    .X_START(X_START),
    .Y_START(Y_START),
    .X_END(X_END),
    .Y_END(Y_END),
    .THETAS(THETAS),
    .RHO_RESOLUTION(RHO_RESOLUTION),
    .RHOS(RHOS),
    .IMG_BITS(IMG_BITS),
    .THETA_BITS(THETA_BITS),
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .BITS(BITS),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .ACCUM_BUFF_SIZE(ACCUM_BUFF_SIZE),
    .ACCUM_BITS(ACCUM_BITS)
) hough_transform_inst (
    .clock(clock),
    .reset(reset),
    .in_rd_en(in_fifo_rd_en),
    .in_empty(in_fifo_empty),
    .in_dout(out_din),
    .out_wr_en(hough_wr_en),
    .out_full(hough_out_full),
    .buffer_index(hough_out),
    .hough_done(hough_done)
);

fifo #(
    .FIFO_DATA_WIDTH(16),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) output_fifo_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(hough_wr_en),
    .din(hough_out),
    .full(hough_out_full),
    .rd_clk(clock),
    .rd_en(out_rd_en),
    .dout(data_out),
    .empty(out_empty)
);

endmodule