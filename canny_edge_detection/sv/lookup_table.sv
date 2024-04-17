module lookup_table#(
  ANGLE_RANGE = 180,
  DATA_WIDTH = 16,
  FRAC_BITS = 13
) (
  input logic [$clog2(ANGLE_RANGE)-1:0] angle,
  output logic [DATA_WIDTH-1:0] sine,
  output logic [DATA_WIDTH-1:0] cosine
);

  logic signed [DATA_WIDTH-1:0] sine_table[ANGLE_RANGE];
  logic signed [DATA_WIDTH-1:0] cosine_table[ANGLE_RANGE];

  function void init_trig_tables();
    real sin_val;
    real cos_val;
    for (int i = 0; i < ANGLE_RANGE; i++) begin
      sin_val = $sin(i * 3.1415926535 / 180);
      cos_val = $cos(i * 3.1415926535 / 180);

      sine_table[i] = real2fixed(sin_val, FRAC_BITS);
      cosine_table[i] = real2fixed(cos_val, FRAC_BITS);
    end
  endfunction

  function signed [DATA_WIDTH-1:0] real2fixed(real val, int frac_bits);
      return signed'($rtoi(val * (1 << frac_bits)));
  endfunction

  initial init_trig_tables();

  always_comb begin
    sine = sine_table[angle];
    cosine = cosine_table[angle];
  end

endmodule
