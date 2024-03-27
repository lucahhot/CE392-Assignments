module motion_detect_top #(
    parameter WIDTH = 768,
    parameter HEIGHT = 576,
    parameter FIFO_BUFFER_SIZE = 8
) (
    input logic         clock,
    input logic         reset,
    output logic        base_full,
    input logic         base_wr_en,
    input logic [23:0]  base_din,

    output logic        img_in_full,
    input logic         img_in_wr_en,
    input logic [23:0]  img_in_din,

    output logic        original_full,
    input logic         original_wr_en,
    input logic [23:0]  original_din,

    output logic        img_out_empty,
    input logic         img_out_rd_en,
    output logic [23:0] img_out_dout
);

// Input wires to grayscale function

logic [23:0]    base_dout;
logic           base_empty;
logic           base_rd_en;

logic [23:0]    img_in_dout;
logic           img_in_empty;
logic           img_in_rd_en;

// Output wires from grayscale function into grayscale FIFOs

logic [7:0]     base_gray_din;
logic           base_gray_full;
logic           base_gray_wr_en;

logic [7:0]     img_in_gray_din;
logic           img_in_gray_full;
logic           img_in_gray_wr_en;

// Output wires from grayscale FIFOs into mask function
logic [7:0]     base_gray_dout;
logic           base_gray_empty;
logic           base_gray_rd_en;

logic [7:0]     img_in_gray_dout;
logic           img_in_gray_empty;
logic           img_in_gray_rd_en;

// Output wires from mask function into mask FIFO
logic [7:0]     mask_din;
logic           mask_full;
logic           mask_wr_en;

// Output wires from mask FIFO and from original FIFO into highlight function 
logic [7:0]     mask_dout;
logic           mask_empty;
logic           mask_rd_en;

logic [23:0]    original_dout;
logic           original_empty;
logic           original_rd_en;

// Output from highlight function into image output FIFO

logic [23:0]    img_out_din;
logic           img_out_full;
logic           img_out_wr_en;


fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
) fifo_base_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(base_wr_en),
    .din(base_din),
    .full(base_full),
    .rd_clk(clock),
    .rd_en(base_rd_en),
    .dout(base_dout),
    .empty(base_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
) fifo_img_in_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(img_in_wr_en),
    .din(img_in_din),
    .full(img_in_full),
    .rd_clk(clock),
    .rd_en(img_in_rd_en),
    .dout(img_in_dout),
    .empty(img_in_empty)
);

grayscale base_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(base_rd_en),
    .in_empty(base_empty),
    .in_dout(base_dout),
    .out_wr_en(base_gray_wr_en),
    .out_full(base_gray_full),
    .out_din(base_gray_din)
);

grayscale img_in_grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(img_in_rd_en),
    .in_empty(img_in_empty),
    .in_dout(img_in_dout),
    .out_wr_en(img_in_gray_wr_en),
    .out_full(img_in_gray_full),
    .out_din(img_in_gray_din)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
) fifo_base_gray_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(base_gray_wr_en),
    .din(base_gray_din),
    .full(base_gray_full),
    .rd_clk(clock),
    .rd_en(base_gray_rd_en),
    .dout(base_gray_dout),
    .empty(base_gray_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
) fifo_img_in_gray_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(img_in_gray_wr_en),
    .din(img_in_gray_din),
    .full(img_in_gray_full),
    .rd_clk(clock),
    .rd_en(img_in_gray_rd_en),
    .dout(img_in_gray_dout),
    .empty(img_in_gray_empty)
);

mask mask_inst (
    .clock(clock),
    .reset(reset),
    .base_rd_en(base_gray_rd_en),
    .base_empty(base_gray_empty),
    .base_dout(base_gray_dout), 
    .img_in_rd_en(img_in_gray_rd_en),
    .img_in_empty(img_in_gray_empty),
    .img_in_dout(img_in_gray_dout), 
    .mask_out_wr_en(mask_wr_en),
    .mask_out_full(mask_full),
    .mask_out_din(mask_din) 
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
) fifo_mask_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(mask_wr_en),
    .din(mask_din),
    .full(mask_full),
    .rd_clk(clock),
    .rd_en(mask_rd_en),
    .dout(mask_dout),
    .empty(mask_empty)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
) fifo_original_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(original_wr_en),
    .din(original_din),
    .full(original_full),
    .rd_clk(clock),
    .rd_en(original_rd_en),
    .dout(original_dout),
    .empty(original_empty)
);

highlight highlight_inst (
    .clock(clock),
    .reset(reset),
    .mask_rd_en(mask_rd_en),
    .mask_empty(mask_empty),
    .mask_dout(mask_dout), 
    .original_rd_en(original_rd_en),
    .original_empty(original_empty),
    .original_dout(original_dout), 
    .img_out_wr_en(img_out_wr_en),
    .img_out_full(img_out_full),
    .img_out_din(img_out_din) 
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
) fifo_img_out_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(img_out_wr_en),
    .din(img_out_din),
    .full(img_out_full),
    .rd_clk(clock),
    .rd_en(img_out_rd_en),
    .dout(img_out_dout),
    .empty(img_out_empty)
);

endmodule

