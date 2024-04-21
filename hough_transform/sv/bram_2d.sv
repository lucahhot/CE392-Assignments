// BRAM module for 2D array of data with X and Y addresses
// BRAM then takes in the X and Y addresses and converts it to a 1D address
// since synplify_premier doesn't support 2D arrays as BRAM

module bram_2d #(
    parameter DATA_WIDTH = 32, 
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input   logic                           clock,
    input   logic                           wr_en,
    input   logic   [$clog2(WIDTH)-1:0]     addr_x,
    input   logic   [$clog2(HEIGHT)-1:0]    addr_y,
    input   logic   [DATA_WIDTH-1:0]        wr_data,
    output  logic   [DATA_WIDTH-1:0]        rd_data
);

// BRAM depth will be the product of the width and height
localparam DEPTH = WIDTH*HEIGHT;

logic [DATA_WIDTH-1:0] mem [DEPTH-1:0];

// 1D address
logic [$clog2(DEPTH)-1:0] addr;

// Clocked read address
logic [$clog2(DEPTH)-1:0] addr_clocked;

always_ff @(posedge clock) begin
    // Clock the address to prevent read/write conflicts
    addr_clocked <= addr;

    // Write to the BRAM
    if (wr_en == 1'b1) begin
        mem[$unsigned(addr)] <= wr_data;
    end 
end

// Combinational logic to read from the BRAM
always_comb begin 
    // Address is clocked to prevent read/write conflicts
    rd_data = mem[$unsigned(addr_clocked)];

    // Convert 2D address to 1D address
    addr = addr_y*WIDTH + addr_x;
end

endmodule