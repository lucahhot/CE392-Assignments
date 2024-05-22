
`timescale 1 ns / 1 ns

module highlight_tb;

localparam string IMG_IN_NAME  = "../images/road_image_1280_720.bmp";
localparam string MASK_IN_NAME = "../images/mask_1280_720.bmp";
localparam string IMG_OUT_NAME = "../images/highlight_output.bmp";
localparam string IMG_CMP_NAME = "../images/stage6_hough.bmp";
localparam string IMG_OUT_NAME_2 = "../images/highlight_output_test.bmp";



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
logic                   image_full;    
logic                   image_wr_en;
logic [23:0]            image_din;   
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

localparam TEST_LINE_LENGTH = 1000;

highlight_top highlight_top_inst (
    .clock(clock),
    .reset(reset),
    .left_rho_in(left_rho_in),
    .right_rho_in(right_rho_in),
    .left_theta_in(left_theta_in),
    .right_theta_in(right_theta_in),
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
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
initial begin : img_read_process
    int i, r;
    int in_file, image_input_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);
    
    in_file = $fopen(IMG_IN_NAME, "rb");
    image_input_file = $fopen("../source/test_values/highlight_input_values.txt", "w");
    
    image_wr_en = 1'b0;
    
    // Skip BMP header
    r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

    // Read data from image file
    i = 0;
    while ( i < BMP_DATA_SIZE ) begin
        @(negedge clock);
        image_wr_en = 1'b0;
        if (image_full == 1'b0) begin
            r = $fread(image_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            $fwrite(image_input_file, "%x\n", image_din);
            image_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    image_wr_en = 1'b0;
    $fclose(in_file);
    in_write_done = 1'b1;
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
    int out_file, cmp_file, image_output_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];
    int x, y; 

    @(negedge reset);
    @(negedge clock);

    // $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");

    image_output_file = $fopen("../source/test_values/highlight_output_values.txt", "w");
    
    // Copy the BMP header
    r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
        $fwrite(out_file, "%c", bmp_header[i]);
    end

    // Wait until highlight is done before reading the output
    wait(highlight_done);
    @(negedge clock);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);

    i = 0;
    x = 0; 
    y = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clock);
        r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
        $fwrite(out_file, "%c%c%c", output_data[23:16], output_data[15:8], output_data[7:0]);
        $fwrite(image_output_file, "output_data: %x, cmp_dout: %x at x = %0d, y = %0d\n", output_data, cmp_dout, x, y);

            if (cmp_dout != output_data) begin
                out_errors += 1;
                // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, {3{out_dout}}, cmp_dout, i);
                $fwrite(image_output_file, "@ %0t: ERROR: output_data: %x, cmp_dout: %x at x = %0d, y = %0d\n", $time, output_data, cmp_dout, x, y);
            end
            i += BYTES_PER_PIXEL;

            if (x == WIDTH-1) begin
                x = 0;
                y += 1;
            end else begin
                x += 1;
            end

        @(negedge clock);   
    end

    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    $fclose(image_output_file);
    out_read_done = 1'b1;
end

initial begin : test_process
    int test_file, test_status;
    int iiii;
    test_file = $fopen(IMG_OUT_NAME_2, "r+");

    // wait(highlight_done);
    @(negedge clock);
    @(negedge clock);
    $display("Writing to the test image");
    test_status = $fseek(test_file, BMP_HEADER_SIZE+36000, 0);
    iiii = 0;

    while ( iiii < TEST_LINE_LENGTH) begin
        @(negedge clock);
        $fwrite(test_file, 24'b000000001111111100000000);
        iiii += 1;
    end



end

endmodule
