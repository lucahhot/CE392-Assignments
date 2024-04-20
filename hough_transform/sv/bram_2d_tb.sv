
`timescale 1 ns / 1 ns

module bram_2d_tb;

localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;

localparam ADDR_WIDTH = 10;
localparam DATA_WIDTH = 32; 
localparam WIDTH = 720;
localparam HEIGHT = 540;

logic                        wr_en;
logic    [ADDR_WIDTH-1:0]    addr_x;
logic    [ADDR_WIDTH-1:0]    addr_y;
logic    [DATA_WIDTH-1:0]    wr_data;
logic    [DATA_WIDTH-1:0]    rd_data;

bram_2d #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) bram_2d_inst (
    .clock(clock),
    .reset(reset),
    .wr_en(wr_en),
    .addr_x(addr_x),
    .addr_y(addr_y),
    .wr_data(wr_data),
    .rd_data(rd_data)
);

always begin
    clock = 1'b1;
    #(CLOCK_PERIOD/2);
    clock = 1'b0;
    #(CLOCK_PERIOD/2);
end

initial begin
    @(posedge clock);
    reset = 1'b1;
    @(posedge clock);
    reset = 1'b0;
end

initial begin : tb_process
    @(negedge reset);
    @(posedge clock);

    // Write data to BRAM
    wr_en = 1'b1;
    addr_x = 0;
    addr_y = 0;
    wr_data = 32'h00000001;

    @(posedge clock);

    // Read from BRAM
    wr_en = 1'b0;
    addr_x = 0;
    addr_y = 0;

    @(posedge clock);

    $display("Data read from BRAM: %h", rd_data);
    if (rd_data == 32'h00000001)
        $display("Data read from BRAM matches data written to BRAM");
    else
        $display("Data read from BRAM does not match data written to BRAM");

    $finish;
end


endmodule