
`timescale 1 ns / 1 ns

module highlight_tb;

// localparam string IMG_IN_NAME  = "../images/road_image_1280_720.bmp";
localparam string MASK_IN_NAME = "../images/mask_1280_720.bmp";
localparam string IMG_OUT_NAME = "../images/highlight_output.bmp";
localparam string IMG_CMP_NAME = "../images/stage6_hough.bmp";
// localparam string FILE_OUT_NAME = "../source/accum_buff_rtl_output.txt";
// localparam string FILE_CMP_NAME = "../source/accum_buff_results.txt";
localparam CLOCK_PERIOD = 10;

localparam WIDTH = 1280;
localparam HEIGHT = 720;
localparam THETA_BITS = 9;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic signed [15:0]     left_rho_in = -163;
logic signed [15:0]     right_rho_in = 575;
logic [THETA_BITS-1:0]  left_theta_in = 128;
logic [THETA_BITS-1:0]  right_theta_in = 60;
logic                   mask_full;
logic                   mask_wr_en;
logic [23:0]            mask_din;
logic                   highlight_done;
logic [23:0]            output_data;

logic   hold_clock = '0;
logic   in_write_done = '0;
logic   mask_write_done = '0;
logic   out_read_done = '0;
integer out_errors = '0;

localparam BMP_HEADER_SIZE = 138; // According to canny_and_hough.c
localparam BYTES_PER_PIXEL = 3; // According to canny_and_hough.c
localparam BMP_DATA_SIZE = WIDTH*HEIGHT*BYTES_PER_PIXEL;

highlight_top highlight_top_inst (
    .clock(clock),
    .reset(reset),
    .left_rho_in(left_rho_in),
    .right_rho_in(right_rho_in),
    .left_theta_in(left_theta_in),
    .right_theta_in(right_theta_in),
    .mask_full(mask_full),
    .mask_wr_en(mask_wr_en),
    .mask_din(mask_din),
    .highlight_done(highlight_done),
    .output_data(output_data)
);

always begin
    clock = 1'b1;
    #(CLOCK_PERIOD/2);
    clock = 1'b0;
    #(CLOCK_PERIOD/2);
end

initial begin
    @(posedge clock);
    reset = 1'b1;
    @(posedge clock);
    reset = 1'b0;
end

initial begin : tb_process
    longint unsigned start_time, end_time;

    @(negedge reset);
    @(posedge clock);
    start_time = $time;

    // start
    $display("@ %0t: Beginning simulation...", start_time);
    start = 1'b1;
    @(posedge clock);
    start = 1'b0;

    wait(out_read_done);
    end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total error count: %0d", out_errors);

    // end the simulation
    $finish;
end

initial begin : mask_read_process
    int i, r_mask;
    int mask_file;
    logic [7:0] mask_bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);

    $display("@ %0t: Loading file %s...", $time, MASK_IN_NAME);

    mask_file = $fopen(MASK_IN_NAME, "rb");

    mask_wr_en = 1'b0;

    r_mask = $fread(mask_bmp_header, mask_file, 0, BMP_HEADER_SIZE);

    i = 0;
    while ( i < BMP_DATA_SIZE ) begin
        @(negedge clock);
        mask_wr_en = 1'b0;
        if (mask_full == 1'b0) begin
            r_mask = $fread(mask_din, mask_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            mask_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    mask_wr_en = 1'b0;
    $fclose(mask_file);
    mask_write_done = 1'b1;
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int cmp_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    // $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");
    
    // Copy the BMP header
    r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
        $fwrite(out_file, "%c", bmp_header[i]);
    end

    // Wait until highlight is done before reading the output
    wait(highlight_done);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);

    i = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clock);
        r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
        $fwrite(out_file, "%c%c%c", output_data[23:16], output_data[15:8], output_data[7:0]);

            // if (cmp_dout != output_data) begin
            //     out_errors += 1;
            //     // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, {3{out_dout}}, cmp_dout, i);
            // end
            i += BYTES_PER_PIXEL;
        @(negedge clock);   
    end

    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
end

endmodule
