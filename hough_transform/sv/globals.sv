// Image dimensions
localparam WIDTH = 1280;
localparam HEIGHT = 720;
localparam IMAGE_SIZE = WIDTH * HEIGHT;
localparam FIFO_BUFFER_SIZE = 8;

// Adjusted height and width to save cycles (pre-calculated or else the fractions create problems)
localparam ENDING_X = 1152 + 5; // 1157 = WIDTH * MASK_BR_X + 5
localparam ENDING_Y = 251 + 5; // 256 = HEIGHT * MASK_TR_Y + 5

localparam STARTING_X = 128 - 5; // 123 = WIDTH * MASK_BL_X - 5
localparam STARTING_Y = 36 - 5; // 31 = HEIGHT * MASK_BL_Y - 5

// Reduced image dimensions (rectangle that encompasses the mask)
localparam REDUCED_WIDTH = ENDING_X - STARTING_X + 1; // 1157 - 123 + 1 = 1035 (need to include the last point as part of the width)
localparam REDUCED_HEIGHT = ENDING_Y - STARTING_Y + 1; // 256 - 31 + 1 = 226 (need to include the last point as part of the height)
localparam REDUCED_IMAGE_SIZE = REDUCED_WIDTH * REDUCED_HEIGHT; 

localparam THETAS = 180;
localparam RHOS = 1179;
localparam RHO_RANGE = 2*RHOS; // 2358

// Unroll factor for the accumulation stage (the theta loop)
localparam THETA_UNROLL = 4;
localparam THETA_DIVIDE_BITS = 2; // So that we don't have to divide by a non-power of 2 number (this means THEAT_UNROLL must be a power of 2)

// Accum_buff BRAM width (was set to 16 in the original C code given but we can reduce to 8 bits)
// It just has to be at least wide enough to go until HOUGH_TRANSFORM_THRESHOLD
localparam ACCUM_BUFF_WIDTH = 8;

// Theta bits (includes an extra bit just so we can always treat thetas as a signed number even though it'll always be positive)
localparam THETA_BITS = 9;
// Lane selection constants
localparam NUM_LANES = 100;
localparam HOUGH_TRANSFORM_THRESHOLD = 150;

// Quantization constants
localparam BITS = 8;
localparam TRIG_DATA_SIZE = 12;
localparam DEQUANTIZE_DATA_SIZE = 32;

// DEQUANTIZE function
function logic signed [15:0] DEQUANTIZE(logic signed [DEQUANTIZE_DATA_SIZE-1:0] i);
    // Arithmetic right shift doesn't work well with negative number rounding so switch the sign 
    // to perform the right shift then apply the negative sign to the results
    if (i < 0) 
        DEQUANTIZE = (16'(-(-i >>> BITS)));
    else 
        DEQUANTIZE = 16'(i >>> BITS);
endfunction

// QUANTIZE function
function logic signed [15:0] QUANTIZE(logic signed [15:0] i);
    QUANTIZE = 16'(i << BITS);
endfunction

// Quantized trig values (quantized using 8 bits for the fractional part)
// Going to make it 16 bits for now, might have to change it later (changed it to 12 bits)
// parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{16'h0000, 16'h0004, 16'h0008, 16'h000d, 16'h0011, 16'h0016, 16'h001a, 16'h001f, 16'h0023, 16'h0028, 16'h002c, 16'h0030, 16'h0035, 16'h0039, 16'h003d, 16'h0042, 16'h0046, 16'h004a, 16'h004f, 16'h0053, 16'h0057, 16'h005b, 16'h005f, 16'h0064, 16'h0068, 16'h006c, 16'h0070, 16'h0074, 16'h0078, 16'h007c, 16'h0080, 16'h0083, 16'h0087, 16'h008b, 16'h008f, 16'h0092, 16'h0096, 16'h009a, 16'h009d, 16'h00a1, 16'h00a4, 16'h00a7, 16'h00ab, 16'h00ae, 16'h00b1, 16'h00b5, 16'h00b8, 16'h00bb, 16'h00be, 16'h00c1, 16'h00c4, 16'h00c6, 16'h00c9, 16'h00cc, 16'h00cf, 16'h00d1, 16'h00d4, 16'h00d6, 16'h00d9, 16'h00db, 16'h00dd, 16'h00df, 16'h00e2, 16'h00e4, 16'h00e6, 16'h00e8, 16'h00e9, 16'h00eb, 16'h00ed, 16'h00ee, 16'h00f0, 16'h00f2, 16'h00f3, 16'h00f4, 16'h00f6, 16'h00f7, 16'h00f8, 16'h00f9, 16'h00fa, 16'h00fb, 16'h00fc, 16'h00fc, 16'h00fd, 16'h00fe, 16'h00fe, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h0100, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00fe, 16'h00fe, 16'h00fd, 16'h00fc, 16'h00fc, 16'h00fb, 16'h00fa, 16'h00f9, 16'h00f8, 16'h00f7, 16'h00f6, 16'h00f4, 16'h00f3, 16'h00f2, 16'h00f0, 16'h00ee, 16'h00ed, 16'h00eb, 16'h00e9, 16'h00e8, 16'h00e6, 16'h00e4, 16'h00e2, 16'h00df, 16'h00dd, 16'h00db, 16'h00d9, 16'h00d6, 16'h00d4, 16'h00d1, 16'h00cf, 16'h00cc, 16'h00c9, 16'h00c6, 16'h00c4, 16'h00c1, 16'h00be, 16'h00bb, 16'h00b8, 16'h00b5, 16'h00b1, 16'h00ae, 16'h00ab, 16'h00a7, 16'h00a4, 16'h00a1, 16'h009d, 16'h009a, 16'h0096, 16'h0092, 16'h008f, 16'h008b, 16'h0087, 16'h0083, 16'h0080, 16'h007c, 16'h0078, 16'h0074, 16'h0070, 16'h006c, 16'h0068, 16'h0064, 16'h005f, 16'h005b, 16'h0057, 16'h0053, 16'h004f, 16'h004a, 16'h0046, 16'h0042, 16'h003d, 16'h0039, 16'h0035, 16'h0030, 16'h002c, 16'h0028, 16'h0023, 16'h001f, 16'h001a, 16'h0016, 16'h0011, 16'h000d, 16'h0008, 16'h0004};
// parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{16'h0100, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00ff, 16'h00fe, 16'h00fe, 16'h00fd, 16'h00fc, 16'h00fc, 16'h00fb, 16'h00fa, 16'h00f9, 16'h00f8, 16'h00f7, 16'h00f6, 16'h00f4, 16'h00f3, 16'h00f2, 16'h00f0, 16'h00ee, 16'h00ed, 16'h00eb, 16'h00e9, 16'h00e8, 16'h00e6, 16'h00e4, 16'h00e2, 16'h00df, 16'h00dd, 16'h00db, 16'h00d9, 16'h00d6, 16'h00d4, 16'h00d1, 16'h00cf, 16'h00cc, 16'h00c9, 16'h00c6, 16'h00c4, 16'h00c1, 16'h00be, 16'h00bb, 16'h00b8, 16'h00b5, 16'h00b1, 16'h00ae, 16'h00ab, 16'h00a7, 16'h00a4, 16'h00a1, 16'h009d, 16'h009a, 16'h0096, 16'h0092, 16'h008f, 16'h008b, 16'h0087, 16'h0083, 16'h0080, 16'h007c, 16'h0078, 16'h0074, 16'h0070, 16'h006c, 16'h0068, 16'h0064, 16'h005f, 16'h005b, 16'h0057, 16'h0053, 16'h004f, 16'h004a, 16'h0046, 16'h0042, 16'h003d, 16'h0039, 16'h0035, 16'h0030, 16'h002c, 16'h0028, 16'h0023, 16'h001f, 16'h001a, 16'h0016, 16'h0011, 16'h000d, 16'h0008, 16'h0004, 16'h0000, 16'hfffc, 16'hfff8, 16'hfff3, 16'hffef, 16'hffea, 16'hffe6, 16'hffe1, 16'hffdd, 16'hffd8, 16'hffd4, 16'hffd0, 16'hffcb, 16'hffc7, 16'hffc3, 16'hffbe, 16'hffba, 16'hffb6, 16'hffb1, 16'hffad, 16'hffa9, 16'hffa5, 16'hffa1, 16'hff9c, 16'hff98, 16'hff94, 16'hff90, 16'hff8c, 16'hff88, 16'hff84, 16'hff80, 16'hff7d, 16'hff79, 16'hff75, 16'hff71, 16'hff6e, 16'hff6a, 16'hff66, 16'hff63, 16'hff5f, 16'hff5c, 16'hff59, 16'hff55, 16'hff52, 16'hff4f, 16'hff4b, 16'hff48, 16'hff45, 16'hff42, 16'hff3f, 16'hff3c, 16'hff3a, 16'hff37, 16'hff34, 16'hff31, 16'hff2f, 16'hff2c, 16'hff2a, 16'hff27, 16'hff25, 16'hff23, 16'hff21, 16'hff1e, 16'hff1c, 16'hff1a, 16'hff18, 16'hff17, 16'hff15, 16'hff13, 16'hff12, 16'hff10, 16'hff0e, 16'hff0d, 16'hff0c, 16'hff0a, 16'hff09, 16'hff08, 16'hff07, 16'hff06, 16'hff05, 16'hff04, 16'hff04, 16'hff03, 16'hff02, 16'hff02, 16'hff01, 16'hff01, 16'hff01, 16'hff01, 16'hff01}; 

parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] SIN_QUANTIZED = '{0, 4, 8, 13, 17, 22, 26, 31, 35, 40, 44, 48, 53, 57, 61, 66, 70, 74, 79, 83, 87, 91, 95, 100, 104, 108, 112, 116, 120, 124, 128, 131, 135, 139, 143, 146, 150, 154, 157, 161, 164, 167, 171, 174, 177, 181, 184, 187, 190, 193, 196, 198, 201, 204, 207, 209, 212, 214, 217, 219, 221, 223, 226, 228, 230, 232, 233, 235, 237, 238, 240, 242, 243, 244, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 254, 255, 255, 255, 255, 255, 256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4};
parameter logic signed [0:179] [TRIG_DATA_SIZE-1:0] COS_QUANTIZED = '{256, 255, 255, 255, 255, 255, 254, 254, 253, 252, 252, 251, 250, 249, 248, 247, 246, 244, 243, 242, 240, 238, 237, 235, 233, 232, 230, 228, 226, 223, 221, 219, 217, 214, 212, 209, 207, 204, 201, 198, 196, 193, 190, 187, 184, 181, 177, 174, 171, 167, 164, 161, 157, 154, 150, 146, 143, 139, 135, 131, 128, 124, 120, 116, 112, 108, 104, 100, 95, 91, 87, 83, 79, 74, 70, 66, 61, 57, 53, 48, 44, 40, 35, 31, 26, 22, 17, 13, 8, 4, 0, -4, -8, -13, -17, -22, -26, -31, -35, -40, -44, -48, -53, -57, -61, -66, -70, -74, -79, -83, -87, -91, -95, -100, -104, -108, -112, -116, -120, -124, -128, -131, -135, -139, -143, -146, -150, -154, -157, -161, -164, -167, -171, -174, -177, -181, -184, -187, -190, -193, -196, -198, -201, -204, -207, -209, -212, -214, -217, -219, -221, -223, -226, -228, -230, -232, -233, -235, -237, -238, -240, -242, -243, -244, -246, -247, -248, -249, -250, -251, -252, -252, -253, -254, -254, -255, -255, -255, -255, -255};




