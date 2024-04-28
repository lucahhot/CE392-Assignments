
`timescale 1 ns / 1 ns
`include "globals.sv"

module hough_tb;

localparam string IMG_IN_NAME  = "../images/road_image_1280_720.bmp";
localparam string MASK_IN_NAME = "../images/mask_1280_720.bmp";
// localparam string IMG_OUT_NAME = "../images/output.bmp";
// localparam string IMG_CMP_NAME = "../images/stage4_hysteresis.bmp";
localparam string FILE_OUT_NAME = "../source/accum_buff_rtl_output.txt";
localparam string FILE_CMP_NAME = "../source/accum_buff_results.txt";
localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic        image_full;
logic        image_wr_en  = '0;
logic [23:0] image_din    = '0;
logic        mask_full;
logic        mask_wr_en   = '0;
logic [23:0] mask_din     = '0;
logic [0:RHO_RANGE-1][0:THETAS-1][15:0] accum_buff_out;

logic   hold_clock    = '0;
logic   in_write_done = '0;
logic   mask_write_done = '0;
logic   out_read_done = '0;
integer out_errors    = '0;

localparam BMP_HEADER_SIZE = 138; // According to canny_and_hough.c
localparam BYTES_PER_PIXEL = 3; // According to canny_and_hough.c
localparam BMP_DATA_SIZE = WIDTH*HEIGHT*BYTES_PER_PIXEL;

hough_top hough_top_inst (
    .clock(clock),
    .reset(reset),
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
    .mask_full(mask_full),
    .mask_wr_en(mask_wr_en),
    .mask_din(mask_din),
    .done(hough_done),
    .accum_buff_out(accum_buff_out)
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

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);
    
    in_file = $fopen(IMG_IN_NAME, "rb");
    
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

initial begin : accum_buff_output_process
    int i, r;
    int cmp_val;
    int out_file, cmp_file, cmp_out_file;

    @(negedge reset);
    @(negedge clock);

    out_file = $fopen(FILE_OUT_NAME, "w");
    cmp_file = $fopen(FILE_CMP_NAME, "r");
    // cmp_out_file = $fopen("../source/cmp_out.txt", "w");

    // Waiting until the hough transform is done (at least till the accum_buff has been filled out)
    wait(hough_done);

    $display("@ %0t: Comparing file %s...", $time, FILE_OUT_NAME);

    // Write the accum_buff_out to a file
    for (int i = 0; i < RHO_RANGE; i++) begin
        for (int j = 0; j < THETAS; j++) begin
            $fwrite(out_file, "%0d\n", accum_buff_out[i][j]);
        end
    end

    // Compare the accum_buff_out to the expected results 
    for (int i = -100; i < 100; i++) begin
        for (int j = 80; j < 100; j++) begin
            if ($feof(cmp_file)) begin
                $display("@ %0t: ERROR: File %s is shorter than expected.", $time, FILE_CMP_NAME);
                $fclose(out_file);
                $fclose(cmp_file);
                $finish;
            end
            r = $fscanf(cmp_file, "%d", cmp_val);
            // $fwrite(cmp_out_file, "%0d\n", cmp_val);
            if (cmp_val != accum_buff_out[i][j]) begin
                out_errors += 1;
                $write("@ %0t: ERROR: %0d != %0d at index %0d.\n", $time, accum_buff_out[i][j], cmp_val, (i*RHO_RANGE)+j);
            end
        end
    end

    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    // $fclose(cmp_out_file);
    out_read_done = 1'b1;
end

// initial begin : img_write_process
//     int i, r;
//     int out_file;
//     int cmp_file;
//     logic [23:0] cmp_dout;
//     logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

//     @(negedge reset);
//     @(negedge clock);

//     $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
//     out_file = $fopen(IMG_OUT_NAME, "wb");
//     cmp_file = $fopen(IMG_CMP_NAME, "rb");
//     out_rd_en = 1'b0;
    
//     // Copy the BMP header
//     r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
//     for (i = 0; i < BMP_HEADER_SIZE; i++) begin
//         $fwrite(out_file, "%c", bmp_header[i]);
//     end

//     i = 0;
//     while (i < BMP_DATA_SIZE) begin
//         @(negedge clock);
//         out_rd_en = 1'b0;
//         if (out_empty == 1'b0) begin
//             r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
//             $fwrite(out_file, "%c%c%c", out_dout, out_dout, out_dout);

//             if (cmp_dout != {3{out_dout}}) begin
//                 out_errors += 1;
//                 // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, {3{out_dout}}, cmp_dout, i);
//             end
//             out_rd_en = 1'b1;
//             i += BYTES_PER_PIXEL;
//         end
//     end

//     @(negedge clock);
//     out_rd_en = 1'b0;
//     $fclose(out_file);
//     $fclose(cmp_file);
//     out_read_done = 1'b1;
// end

endmodule
