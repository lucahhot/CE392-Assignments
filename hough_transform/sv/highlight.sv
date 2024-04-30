module hightlight#(
    WIDTH = 1280,
    HEIGHT = 720,
    IMAGE_SIZE = 388800,
    ANGLE_RANGE = 180,
    DATA_WIDTH = 16,
    FRAC_BITS = 13,
    LINE_LENGTH = 1000,
) (
    input  logic        clock,
    input  logic        reset,
    input  logic        start_draw_a_line;
    input logic [$clog2(ANGLE_RANGE)-1:0] angle,
    input logic [$clog2(IMAGE_SIZE)-1 : 0] radius,
    output logic finish_draw_a_line;
    output logic        out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0] out_addr;
    output logic [23:0]  out_din
);

typedef enum logic [1:0] {DRAWING_LINES, FINISHED_DRAWING} image_state_types;
image_state_types image_state, next_image_state;

logic signed [DATA_WIDTH-1:0] sine_angle, cosine_angle;

lookup_table #(
    .ANGLE_RANGE(ANGLE_RANGE),
    .DATA_WIDTH(DATA_WIDTH),
    .FRAC_BITS(FRAC_BITS)
) lookup_table_inst(
    .angle(angle),
    .sine(sine_angle),
    .cosine(cosine_angle)
);

logic [$clog2(LINE_LENGTH):0] line_index;

logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x0, y0;
logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x_step, y_step;
logic signed [2*$clog2(IMAGE_SIZE)-1 : 0] x1, y1;

logic [$clog2(IMAGE_SIZE)-1:0] line_image_index;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        image_state <= FINISHED_DRAWING;
        line_index <= '0;
        finish_draw_a_line <= 1'b1;
        out_wr_en <= 1'b0;
        out_addr <= '0;
        out_din <= '0;
        line_image_index <= '0;
    end else begin
        image_state <= next_image_state;
    end
end

always_comb begin
    x0 = cosine_angle * $signed(radius) >>> FRAC_BITS;
    y0 = sine_angle * $signed(radius) >>> FRAC_BITS;
end

always_ff @(posedge clock) begin
    if(image_state==FINISHED_DRAWING) begin
        if(start_draw_a_line == 1'b1) begin
            next_image_state = DRAWING_LINES;
            line_index = '0;
            out_wr_en = 1'b1;
            finish_draw_a_line = 1'b0;
        end
    end else if(image_state==DRAWING_LINES) begin
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
            image_state = FINISHED_DRAWING;
            finish_draw_a_line = 1'b1;
            out_wr_en = 1'b0;
        end
    end
end

assign out_addr = line_image_index;
assign out_din = 24'b000000001111111100000000;

endmodule
