`timescale  1ns/1ns

module hough_transform_tb;

`include "globals.sv"

localparam IMG_IN_NAME = "../images/stage4_hysteresis.bmp";
localparam FILE_OUT_NAME = "../sim/accum_buff_out.txt"
localparam FILE_CMP_NAME = "../source/accum.txt"

localparam BMP_HEADER_SIZE = 138;
localparam BYTES_PER_PIXEL = 3;
localparam BMP_DATA_SIZE = WIDHT*HEIGHT*BYTES_PER_PIXEL;

logic out_rd_done, in_write_done;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done = '0;

logic hough_in_full, hough_in_wr_en;
logic [7:0] hough_data_in;
logic hough_out_empty, hough_out_rd_en;
logic [15:0] hough_data_out;

hough_transform_top #(
    .WIDTH(WIDTH),
    .HEIGHT(HEGIHT),
    .X_WIDTH(X_WIDTH),
    .Y_WIDTH(Y_WIDTH),
    .X_START(X_START),
    .Y_START(Y_START),
    .THETAS(THETAS),
    .RHO_RESOLUTION(RHO_RESOLUTION),
    .RHOS(RHOS),
    .IMG_BITS(IMG_BITS),
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .BITS(BITS),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE),
    .ACCUM_BUFF_SIZE(ACCUM_BUFF_SIZE),
    .ACCUM_BITS(ACCUM_BITS)
) hough_top_inst (
    .clock(clock),
    .reset(reset),
    .in_full(hough_in_full),
    .in_wr_en(hough_in_wr_en),
    .data_in(hough_data_in),
    .out_empty(hough_out_empty),
    .out_rd_en(hough_out_rd_en),
    .data_out(hough_data_out)
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
    int in_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];
    logic [23:0] in_din;

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);

    in_file = $fopen(IMG_IN_NAME, "rb");
    hough_in_wr_en = 1'b0;

    // Skip BMP header
    r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

    // Read data from image file
    i = 0;
    while ( i < BMP_DATA_SIZE ) begin
        @(negedge clock);
        in_wr_en = 1'b0;
        if (in_full == 1'b0) begin
            r = $fread(in_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            // get first 8 bits, B&W values so should be the same
            hough_data_in = in_din[7:0];
            hough_in_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    hough_in_wr_en = 1'b0;
    $fclose(in_file);
    in_write_done = 1'b1;
end

initial begin : buff_cmp_process
    int i, r;
    int out_file;
    int cmp_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");
    out_rd_en = 1'b0;

    i = 0;
    while () begin
        @(negedge clock);
        out_rd_en = 1'b0;
        if (out_empty == 1'b0) begin
            r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            $fwrite(out_file, "%c%c%c", out_dout, out_dout, out_dout);

            if (cmp_dout != {3{out_dout}}) begin
                out_errors += 1;
                // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, {3{out_dout}}, cmp_dout, i);
            end
            out_rd_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    out_rd_en = 1'b0;
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
end

endmodule