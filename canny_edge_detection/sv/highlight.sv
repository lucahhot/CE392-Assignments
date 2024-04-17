module hightlight#(
    WIDTH = 720,
    HEIGHT = 540
) (
    input  logic        clock,
    input  logic        reset,
    input logic        rd_en,
    input  logic        in_empty,
    input  logic [23:0]  in_dout
    // output logic        out_wr_en,
    // input  logic        out_full,
    // output logic [23:0]  out_din
);




typedef enum logic [1:0] {READING_IMAGE, FULL} image_state_types;
image_state_types image_state, next_image_state;

logic [WIDTH*HEIGHT-1:0][23:0] whole_image;

logic [$clog2(HEIGHT*WIDTH)-1:0] image_index, image_index_c;



always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        image_state <= READING_IMAGE;
        whole_image <= '{default: '{default: '0}};
        image_index <= '0;
    end else begin
        image_state <= next_image_state;
        image_index <= image_index_c;
    end
end

always_ff @(posedge rd_en) begin
    image_index_c = image;
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
    endcase 
end

// always_comb begin
//     next_image_state = image_state;
//     image_index_c = image_index;
    
// end



// parameter HIGH_THRESHOLD = 48;
// parameter LOW_THRESHOLD = 12;  

// typedef enum logic [1:0] {PROLOGUE, HYSTERESIS, OUTPUT} state_types;
// state_types state, next_state;
// parameter SHIFT_REG_LEN = 2*WIDTH+3;
// parameter PIXEL_COUNT = WIDTH*HEIGHT;

// // Shift register
// logic [0:SHIFT_REG_LEN-1][7:0] shift_reg ;
// logic [0:SHIFT_REG_LEN-1][7:0] shift_reg_c;

// // Counters for prologue
// logic [$clog2(WIDTH+2)-1:0] counter, counter_c;

// // Column counter to know when to jump
// logic [$clog2(WIDTH)-1:0] col, col_c;

// // Row counter to know when we need to enter epilogue and push more zeros
// logic [$clog2(HEIGHT)-1:0] row, row_c;

// // Hysteresis value
// logic [7:0] hysteresis, hysteresis_c;

// // Wires to hold temporary pixel values
// logic [7:0] pixel1,pixel2,pixel3,pixel4,pixel5,pixel6,pixel7,pixel8,pixel9;

// always_ff @(posedge clock or posedge reset) begin
//     if (reset == 1'b1) begin
//         state <= PROLOGUE;
//         shift_reg <= '{default: '{default: '0}};
//         counter <= '0;
//         col <= '0;
//         row <= '0;
//         hysteresis <= '0;
//     end else begin
//         state <= next_state;
//         shift_reg <= shift_reg_c;
//         counter <= counter_c;
//         col <= col_c;
//         row <= row_c;
//         hysteresis <= hysteresis_c;
//     end
// end

// always_comb begin
//     next_state = state;
//     in_rd_en = 1'b0;
//     out_wr_en = 1'b0;
//     out_din = 8'h00;
//     counter_c = counter;
//     col_c = col;
//     row_c = row;
//     shift_reg_c = shift_reg;
//     hysteresis_c = hysteresis;

//     if (state != OUTPUT) begin
//         if (in_empty == 1'b0) begin
//             // Implementing a shift right register
//             shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
//             shift_reg_c[SHIFT_REG_LEN-1] = in_dout;
//             in_rd_en = 1'b1;
//         // If we have reached the end of the pixels from the FIFO, shift in zeros for padding
//         end else if ((row*WIDTH) + col > (PIXEL_COUNT-1) - (WIDTH+2)) begin
//             shift_reg_c[0:SHIFT_REG_LEN-2] = shift_reg[1:SHIFT_REG_LEN-1];
//             shift_reg_c[SHIFT_REG_LEN-1] = 8'h00;
//         end
//     end

// case(state) 
//         // Prologue
//         PROLOGUE: begin
//             // Waiting for shift register to fill up enough to start sobel HYSTERESIS
//             if (counter < WIDTH + 2) begin
//                 if (in_empty == 1'b0)
//                     counter_c++;
//             end else 
//                 next_state = HYSTERESIS;
//         end
//         // Sobel HYSTERESISing
//         HYSTERESIS: begin
//             // Only calculate hysteresis value if we there is input from the input FIFO 
//             if (in_empty == 1'b0 || ((row*WIDTH) + col > (PIXEL_COUNT-1) - (WIDTH+2))) begin
//                 // If we are on an edge pixel, the hysteresis value will be zero
//                 if (row != 0 && row != (HEIGHT - 1) && col != 0 && col != (WIDTH - 1)) begin
//                     // Grabbing correct pixel values from the shift register
//                     pixel1 = shift_reg[0];
//                     pixel2 = shift_reg[1];
//                     pixel3 = shift_reg[2];
//                     pixel4 = shift_reg[WIDTH];
//                     pixel5 = shift_reg[WIDTH+1];
//                     pixel6 = shift_reg[WIDTH+2];
//                     pixel7 = shift_reg[WIDTH*2];
//                     pixel8 = shift_reg[WIDTH*2+1];
//                     pixel9 = shift_reg[WIDTH*2+2];

//                     // If pixel is strong or it is somewhat strong and at least one 
// 			        // neighbouring pixel is strong, keep it. Otherwise zero it.
//                     if (pixel5 > HIGH_THRESHOLD || (pixel5 > LOW_THRESHOLD && 
//                         (pixel1 > HIGH_THRESHOLD || pixel2 > HIGH_THRESHOLD || pixel3 > HIGH_THRESHOLD || 
//                         pixel4 > HIGH_THRESHOLD || pixel6 > HIGH_THRESHOLD || pixel7 > HIGH_THRESHOLD || 
//                         pixel8 > HIGH_THRESHOLD || pixel9 > HIGH_THRESHOLD))) begin
//                             hysteresis_c = pixel5;
//                         end else begin
//                             hysteresis_c = '0;
//                         end
                        
//                 end else begin
//                     hysteresis_c = '0;
//                 end
//                 // Increment col and row trackers
//                 if (col == WIDTH - 1) begin
//                     col_c = 0;
//                     row_c++;
//                 end else
//                     col_c++;

//                 next_state = OUTPUT;
//             end

//         end
//         // Writing to FIFO
//         OUTPUT: begin
//             if (out_full == 1'b0) begin
//                 out_din = hysteresis;
//                 out_wr_en = 1'b1;
//                 next_state = HYSTERESIS;
//                 // If we have reached the last pixel of the entire image, go back to PROLOGUE and reset everything
//                 if (row == HEIGHT && col == WIDTH) begin
//                     next_state = PROLOGUE;
//                     row_c = 0;
//                     col_c = 0;
//                     counter_c = 0;
//                     hysteresis_c = 0;
//                     // shift_reg_c = '{default: '{default: '0}};
//                 end
//             end
//         end
//         default: begin
//             next_state = PROLOGUE;
//             in_rd_en = 1'b0;
//             out_wr_en = 1'b0;
//             out_din = '0;
//             counter_c = 'X;
//             col_c = 'X;
//             row_c = 'X;
//             shift_reg_c = '{default: '{default: '0}};
//             hysteresis_c = 'X;
//         end
//     endcase
// end

endmodule
