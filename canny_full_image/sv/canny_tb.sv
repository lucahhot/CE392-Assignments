
`timescale 1 ns / 1 ns

module canny_tb;

localparam string IMG_IN_NAME  = "/home/laa8390/Documents/CE392/CE392-Assignments/hough_transform/images/road_image_1280_720.bmp";
localparam string IMG_OUT_NAME = "../images/canny_output.bmp";
localparam string IMG_CMP_NAME = "/home/laa8390/Documents/CE392/CE392-Assignments/hough_transform/images/stage4_hysteresis.bmp";
localparam CLOCK_PERIOD = 10;

localparam WIDTH = 1280;
localparam HEIGHT = 720;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic image_full;
logic image_wr_en;
logic [23:0] image_din;
logic img_out_rd_en;
logic img_out_empty;
logic [7:0] img_out_dout;

logic   hold_clock = '0;
logic   in_write_done = '0;
logic   out_read_done = '0;
integer error_count = '0;

localparam BMP_HEADER_SIZE = 138; // According to canny_and_hough.c
localparam BYTES_PER_PIXEL = 3; // According to canny_and_hough.c
localparam BMP_DATA_SIZE = WIDTH*HEIGHT*BYTES_PER_PIXEL;

canny_top #(
    .WIDTH (WIDTH),
    .HEIGHT(HEIGHT),
    .FIFO_BUFFER_SIZE(8)
) canny_top_inst (
    .clock(clock),
    .reset(reset),
    // IMAGE INPUT
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
    // IMAGE OUTPUT
    .img_out_rd_en(img_out_rd_en),
    .img_out_empty(img_out_empty),
    .img_out_dout(img_out_dout)
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
    $display("Total error count: %0d", error_count);

    // end the simulation
    $finish;
end

initial begin : img_read_process
    int i, r;
    int in_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);
    
    in_file = $fopen(IMG_IN_NAME, "rb");
    
    image_wr_en = 1'b0;
    
    // Skip BMP header
    r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

    // Read data from image file
    i = 0;
    while ( i < BMP_DATA_SIZE) begin
        @(negedge clock);
        image_wr_en = 1'b0;
        if (image_full == 1'b0) begin
            r = $fread(image_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            image_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    image_wr_en = 1'b0;
    $fclose(in_file);
    in_write_done = 1'b1;
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int cmp_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s with %s...", $time, IMG_OUT_NAME, IMG_CMP_NAME);
    
    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");
    img_out_rd_en = 1'b0;
    
    // Copy the BMP header
    r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
        $fwrite(out_file, "%c", bmp_header[i]);
    end

    i = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clock);
        img_out_rd_en = 1'b0;
        if (img_out_empty == 1'b0) begin
            r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            $fwrite(out_file, "%c%c%c", img_out_dout, img_out_dout, img_out_dout);

            if (cmp_dout != {3{img_out_dout}}) begin
                error_count += 1;
                // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, {3{img_out_dout}}, cmp_dout, i);
            end
            img_out_rd_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    img_out_rd_en = 1'b0;
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
end

endmodule
