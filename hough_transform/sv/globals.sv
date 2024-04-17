`ifndef __GLOBALS__
`define __GLOBALS__

// UVM Globals
localparam CLOCK_PERIOD = 10;
localparam CORDIC_DATA_WIDTH = 16;
localparam BITS = 14;
localparam QUANT_VAL = (1 << BITS);
localparam M_PI = 3.14159265358979323846;
localparam RAD_RATIO = 0.01745329251;
localparam DATA_SIZE = 32;
localparam FIFO_BUFFER_SIZE = 32;

localparam RHO_RESOLUTION = 1;
localparam THETAS = 180;
localparam WIDTH = 1200;
localparam HEIGHT = 900;
localparam RHOS = sqrt(WIDTH*WIDTH + HEIGHT*HEIGHT)/RHO_RESOLUTION;
localparam IMG_BITS = $clog2(WIDTH);
localparam X_WIDTH = IMG_BITS;
localparam Y_WIDTH = $clog2(HEIGHT/2)
localparam THETA_BITS = $clog2(THETAS);

// localparam X_START = -WIDTH/2;
// localparam X_START = 16'hFE98;
localparam X_START = 16'hFDA8;
localparam X_END = 16'h0258;
// localparam Y_START = -HEIGHT/2;
// localparam Y_START = 16'hFEF2;
localparam Y_START = 16'hFE3E;
// localparam X_END = 16'h0168;
localparam Y_END = 16'h0;

localparam ACCUM_BUFF_SIZE = RHOS * THETAS;
localparam ACCUM_BITS = $clog2(ACCUM_BUFF_SIZE);


// localparam string FILE_OUT_NAME = "../source/uvm_test_output.txt";

// QUANTIZE_F function
function int QUANTIZE_F(shortreal i);
    QUANTIZE_F = int'(shortreal'(i) * shortreal'(QUANT_VAL));
endfunction

// DEQUANTIZE_F function
function shortreal DEQUANTIZE_F(int i);
    DEQUANTIZE_F = shortreal'(shortreal'(i) / shortreal'(QUANT_VAL));
endfunction

localparam K = 1.646760258121066;
localparam logic signed [31:0] CORDIC_1K = QUANTIZE_F(1/K);
localparam logic signed [31:0] PI = QUANTIZE_F(M_PI);
localparam logic signed [31:0] HALF_PI = QUANTIZE_F(M_PI/2);
localparam logic signed [31:0] TWO_PI = QUANTIZE_F(M_PI*2);

// DEQUANTIZE function
function logic signed [DATA_SIZE-1:0] DEQUANTIZE(logic signed [DATA_SIZE-1:0] i);
    // Arithmetic right shift doesn't work well with negative number rounding so switch the sign 
    // to perform the right shift then apply the negative sign to the results
    if (i < 0) 
        DEQUANTIZE = DATA_SIZE'(-(-i >>> BITS));
    else 
        DEQUANTIZE = DATA_SIZE'(i >>> BITS);
endfunction

// QUANTIZE function
function logic signed [DATA_SIZE-1:0] QUANTIZE(logic signed [DATA_SIZE-1:0] i);
    QUANTIZE = DATA_SIZE'(i << BITS);
endfunction
`endif