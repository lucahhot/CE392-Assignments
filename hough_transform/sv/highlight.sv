module highlight#(
    WIDTH = 1280,
    HEIGHT = 720,
    IMAGE_SIZE = 921600,
    ANGLE_RANGE = 180,
    DATA_WIDTH = 16,
    FRAC_BITS = 13,
    LINE_LENGTH = 10000,
    THETA_BITS = 9
) (
    input  logic        clock,
    input  logic        reset,
    input  logic        start_draw_a_line,
    input logic [THETA_BITS-1:0] left_angle,
    input logic [THETA_BITS-1:0] right_angle,
    input logic [15 : 0] left_radius,
    input logic [15 : 0] right_radius,
    output logic finish_draw_a_line,
    output logic        out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0] out_addr,
    output logic [23:0]  out_din,
    input load_finished
);

typedef enum logic [1:0] {DRAWING_LEFT_LINE, DRAWING_RIGHT_LINE, FINISHED_DRAWING} image_state_types;
image_state_types image_state, next_image_state;

logic signed [DATA_WIDTH-1:0] sine_angle, cosine_angle;

logic [THETA_BITS-1:0] angle;

// logic start_draw_a_line_cp;
logic [THETA_BITS-1:0] left_angle_cp;
logic [THETA_BITS-1:0] right_angle_cp;
logic [15 : 0] left_radius_cp;
logic [15 : 0] right_radius_cp;

assign angle = (image_state == DRAWING_LEFT_LINE) ? left_angle_cp :
               (image_state == DRAWING_RIGHT_LINE) ? right_angle_cp :
               '0;

logic [$clog2(IMAGE_SIZE)-1 : 0] radius;

assign radius = (image_state == DRAWING_LEFT_LINE) ? left_radius_cp :
               (image_state == DRAWING_RIGHT_LINE) ? right_radius_cp :
               '0;

lookup_table #(
    .ANGLE_RANGE(ANGLE_RANGE),
    .DATA_WIDTH(DATA_WIDTH),
    .FRAC_BITS(FRAC_BITS)
) lookup_table_inst(
    .angle(angle),
    .sine(sine_angle),
    .cosine(cosine_angle)
);

logic signed [$clog2(LINE_LENGTH)+1:0] line_index;

logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x0, y0;
logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x_step, y_step;
logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x1, y1;

logic [$clog2(IMAGE_SIZE)-1:0] line_image_index;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        image_state <= FINISHED_DRAWING;
        next_image_state <= FINISHED_DRAWING;
        line_index <= '0;
        finish_draw_a_line <= 1'b0;
        out_wr_en <= 1'b0;
        // out_addr <= '0;
        // out_din <= '0;
        line_image_index <= '0;
    end else begin
        image_state <= next_image_state;
    end
end

always_ff @(posedge start_draw_a_line) begin
    // start_draw_a_line_cp <= 1'b1;
    left_angle_cp <= left_angle;
    right_angle_cp <= right_angle;
    left_radius_cp <= left_radius;
    right_radius_cp <= right_radius;
end

always_comb begin
    x0 = $signed(cosine_angle) * $signed(radius) >>> FRAC_BITS;
    y0 = $signed(sine_angle) * $signed(radius) >>> FRAC_BITS;
end

always_ff @(posedge clock or posedge start_draw_a_line) begin
    if(image_state==FINISHED_DRAWING) begin
        if(start_draw_a_line == 1'b1) begin
            next_image_state = DRAWING_LEFT_LINE;
            line_index = -LINE_LENGTH;
            out_wr_en = 1'b1;
            finish_draw_a_line = 1'b0;
        end
    end else if(load_finished==1'b0)begin
    end else if(image_state==DRAWING_LEFT_LINE) begin
        if(line_index < LINE_LENGTH) begin
            line_index++;
            x_step = $signed(line_index) * (-sine_angle) >>> FRAC_BITS;
            y_step = $signed(line_index) * cosine_angle >>> FRAC_BITS;
            x1 = x0 + x_step;
            y1 = y0 + y_step;
            if(x1 >=0 && y1>=0 && x1 < WIDTH && y1 < HEIGHT) begin
                line_image_index = y1 * WIDTH + x1;
            end
        end else begin
            line_index = -LINE_LENGTH;
            next_image_state = DRAWING_RIGHT_LINE;
            // finish_draw_a_line = 1'b1;
            // out_wr_en = 1'b0;
        end
    end else if(image_state==DRAWING_RIGHT_LINE) begin
        if(line_index < LINE_LENGTH) begin
            line_index++;
            x_step = $signed(line_index) * (-sine_angle) >>> FRAC_BITS;
            y_step = $signed(line_index) * cosine_angle >>> FRAC_BITS;
            x1 = x0 + x_step;
            y1 = y0 + y_step;
            if(x1 >=0 && y1>=0 && x1 < WIDTH && y1 < HEIGHT) begin
                line_image_index = y1 * WIDTH + x1;
            end
        end else begin
            next_image_state = FINISHED_DRAWING;
            finish_draw_a_line = 1'b1;
            out_wr_en = 1'b0;
            // start_draw_a_line_cp = 1'b0;
        end
    end
end

assign out_addr = line_image_index;
assign out_din = 24'b000000001111111100000000;

endmodule
