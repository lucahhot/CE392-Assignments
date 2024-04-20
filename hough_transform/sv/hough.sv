// This module will take in the output of the hysteresis stage and the mask, and 
// output the accum_buff which will be a 2D array of all the possible rhos and thetas.

// Hysteresis inputs will be streamed in pixel by pixel, but we need to loop through 0 to THETAS
// PER pixel, this hough module will be stalled per pixel and it might stall the entire canny edge
// pipeline before this. Making the hysteresis output FIFO super big is obviously not a good idea,
// so another idea might be to store the hysteresis, initial image, and mask into some time of memory,
// so we can read them as we want to inside of hough. Will try to store the images (including the mask)
// and the hysteresis output in a BRAM and read them as we want to.

module hough #(
    parameter WIDTH = 720,
    parameter HEIGHT = 540
) (
    input  logic        clock,
    input  logic        reset,
    // HYSTERESIS INPUTS from FIFO???
    output logic        hysteresis_in_rd_en,
    input  logic        hysteresis_in_empty,
    input  logic [7:0]  hysteresis_in_dout,
    // OUTPUTS here
);

endmodule