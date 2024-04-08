module cordic #(
    parameter CORDIC_DATA_WIDTH = 16
) (
    input   logic                           clk,
    input   logic                           reset,
    input   logic signed [2*CORDIC_DATA_WIDTH-1:0] radians_dout,
    output  logic                           radians_rd_en,
    input   logic                           radians_empty,
    output  logic signed [CORDIC_DATA_WIDTH-1:0]   sin_out_din,
    output  logic                           sin_wr_en,
    input   logic                           sin_full,
    output  logic signed [CORDIC_DATA_WIDTH-1:0]   cos_out_din,
    output  logic                           cos_wr_en,
    input   logic                           cos_full
);

localparam CORDIC_NTAB =  16;
localparam logic signed [15:0] CORDIC_TABLE [0:15] = // Reverse since opposite indexing of C++ for arrays 
{
    16'h3243, 16'h1DAC, 16'h0FAD, 16'h07F5, 16'h03FE, 16'h01FF, 16'h00FF, 16'h007F, 
    16'h003F, 16'h001F, 16'h000F, 16'h0007, 16'h0003, 16'h0001, 16'h0000, 16'h0000
};

// Generate the following quantized constants from SV testbench (they don't change based on 
// inputs so we can have them stored as constants to not blow up are design)
localparam logic signed [15:0] CORDIC_1K = 16'h26dd; // 9949
localparam logic signed [31:0] PI = 32'hc910; // 51472
localparam logic signed [31:0] HALF_PI = 32'h6488; // 25736
localparam logic signed [31:0] TWO_PI = 32'h19220; // 102944

// Need 17 element array to hold the output after 16 stages
logic signed [0:16][CORDIC_DATA_WIDTH-1:0] x_connector;
logic signed [0:16][CORDIC_DATA_WIDTH-1:0] y_connector;
logic signed [0:16][CORDIC_DATA_WIDTH-1:0] z_connector;
logic [0:16] valid_connector;

// Wires to calculate z_in for cordic_stage with every new radians input
logic signed [CORDIC_DATA_WIDTH-1:0] x_c, y_c, z_c;
logic signed [2*CORDIC_DATA_WIDTH-1:0] r_c;
logic valid_c;

genvar i;
generate
    for (i = 0; i < CORDIC_NTAB; i++) begin
        cordic_stage #(
            .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH)
        ) cordic_state_inst (
            .clk(clk),
            .reset(reset),
            .k(4'(i)),
            .c(CORDIC_TABLE[i]),
            .x_in(x_connector[i]),
            .y_in(y_connector[i]),
            .z_in(z_connector[i]),
            .valid_in(valid_connector[i]),
            .x_out(x_connector[i+1]),
            .y_out(y_connector[i+1]),
            .z_out(z_connector[i+1]),
            .valid_out(valid_connector[i+1])
        );
    end
endgenerate 

always_ff @(posedge clk or posedge reset) begin
    if (reset == 1'b1) begin
        x_connector[0] <= '0;
        y_connector[0] <= '0;
        z_connector[0] <= '0;
        valid_connector[0] <= '0;
        sin_out_din <= '0;
        cos_out_din <= '0;
        sin_wr_en <= '0;
        cos_wr_en <= '0;
    end else begin
        x_connector[0] <= x_c;
        y_connector[0] <= y_c;
        z_connector[0] <= z_c;
        valid_connector[0] <= valid_c;
        sin_out_din <= y_connector[16];
        cos_out_din <= x_connector[16];
        sin_wr_en <= valid_connector[16];
        cos_wr_en <= valid_connector[16];
    end
end

always_comb begin
    x_c = CORDIC_1K; // 9949
    y_c = 0;
    z_c = 'X;
    r_c = 'X;
    valid_c = '0;

    if (radians_empty == 1'b1)
        radians_rd_en = 1'b0;
    else begin

        r_c = radians_dout;
        radians_rd_en = 1'b1;

        while (r_c > PI) // 51472
            r_c -= TWO_PI; // -102944

        while (r_c < -PI) // -51472
            r_c += TWO_PI; // +102944

        if (r_c > HALF_PI) begin
            r_c -= PI;
            x_c = -CORDIC_1K;
            y_c = 0;
        end else if (r_c < -HALF_PI) begin
            r_c += PI;
            x_c = -CORDIC_1K;
            y_c = 0;
        end

        z_c = r_c[15:0];
        valid_c = 1'b1;

    end

end



endmodule