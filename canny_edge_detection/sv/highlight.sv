module hightlight#(
    WIDTH = 720,
    HEIGHT = 540,
    ANGLE_RANGE = 180,
    DATA_WIDTH = 16,
    FRAC_BITS = 13,
    LINE_LENGTH = 1000,
    RADIUS_WIDTH = 16
) (
    input  logic        clock,
    input  logic        reset,
    input logic        rd_en,
    input  logic        in_empty,
    input  logic [23:0]  in_dout,
    input logic [$clog2(ANGLE_RANGE)-1:0] angle,
    input logic [RADIUS_WIDTH-1 : 0] radius,
    output logic        out_wr_en,
    // input  logic        out_full,
    output logic [23:0]  out_din
);

typedef enum logic [1:0] {READING_IMAGE, FULL, FINISHED_DRAWING} image_state_types;
image_state_types image_state, next_image_state;

logic [WIDTH*HEIGHT-1:0][23:0] whole_image;

logic [$clog2(LINE_LENGTH):0] line_index;

logic [$clog2(HEIGHT*WIDTH)-1:0] image_index, image_index_c;

//this wire is for outputing
logic [$clog2(HEIGHT*WIDTH)-1:0] image_output_index, image_output_index_c;

logic signed [DATA_WIDTH-1:0] sine_angle, cosine_angle;

logic signed [2*RADIUS_WIDTH-1 : 0] x0, y0;
logic signed [2*RADIUS_WIDTH-1 : 0] x_step, y_step;
logic signed [2*RADIUS_WIDTH-1 : 0] x1, y1;
//corresponding to y1*width + x1
logic [RADIUS_WIDTH-1:0] line_image_index;

lookup_table #(
    .ANGLE_RANGE(ANGLE_RANGE),
    .DATA_WIDTH(DATA_WIDTH),
    .FRAC_BITS(FRAC_BITS)
) lookup_table_inst(
    .angle(angle),
    .sine(sine_angle),
    .cosine(cosine_angle)
);

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        image_state <= READING_IMAGE;
        whole_image <= '{default: '{default: '0}};
        image_index <= '0;
        line_index <= '0;
        image_output_index <= '0;
    end else begin
    if(in_empty==1'b0)begin
        image_state <= next_image_state;
        image_index <= image_index_c;
    end
    image_output_index <= image_output_index_c;
//        image_state <= next_image_state;
//        image_index <= image_index_c;
    end
end

always_ff @(posedge rd_en) begin
    image_index_c = image_index;
    next_image_state = image_state;
    case(image_state)
        READING_IMAGE : begin
            if(in_empty == 1'b0) begin
                whole_image[image_index] <= in_dout;
                image_index_c++;
                if(image_index_c == WIDTH*HEIGHT) begin
                    next_image_state = FULL;
                end
            end
        end
        FULL : begin
        end
        default : begin
        end
    endcase 
end

always_comb begin
    x0 = cosine_angle * $signed(radius) >>> FRAC_BITS;
    y0 = sine_angle * $signed(radius) >>> FRAC_BITS;
end

always_ff @(posedge clock) begin
    if(image_state==FULL) begin
        if(line_index < LINE_LENGTH) begin
            line_index++;
        end else begin
            image_state = FINISHED_DRAWING;
        end
    end
end

always_comb begin
    if(image_state==FULL) begin
        x_step = $signed(line_index) * (-sine_angle) >>> FRAC_BITS;
        y_step = $signed(line_index) * cosine_angle >>> FRAC_BITS;
        x1 = x0 + x_step;
        y1 = y0 + y_step;
        if(x1 >=0 && y1>=0 && x1 < WIDTH && y1 < HEIGHT) begin
            line_image_index = y1 * WIDTH + x1;
            whole_image[line_image_index] = 24'b000000001111111100000000;
        end
    end
end

always_comb begin
    image_output_index_c = image_output_index;
    out_wr_en = 1'b0;
    out_din = whole_image[image_output_index];
    if(image_state==FINISHED_DRAWING) begin
        out_wr_en = 1'b1;
        image_output_index_c++;
    end
end

endmodule
