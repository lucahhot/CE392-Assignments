module avalon_control(
  /* verilator lint_off UNUSED */
  input logic clk,
  input logic reset,
  input logic [31:0] avs_s0_writedata,
  /* verilator lint_on UNUSED */
  input logic avs_s0_write,
  output logic do_read
);

// Write anything to trigger a write.
// Without a waitrequest from the agent (this module)
// the `write` signal is asserted for exactly one cycle.
assign do_read = avs_s0_write;

endmodule