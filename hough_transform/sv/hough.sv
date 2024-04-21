// This module will take in the output of the hysteresis stage and the mask, and 
// calculate the accum_buff which will be a 2D array of all the possible rhos and thetas.

// (Might do the highlighting of the lanes in this module to avoid having to transfer the 
// accum_buff to another module to do the highlighting).

// Hysteresis inputs will be streamed in pixel by pixel, but we need to loop through 0 to THETAS
// PER pixel, therefore this hough module will be stalled per pixel and it might stall the entire canny edge
// pipeline before this. Making the hysteresis output FIFO super big is obviously not a good idea,
// so another idea might be to store the hysteresis, initial image, and mask into some time of memory,
// so we can read them as we want to inside of hough. Will try to store the images (including the mask)
// and the hysteresis output in a BRAM and read them as we want to. The accum_buff will currenly be a 2D
// array of flip flops as it'll be easier to implement since I don't know how to zero or reset the BRAM
// and also we would need to read and write to each accum_buff array value in 1 clock cycle, which is not
// possible with the BRAM.

`include "globals.sv"

module hough (
    input  logic        clock,
    input  logic        reset,
    input  logic        start,
    // HYSTERESIS INPUTS from bram_2d
    input  logic [7:0]  hysteresis_bram_dout,
    output logic [$clog2(WIDTH)-1:0] hysteresis_bram_addr_x,
    output logic [$clog2(HEIGHT)-1:0] hysteresis_bram_addr_y,
    // MASK INPUTs from bram_2d
    input  logic [7:0]  mask_bram_dout,
    output logic [$clog2(WIDTH)-1:0] mask_bram_addr_x,
    output logic [$clog2(HEIGHT)-1:0] mask_bram_addr_y, 
    // UNSURE OF OUTPUTS FOR NOW
);

typedef enum logic [1:0] {IDLE, LOAD_DATA, ACCUMULATE, SELECT} state_types;

// Accumulator buffer (2D array of all possible rhos and thetas)
// Each entry will be a 16 bit value as specified in the C code by Professor Zaretsky
logic [15:0] accum_buff [0:RHO_RANGE-1][0:THETAS-1];

always_ff @(posedge clock or posedge reset) begin
    if (reset == 1'b1) begin
        accum_buff <= '{default: '{default: '{default: '0}}};
    end


end



endmodule