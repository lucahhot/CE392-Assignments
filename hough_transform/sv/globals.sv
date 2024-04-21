// Image dimensions
localparam WIDTH = 720;
localparam HEIGHT = 540;

// Mask info
localparam MASK_BL_X = 0.0
localparam MASK_BL_Y = (1 - 0.95)
localparam MASK_BR_X = 1.0
localparam MASK_BR_Y = (1 - 0.95)
localparam MASK_TL_X = 0.4
localparam MASK_TL_Y = 1 - 0.65
localparam MASK_TR_X = 0.85
localparam MASK_TR_Y = (1 - 0.65)

// Adjusted height and width to save cycles
localparam WIDTH_ADJUSTED = WIDTH * MASK_BR_X;
localparam HEIGHT_ADJUSTED = HEIGHT * MASK_TR_Y;

localparam STARTING_X = WIDTH * MASK_BL_X;
localparam STARTING_Y = HEIGHT * MASK_BL_Y;

localparam THETAS = 180;
localparam RHOS = sqrt(WIDTH_ADJUSTED*WIDTH_ADJUSTED + HEIGHT_ADJUSTED*HEIGHT_ADJUSTED);
localparam RHO_RANGE = 2*RHOS;
