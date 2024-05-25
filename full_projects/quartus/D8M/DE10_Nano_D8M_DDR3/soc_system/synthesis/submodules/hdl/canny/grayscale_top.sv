module grayscale_top #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter FIFO_BUFFER_SIZE = 8
) (
    input logic         clock,
    input logic         reset,
    output logic        image_full,
    input logic         image_wr_en,
    input logic [23:0]  image_din,

    output logic        img_out_empty,
    input logic         img_out_rd_en,
    output logic [7:0]  img_out_dout
);

// Input wires to grayscale function

logic [23:0]    image_dout;
logic           image_empty;
logic           image_rd_en;

// Output wires from hysteresis function to output FIFO
logic           img_out_wr_en;
logic           img_out_full;
logic [7:0]     img_out_din;



fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(24)
) fifo_image_inst (
    .reset(reset),
    .wr_clk(clock),
    .wr_en(image_wr_en),
    .din(image_din),
    .full(image_full),
    .rd_clk(clock),
    .rd_en(image_rd_en),
    .dout(image_dout),
    .empty(image_empty)
);

grayscale grayscale_inst(
    .clock(clock),
    .reset(reset),
    .in_rd_en(image_rd_en),
    .in_empty(image_empty),
    .in_dout(image_dout),
    .out_wr_en(img_out_wr_en),
    .out_full(img_out_full),
    .out_din(img_out_din)
);

fifo #(
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .FIFO_DATA_WIDTH(8)
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