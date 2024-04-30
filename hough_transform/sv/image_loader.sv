// This module will take in the image input from the image FIFO and write it to a BRAM module so that it can be used
// later when highlighting the lanes and outputting the final image out of the entire top-level module.

// This module will also importantly feed the pixels within the rectangle that encompasses the mask into another 
// FIFO which the entire canny edge detection pipeline will read from. This will reduce the number of cycles needed
// as the canny algorithm has to go through a smaller number of pixels. We would still need to go through the pixels 
// from (0,0) to (STARTING_X,STARTING_Y) before we can start doing any processing.

// IMAGE_SIZE = 1280 x 720 = 921600 
// REDUCED_IMAGE_SIZE = 1035 x 226 = 233910 (1024 x 215 according to the mask_1280_720.bmp file) Note: we need 5 pixels of padding
// on each side because we always have to fill the pixels around the edges of the masked pixels at every stage of the pipeline

// Normal cycles count = 921600 * 2 = 1,843,200 (ONLY UP FOR THE CANNY EDGE DETECTION PIPELINE)
// Reduced cycles count = (31*1280 + 123) + 233910 * 2 = 507623 -72.5% reduction in cycles
// Note that this not take into account the canny edge pipeline stalling that happens ie. when the FIFOs fill up.
// This means that the actual number of cycles taken will be much greater but I believe that the improvement should remain
// since processing the full image will also result in the same pipeline stalling.  

// Comment this line out for synthesis but uncomment for simulations
`include "globals.sv"

module image_loader (
    input  logic            clock,
    input  logic            reset,
    output logic            in_rd_en,
    input  logic            in_empty,
    input  logic [23:0]     in_dout,
    // OUTPUT to grayscale FIFO
    output logic            fifo_out_wr_en,
    input  logic            fifo_out_full,
    output logic [23:0]     fifo_out_din,
    // OUTPUT to image BRAM
    output logic                            bram_out_wr_en,
    output logic [$clog2(IMAGE_SIZE)-1:0]   bram_out_wr_addr,
    output logic [23:0]                     bram_out_wr_data,
    output logic    load_finished;
);

typedef enum logic [1:0] {IDLE, OUTPUT} state_types;
state_types state, next_state;

logic [23:0] pixel;

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
    end
end

always_comb begin
    x_c = x;
    y_c = y;
    next_state = state;
    in_rd_en = 1'b0;
    fifo_out_wr_en = 1'b0;
    fifo_out_din = '0;
    bram_out_wr_en = 1'b0;
    bram_out_wr_data = '0;
    bram_out_wr_addr = 0;
    load_finished = 1'b0;

    case(state)
        IDLE: begin
            // Reset the x and y coordinates once we are in the IDLE state and we see there is a value inside the input FIFO
            if (in_empty == 1'b0) begin
                next_state = OUTPUT;
                x_c = 0; 
                y_c = 0;
            end
        end

        OUTPUT: begin
            // Only write to both FIFO and BRAM if output FIFO is not empty
            if (fifo_out_full == 1'b0 && in_empty == 1'b0) begin
                in_rd_en = 1'b1;
                pixel = in_dout;
                // Writing to FIFO (that feed into the canny pipeline) only if pixel is inside the reduced image dimensions
                if (x >= STARTING_X && x <= ENDING_X && y >= STARTING_Y && y <= ENDING_Y) begin
                    fifo_out_wr_en = 1'b1;
                    fifo_out_din = pixel;
                end
                // Writing to BRAM all pixels
                bram_out_wr_en = 1'b1;
                bram_out_wr_data = pixel;
                bram_out_wr_addr = (y * WIDTH) + x;
                next_state = OUTPUT;
                // Calculate the next address to write to (if we are at the end, go back to IDLE)
                if (x == WIDTH-1) begin
                    if (y == HEIGHT-1) 
                        next_state = IDLE;    
                        load_finished = 1'b1;
                    else begin
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
            in_rd_en = 1'b0;
            fifo_out_wr_en = 1'b0;
            fifo_out_din = '0;
            bram_out_wr_en = 1'b0;
            bram_out_wr_data = '0;
            bram_out_wr_addr = 0;
        end

    endcase
end
   
endmodule