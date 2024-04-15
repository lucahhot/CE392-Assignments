module hough_transform #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540,
    parameter X_WIDTH,
    parameter Y_WIDTH,
    parameter X_START,
    parameter Y_START,
    parameter THETAS,
    parameter RHO_RESOLUTION,
    parameter RHOS,
    parameter IMG_BITS,
    parameter CORDIC_DATA_WIDTH,
    parameter BITS,
    parameter FIFO_BUFFER_SIZE
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

logic [7:0] accum_buff  [ACCUM_BUFF_SIZE-1:0];
logic [7:0] accum       [ACCUM_BUFF_SIZE-1:0];

localparam ACCUM_BITS = $clog2(ACCUM_BUFF_SIZE);

logic [X_WIDTH-1:0] x, x_c;
logic [Y_WIDTH-1:0] y, y_c;
logic [CORDIC_DATA_WIDTH-1:0] theta, theta_c;
logic [3:0] count, count_c;

logic theta_in_full, x_in_full, y_in_full;
logic in_wr_en, row_out_empty, row_out_rd_en;
logic [CORDIC_DATA_WIDTH-1:0] theta_din, data_in_x, data_in_y, row_out;

logic [ACCUM_BITS-1:0] buffer_index;

accum_buff_top #(
    .THETAS(THETAS),
    .RHO_RESOLUTION(RHO_RESOLUTION),
    .RHOS(RHOS),
    .IMG_BITS(IMG_BITS),
    .THETA_BITS(THETA_BITS),
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .BITS(BITS),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) accum_buff_inst(
    .clock(clock),
    .reset(reset),
    .theta_in_full(theta_in_full),
    .x_in_full(x_in_full),
    .y_in_full(y_in_full),
    .in_wr_en(in_wr_en),
    .theta_din(theta_din),
    .data_in_x(data_in_x),
    .data_in_y(data_in_y),
    .row_out_empty(row_out_empty),
    .row_out_rd_en(row_out_rd_en),
    .row_out(row_out)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        accum <= '{default: '{default: '0}};
        x <= X_START;
        y <= Y_START;
        theta <= '0;
        count <= '0;
    end else begin
        accum <= accum_buff;
        x <= x_c;
        y <= y_c;
        theta <= theta_c;
        count <= count_c;
        accum <= accum_buff;
    end
end

always_comb begin
    accum_buff = accum;
    x_c = x;
    y_c = y;
    theta_c = theta;
    count_c = count;

    case (state) 
        INIT: begin
            x_c = X_START;
            y_c = Y_START;
            if (in_din != '0) begin
                next_state = LOOP;
            end else begin
                next_state = INIT;
            end
        end

        X_Y_LOOP: begin
            x_c = x + 16'b1;
            if (x == X_END - 1) begin
                y_c = y + 16'b1;
            end

            data_in_x = x;
            data_in_y = y;
            next_state = THETA_LOOP;
            theta_c = '0;
        end

        THETA_LOOP: begin
            theta_c = theta + 16'b1;

            if (theta == THETAS-1 && count == THETAS-1) begin
                next_state = X_Y_LOOP;
            end else begin
                next_state = ROW_OUT;
            end
        end

        OUTPUT: begin
            if (row_out_empty == 1'b0) begin
                row_out_rd_en = 1'b1;
                buffer_index = RHOS * (row_out) + count;
                count_c = count + 4'b1;
                accum_buff[buffer_index] = accum[buffer_index] + 1;
            end
            next_state = THETA_LOOP;
        end

        default: begin
            theta_c = '0;
            count_c = '0;
            accum_buff = '{default: '{default: '0}};
        end
    endcase
end

endmodule