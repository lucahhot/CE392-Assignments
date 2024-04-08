module hough_transform #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input   logic           clock,
    input   logic           reset,
    input   logic           in_rd_en,
    input   logic           in_empty,
    input   logic [7:0]     in_dout,
    output  logic           out_wr_en,
    input   logic           out_full,
    output  logic [7:0]     out_din
);


// May need to be changed to logic signed later to be synthesizable
localparam X_START = -WIDTH >>> 1;
localparam Y_START = -HEIGHT >>> 1;
localparam X_END = WIDTH >>> 1;
localparam Y_END = 0;

localparam RHO_RESOLUTION = 2;
// RHOS = Sqrt(WIDTH^2 + HEIGHT^2)/RHO_RESOLUTION
// Can do calculation beforehand since we will know image size
localparam RHOS = 900 >>> 1;
localparam THETAS = 180;

parameter ACCUM_BUFF_SIZE = RHOS * THETAS;

logic [7:0] accum_buff  [ACCUM_BUFF_SIZE-1:0];
logic [7:0] accum       [ACCUM_BUFF_SIZE-1:0];

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        accum <= '{default: '{default: 0}};
    end else begin
        accum <= accum_buff;
    end
end

always_comb begin
    accum_buff = accum;

    case (state) 
        INIT: begin
            if (in_din != 0) begin
                next_state = LOOP;
            end else begin
                next_state = INIT;
            end
        end

        LOOP: begin
            
        end
    endcase
end

endmodule