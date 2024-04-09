module accum_buff_calc #(
    parameter THETAS,
    parameter RHO_RESOLUTION,
    parameter RHOS
) (
    input   logic       clock,
    input   logic       reset,
    input   logic       data_in_x,  
    input   logic       data_in_y,  
    input   logic       theta,
    output  logic       out_row
);
// image_in[] != 0

// Cordic Wires
logic radians_full, radians_wr_en;
logic [DATA_SIZE - 1 : 0] radians_din, radians_din_c;
logic sin_empty, sin_rd_en;
logic cos_empty, cos_rd_en;

cordic_top #(
    .CORDIC_DATA_WIDTH()
) cordic_top_inst (
    .clock(clock),
    .reset(reset),
    .radians_full(radians_full),
    .radians_wr_en(radians_wr_en),
    .radians_din(radians_din),
    .sin_empty(sin_empty),
    .sin_rd_en(sin_rd_en),
    .sin_dout(sin_dout_c),
    .cos_empty(cos_empty),
    .cos_rd_en(cos_rd_en),
    .cos_dout(cos_dout_c)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        sin_dout = '0;
        cos_dout = '0;
    end else begin
        sin_dout <= sin_dout_c;
        cos_dout <= cos_dout_c;
    end
end

always_comb begin
    // RHORESOLUTION = 2 ==> arithmetic right shift 1
    case (state) 
        COMPUTE_RADIANS: begin
            // compute radians
            radians_din_c = theta * 180/PI;       // do something about this calculation.
            next_state = CORDIC;
        end

        CORDIC: begin
            if (radians_full == 1'b0) begin
                radians_wr_en = 1'b1
                if (sin_empty == 1'b1 && cos_empty == 1'b1) begin
                    // if no output loop back to compute more inputs
                    next_state = COMPUTE_RADIANS;
                    sin_rd_en = 1'b1; 
                    cos_rd_en = 1'b1;
                end else begin
                    next_state = OUT;
                end
            end else begin
                next_state = CORDIC;
            end
            
        end

        OUT: begin
            rho = (data_in_x >>> 1) * cos_dout + (data_in_y >>> 1) * sin_dout;
            out_row = rho + RHOS>>1;
            next_state = COMPUTE_RADIANS;
        end

        default: begin
            sin_rd_en = 1'b0;
            cos_rd_en = 1'b0;
            radians_wr_en = 1'b0;
            radians_din_c = '0;
            out_row = 'X;
            next_state = COMPUTE_RADIANS;
        end
    endcase
    
end



endmodule