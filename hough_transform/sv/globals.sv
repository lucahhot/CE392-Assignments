// Image dimensions
localparam WIDTH = 720;
localparam HEIGHT = 540;
localparam IMAGE_SIZE = WIDTH * HEIGHT;
localparam FIFO_BUFFER_SIZE = 8;

// Mask info
localparam MASK_BL_X = 0.0;
localparam MASK_BL_Y = (1 - 0.95);
localparam MASK_BR_X = 1.0;
localparam MASK_BR_Y = (1 - 0.95);
localparam MASK_TL_X = 0.4;
localparam MASK_TL_Y = 1 - 0.65;
localparam MASK_TR_X = 0.85;
localparam MASK_TR_Y = (1 - 0.65);

// Adjusted height and width to save cycles
localparam WIDTH_ADJUSTED = WIDTH * MASK_BR_X;
localparam HEIGHT_ADJUSTED = HEIGHT * MASK_TR_Y;

localparam STARTING_X = WIDTH * MASK_BL_X;
localparam STARTING_Y = HEIGHT * MASK_BL_Y;

localparam THETAS = 180;
localparam RHOS = $sqrt(WIDTH_ADJUSTED*WIDTH_ADJUSTED + HEIGHT_ADJUSTED*HEIGHT_ADJUSTED);
localparam RHO_RANGE = 2*RHOS;

// Quantization constants
localparam BITS = 8;
localparam DATA_SIZE = 16;

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

// Quantized trig values (quantized using 8 bits for the fractional part)
// Going to make it 16 bits for now, might have to change it later
parameter logic signed [0:179] [DATA_SIZE-1:0] SIN_QUANTIZED = '{16'h0000, 16'h0004, 16'h0008, 16'h000d, 16'h0011, 16'h0016, 16'h001a, 16'h001f, 16'h0023, 16'h0028, 16'h002c, 16'h0030, 16'h0035, 16'h0039, 16'h003d, 16'h0042, 16'h0046, 16'h004a, 16'h004f, 16'h0053, 16'h0057, 16'h005b, 16'h005f, 16'h0064, 16'h0068, 16'h006c, 16'h0070, 16'h0074, 16'h0078, 16'h007c, 16'h0080, 16'h0083, 16'h0087, 16'h008b, 16'h008f, 16'h0092, 16'h0096, 16'h009a, 16'h009d, 16'h00a1, 16'h00a4, 16'h00a7, 16'h00ab, 16'h00ae, 16'h00b1, 16'h00b5, 16'h00b8, 16'h00bb, 16'h00be, 16'h00c1, 16'h00c4, 16'h00c6, 16'h00c9, 16'h00cc, 16'h00cf, 16'h00d1, 16'h00d4, 16'h00d6, 16'h00d9, 16'h00db, 16'h00dd, 16'h00df, 16'h00e2, 16'h00e4, 16'h00e6, 16'h00e8, 16'h00e9, 16'h00eb, 16'h00ed, 16'h00ee, 16'h00f0, 16'h00f2, 16'h00f3, 16'h00f4, 16'h00f6, 16'h00f7, 16'h00f8, 16'h00f9, 16'h00fa, 16'h00fb, 16'h00fc, 16'h00fc, 16'h00fd, 16'h00fe, 16'h00fe, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h0100, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00fe, 16'h00fe, 16'h00fd, 16'h00fc, 16'h00fc, 16'h00fb, 16'h00fa, 16'h00f9, 16'h00f8, 16'h00f7, 16'h00f6, 16'h00f4, 16'h00f3, 16'h00f2, 16'h00f0, 16'h00ee, 16'h00ed, 16'h00eb, 16'h00e9, 16'h00e8, 16'h00e6, 16'h00e4, 16'h00e2, 16'h00df, 16'h00dd, 16'h00db, 16'h00d9, 16'h00d6, 16'h00d4, 16'h00d1, 16'h00cf, 16'h00cc, 16'h00c9, 16'h00c6, 16'h00c4, 16'h00c1, 16'h00be, 16'h00bb, 16'h00b8, 16'h00b5, 16'h00b1, 16'h00ae, 16'h00ab, 16'h00a7, 16'h00a4, 16'h00a1, 16'h009d, 16'h009a, 16'h0096, 16'h0092, 16'h008f, 16'h008b, 16'h0087, 16'h0083, 16'h0080, 16'h007c, 16'h0078, 16'h0074, 16'h0070, 16'h006c, 16'h0068, 16'h0064, 16'h005f, 16'h005b, 16'h0057, 16'h0053, 16'h004f, 16'h004a, 16'h0046, 16'h0042, 16'h003d, 16'h0039, 16'h0035, 16'h0030, 16'h002c, 16'h0028, 16'h0023, 16'h001f, 16'h001a, 16'h0016, 16'h0011, 16'h000d, 16'h0008, 16'h0004};
parameter logic signed [0:179] [DATA_SIZE-1:0] COS_QUANTIZED = '{16'h0100, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00fe, 16'h00fe, 16'h00fd, 16'h00fc, 16'h00fc, 16'h00fb, 16'h00fa, 16'h00f9, 16'h00f8, 16'h00f7, 16'h00f6, 16'h00f4, 16'h00f3, 16'h00f2, 16'h00f0, 16'h00ee, 16'h00ed, 16'h00eb, 16'h00e9, 16'h00e8, 16'h00e6, 16'h00e4, 16'h00e2, 16'h00df, 16'h00dd, 16'h00db, 16'h00d9, 16'h00d6, 16'h00d4, 16'h00d1, 16'h00cf, 16'h00cc, 16'h00c9, 16'h00c6, 16'h00c4, 16'h00c1, 16'h00be, 16'h00bb, 16'h00b8, 16'h00b5, 16'h00b1, 16'h00ae, 16'h00ab, 16'h00a7, 16'h00a4, 16'h00a1, 16'h009d, 16'h009a, 16'h0096, 16'h0092, 16'h008f, 16'h008b, 16'h0087, 16'h0083, 16'h0080, 16'h007c, 16'h0078, 16'h0074, 16'h0070, 16'h006c, 16'h0068, 16'h0064, 16'h005f, 16'h005b, 16'h0057, 16'h0053, 16'h004f, 16'h004a, 16'h0046, 16'h0042, 16'h003d, 16'h0039, 16'h0035, 16'h0030, 16'h002c, 16'h0028, 16'h0023, 16'h001f, 16'h001a, 16'h0016, 16'h0011, 16'h000d, 16'h0008, 16'h0004, 16'h0000, 16'hfffc, 16'hfff8, 16'hfff3, 16'hffef, 16'hffea, 16'hffe6, 16'hffe1, 16'hffdd, 16'hffd8, 16'hffd4, 16'hffd0, 16'hffcb, 16'hffc7, 16'hffc3, 16'hffbe, 16'hffba, 16'hffb6, 16'hffb1, 16'hffad, 16'hffa9, 16'hffa5, 16'hffa1, 16'hff9c, 16'hff98, 16'hff94, 16'hff90, 16'hff8c, 16'hff88, 16'hff84, 16'hff80, 16'hff7d, 16'hff79, 16'hff75, 16'hff71, 16'hff6e, 16'hff6a, 16'hff66, 16'hff63, 16'hff5f, 16'hff5c, 16'hff59, 16'hff55, 16'hff52, 16'hff4f, 16'hff4b, 16'hff48, 16'hff45, 16'hff42, 16'hff3f, 16'hff3c, 16'hff3a, 16'hff37, 16'hff34, 16'hff31, 16'hff2f, 16'hff2c, 16'hff2a, 16'hff27, 16'hff25, 16'hff23, 16'hff21, 16'hff1e, 16'hff1c, 16'hff1a, 16'hff18, 16'hff17, 16'hff15, 16'hff13, 16'hff12, 16'hff10, 16'hff0e, 16'hff0d, 16'hff0c, 16'hff0a, 16'hff09, 16'hff08, 16'hff07, 16'hff06, 16'hff05, 16'hff04, 16'hff04, 16'hff03, 16'hff02, 16'hff02, 16'hff01, 16'hff01, 16'hff01, 16'hff01, 16'hff01}; 



