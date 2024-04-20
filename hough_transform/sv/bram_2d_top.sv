module bram_2d_top #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32, 
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input logic                         clock,
    input logic                         reset,
    output logic [DATA_WIDTH-1:0]       output_data
);

logic                         wr_en;
logic    [ADDR_WIDTH-1:0]    addr_x;
logic    [ADDR_WIDTH-1:0]    addr_y;
logic    [DATA_WIDTH-1:0]    wr_data;

// Instantiate the BRAM module
bram_2d #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT)
) bram_2d_inst (
    .clock(clock),
    .wr_en(wr_en),
    .addr_x(addr_x),
    .addr_y(addr_y),
    .wr_data(wr_data),
    .rd_data(rd_data)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        wr_en <= 1'b0;
        addr_x <= '0;
        addr_y <= '0;
        wr_data <= '0;
    end else begin
        // Write data to BRAM
        wr_en <= 1'b1;
        addr_x <= addr_x + 1;
        addr_y <= addr_y + 1;
        wr_data <= wr_data + 1;
    end
end

// Read data from BRAM
assign output_data = rd_data;



endmodule