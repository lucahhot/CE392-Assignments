// Same as the grayscale for the image but to write the grayscaled mask to a 2D BRAM
// Since we won't use the value of the mask that are not inside the mask, there is no point
// writing or calculating them. We will only write the values that are inside the mask to the mask BRAM,
// and then stop. This will also allow us to have a smaller BRAM size for the mask.

// Comment this line out for synthesis but uncomment for simulations
// `include "globals.sv"

module grayscale_mask (
    input  logic        clock,
    input  logic        reset,
    output logic        in_rd_en,
    input  logic        in_empty,
    input  logic [23:0] in_dout,
    input  logic        hough_done,
    // Output wires to write to BRAM
    output logic                                    out_wr_en,
    output logic [$clog2(REDUCED_IMAGE_SIZE)-1:0]   out_wr_addr,
    output logic [7:0]                              out_wr_data
);

typedef enum logic [1:0] {IDLE, GS, DONE} state_types;
state_types state, next_state;

logic [7:0] gs_c;

// Variables to track the x_full_image and y_full_image indices of the entire image
logic [$clog2(WIDTH)-1:0] x_full_image, x_full_image_c;
logic [$clog2(HEIGHT)-1:0] y_full_image, y_full_image_c;
// Variable to track the x and y indices of just the mask (or the rectangle that encompasses the mask)
logic [$clog2(REDUCED_WIDTH)-1:0] x_mask, x_mask_c;
logic [$clog2(REDUCED_HEIGHT)-1:0] y_mask, y_mask_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        state <= IDLE;
        // gs <= 8'h0;
        x_full_image <= '0;
        y_full_image <= '0;
        x_mask <= '0;
        y_mask <= '0;
    end else begin
        state <= next_state;
        // gs <= gs_c;
        x_full_image <= x_full_image_c;
        y_full_image <= y_full_image_c;
        x_mask <= x_mask_c;
        y_mask <= y_mask_c;
    end
end

always_comb begin
    in_rd_en  = 1'b0;
    out_wr_en = 1'b0;
    out_wr_data = 8'b0;
    out_wr_addr = 0;
    next_state = state;
    x_full_image_c = x_full_image;
    y_full_image_c = y_full_image;
    x_mask_c = x_mask;
    y_mask_c = y_mask;

    case (state)
        IDLE: begin
            // Reset the x_full_image and y_full_image coordinates once we are in the IDLE state and we see there is a value inside the input FIFO
            if (in_empty == 1'b0) begin
                next_state = GS;
                x_full_image_c = 0; 
                y_full_image_c = 0;
                x_mask_c = 0;
                y_mask_c = 0;
            end
        end
        GS: begin
            if (in_empty == 1'b0) begin
                // Calculating the grayscale value if there is value in the FIFO available to be read
                gs_c = 8'(($unsigned({2'b0, in_dout[23:16]}) + $unsigned({2'b0, in_dout[15:8]}) + $unsigned({2'b0, in_dout[7:0]})) / $unsigned(10'd3));
                in_rd_en = 1'b1;
                // Writing to the mask BRAM with the grayscale value if the grayscale pixel is inside the mask
                if (x_full_image >= STARTING_X && x_full_image <= ENDING_X && y_full_image >= STARTING_Y && y_full_image <= ENDING_Y) begin
                    // We want to use the mask indices to write to the BRAM since the BRAM will only have enough space for the mask values
                    out_wr_addr = (y_mask * REDUCED_WIDTH) + x_mask;
                    out_wr_data = gs_c;
                    out_wr_en = 1'b1;
                    // Calculate the new indices for the mask
                    if (x_mask == REDUCED_WIDTH-1) begin
                        if (y_mask == REDUCED_HEIGHT-1) 
                            // We will switch back to IDLE after we have filled up the mask BRAM
                            next_state = DONE;    
                        else begin
                            x_mask_c = 0;
                            y_mask_c = y_mask + 1;
                        end                
                    end else begin
                        x_mask_c = x_mask + 1;
                    end
                end
                // Calculate the new indices for the full image regardless of if we are inside the mask or not (or if we have written a value to the mask BRAM or not)
                if (x_full_image == WIDTH-1) begin
                    if (y_full_image == HEIGHT-1) 
                        next_state = IDLE;    
                    else begin
                        x_full_image_c = 0;
                        y_full_image_c = y_full_image + 1;
                    end                
                end else begin
                    x_full_image_c = x_full_image + 1;
                end
            end
        end

        DONE: begin
            // Done state that this will remain until hough_done is asserted and it will go back into IDLE.
            // This is so that it doesn't override the mask BRAM with the wrong values since there will still
            // be more pixels coming in through the FIFO.
            if (hough_done == 1'b1) 
                next_state = IDLE;
        end

        default: begin
            in_rd_en  = 1'b0;
            out_wr_en = 1'b0;
            out_wr_data = 8'b0;
            out_wr_addr = 0;
            next_state = IDLE;
            x_full_image_c = 'X;
            y_full_image_c = 'X;
            x_mask_c = 'X;
            y_mask_c = 'X;
        end

    endcase
end

endmodule