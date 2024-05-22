

module simple_image_loader #(
    parameter WIDTH = 1280,
    parameter HEIGHT = 720,
    parameter IMAGE_SIZE = WIDTH *HEIGHT
) (
    input  logic            clock,
    input  logic            reset,
    input  logic            image_wr_en,
    input  logic [23:0]     in_dout,
    // OUTPUT to image BRAM
    output logic                            bram_out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0]   bram_out_wr_addr,
    output logic [23:0]                     bram_out_wr_data,
    output logic    load_finished
);

typedef enum logic [1:0] {IDLE, OUTPUT} state_types;
state_types state, next_state;


// Variables to track the x and y indices to write to BRAM
logic [$clog2(WIDTH)-1:0] x, x_c;
logic [$clog2(HEIGHT)-1:0] y, y_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        x <= '0;
        y <= '0;
    end else begin
        state <= next_state;
        x <= x_c;
        y <= y_c;
        // if (state==OUTPUT & next_state==IDLE) begin
        //     load_finished <= 1'b1;
        // end
    end
end

always_comb begin
    x_c = x;
    y_c = y;
    next_state = state;
    bram_out_wr_en = 1'b0;
    bram_out_wr_data = '0;
    bram_out_wr_addr = 0;
    load_finished = 1'b0;

    case(state)
        IDLE: begin
            if (image_wr_en == 1'b1) begin
                next_state = OUTPUT;
                x_c = 0; 
                y_c = 0;
            end
        end

        OUTPUT: begin
            if (image_wr_en == 1'b1) begin
                bram_out_wr_en = 1'b1;
                bram_out_wr_data = in_dout;
                bram_out_wr_addr = (y * WIDTH) + x;
                next_state = OUTPUT;
                // Calculate the next address to write to (if we are at the end, go back to IDLE)
                if (x == WIDTH-1) begin
                    if (y == HEIGHT-1) begin
                        next_state = IDLE;    
                        load_finished = 1'b1;
                    end else begin
                        x_c = 0;
                        y_c = y + 1;
                    end                
                end else begin
                    x_c = x + 1;
                end
            end
        end

        default: begin
            x_c = 'X;
            y_c = 'X;
            next_state = IDLE;
            bram_out_wr_en = 1'b0;
            bram_out_wr_data = '0;
            bram_out_wr_addr = 0;
            load_finished = 1'b0;
        end

    endcase
end
   
endmodule