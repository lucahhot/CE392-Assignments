`include "globals.sv"

module bram #(
  parameter BRAM_DATA_WIDTH = 8,
  parameter IMAGE_SIZE = 388800
) ( 
  input  logic                            clock,
  input  logic [$clog2(IMAGE_SIZE)-1:0]   rd_addr,
  input  logic [$clog2(IMAGE_SIZE)-1:0]   wr_addr,
  input  logic                            wr_en,
  input  logic [BRAM_DATA_WIDTH-1:0]      wr_data, 
  output logic [BRAM_DATA_WIDTH-1:0]      rd_data
);

  logic [0:IMAGE_SIZE-1][BRAM_DATA_WIDTH-1:0] mem;
  logic [$clog2(IMAGE_SIZE)-1:0] read_addr;
  
  assign rd_data = mem[read_addr];
  
  always_ff @(posedge clock) begin
    read_addr <= rd_addr;
    if (wr_en) mem[wr_addr] <= wr_data; 
  end

endmodule