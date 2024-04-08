module cordic_stage #(
    parameter CORDIC_DATA_WIDTH = 16
) (
    input   logic                           clk,
    input   logic                           reset,
    input   logic signed [3:0]                     k,
    input   logic signed [CORDIC_DATA_WIDTH-1:0]   c,
    input   logic signed [CORDIC_DATA_WIDTH-1:0]   x_in,
    input   logic signed [CORDIC_DATA_WIDTH-1:0]   y_in,
    input   logic signed [CORDIC_DATA_WIDTH-1:0]   z_in,
    input   logic                           valid_in,

    output  logic signed [CORDIC_DATA_WIDTH-1:0]   x_out,
    output  logic signed [CORDIC_DATA_WIDTH-1:0]   y_out,
    output  logic signed [CORDIC_DATA_WIDTH-1:0]   z_out,
    output  logic                           valid_out
);

logic valid_out_c;
logic signed [CORDIC_DATA_WIDTH-1:0] d;
logic signed [CORDIC_DATA_WIDTH-1:0] x_out_c, y_out_c, z_out_c;

always_ff @(posedge clk or posedge reset) begin
    if (reset == 1'b1) begin
        valid_out <= 1'b0;
    end else begin 
        x_out <= x_out_c;
        y_out <= y_out_c;
        z_out <= z_out_c;
        valid_out <= valid_out_c;
    end
end

always_comb begin

    if (valid_in == 1'b1) begin
        d = ($signed(z_in) >= 0) ? 0 : -1;
        x_out_c = x_in - (((y_in >>> k) ^ d) - d);
        y_out_c = y_in + (((x_in >>> k) ^ d) - d);
        z_out_c = z_in - ((c ^ d) - d);
        valid_out_c = 1'b1;
    end else begin
        valid_out_c = 1'b0;
    end
end


endmodule