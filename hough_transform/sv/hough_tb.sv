
`timescale 1 ns / 1 ns
`include "globals.sv"

module hough_tb;

localparam string IMG_IN_NAME  = "../images/road_image_1280_720.bmp";
localparam string MASK_IN_NAME = "../images/mask_1280_720.bmp";
localparam string IMG_OUT_NAME = "../images/output.bmp";
localparam string IMG_CMP_NAME = "../images/road_image_1280_720.bmp";
localparam string FILE_OUT_NAME = "../source/accum_buff_rtl_output.txt";
localparam string FILE_CMP_NAME = "../source/accum_buff_results.txt";
localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;
logic [15:0] hough_output;

logic                           image_full;
logic                           image_wr_en  = '0;
logic [23:0]                    image_din    = '0;
logic                           mask_full;
logic                           mask_wr_en   = '0;
logic [23:0]                    mask_din     = '0;
logic                           accum_buff_done;
logic                           hough_done;
logic [0:THETA_UNROLL-1][ACCUM_BUFF_WIDTH-1:0]    output_data;
logic signed [15:0]             left_rho_out;
logic signed [15:0]             right_rho_out;
logic [THETA_BITS-1:0]          left_theta_out;
logic [THETA_BITS-1:0]          right_theta_out;
logic finish_draw_a_line;
logic [$clog2(IMAGE_SIZE)-1:0]  image_bram_rd_addr;
logic [23:0]                    image_bram_rd_data;

logic   hold_clock = '0;
logic   in_write_done = '0;
logic   mask_write_done = '0;
logic   out_read_done = '0;
integer BRAM_out_errors = '0;

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
    .accum_buff_done(accum_buff_done),
    .hough_done(hough_done),
    .output_data(output_data),
    // .left_rho_out(left_rho_out),
    // .right_rho_out(right_rho_out),
    // .left_theta_out(left_theta_out),
    // .right_theta_out(right_theta_out)
    .finish_draw_a_line(finish_draw_a_line),
    .image_bram_rd_addr(image_bram_rd_addr),
    .image_bram_rd_data(image_bram_rd_data)
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
    $display("Total BRAM error count: %0d", BRAM_out_errors);

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
    int out_file, cmp_file, results_file, rho_file;

    @(negedge reset);
    @(negedge clock);

    out_file = $fopen(FILE_OUT_NAME, "w");
    cmp_file = $fopen(FILE_CMP_NAME, "r");
    results_file = $fopen("../source/accum_buff_comparison.txt", "w");
    // rho_file = $fopen("../source/test_values/rho_values.txt", "r");

    // Waiting until the hough transform is done (at least till the accum_buff has been filled out)
    wait(accum_buff_done);
    @(negedge clock); // Need to offset a bit or else we read the last value of the value that should be read (I think this is a simulator problem)

    $display("@ %0t: Comparing file %s...", $time, FILE_OUT_NAME);

    // Write the accum_buff_out to a file
    for (int i = 0; i < RHO_RANGE; i++) begin
        for (int j = 0; j < THETAS; j = j + THETA_UNROLL) begin
            r = $fscanf(cmp_file, "%d", cmp_val);
            $fwrite(out_file, "rho = %0d, theta = %0d, BRAM accum_buff = %0d, Actual accum_buff = %0d\n", i - RHOS, j, output_data[0], cmp_val);
            if (output_data[0] != cmp_val) begin
                BRAM_out_errors += 1;
                $fwrite(results_file, "ERROR: BRAM accum_buff[0]: %0d != %0d at rho = %0d (rho index = %0d), theta = %0d.\n", output_data[0], cmp_val, i-RHOS, i, j);
            end
            r = $fscanf(cmp_file, "%d", cmp_val);
            $fwrite(out_file, "rho = %0d, theta = %0d, BRAM accum_buff = %0d, Actual accum_buff = %0d\n", i - RHOS, j+1, output_data[1], cmp_val);
            if (output_data[1] != cmp_val) begin
                BRAM_out_errors += 1;
                $fwrite(results_file, "ERROR: BRAM accum_buff[1]: %0d != %0d at rho = %0d (rho index = %0d), theta = %0d.\n", output_data[1], cmp_val, i-RHOS, i, j+1);
            end
            r = $fscanf(cmp_file, "%d", cmp_val);
            $fwrite(out_file, "rho = %0d, theta = %0d, BRAM accum_buff = %0d, Actual accum_buff = %0d\n", i - RHOS, j+2, output_data[2], cmp_val);
            if (output_data[2] != cmp_val) begin
                BRAM_out_errors += 1;
                $fwrite(results_file, "ERROR: BRAM accum_buff[1]: %0d != %0d at rho = %0d (rho index = %0d), theta = %0d.\n", output_data[2], cmp_val, i-RHOS, i, j+2);
            end
            r = $fscanf(cmp_file, "%d", cmp_val);
            $fwrite(out_file, "rho = %0d, theta = %0d, BRAM accum_buff = %0d, Actual accum_buff = %0d\n", i - RHOS, j+3, output_data[3], cmp_val);
            if (output_data[3] != cmp_val) begin
                BRAM_out_errors += 1;
                $fwrite(results_file, "ERROR: BRAM accum_buff[1]: %0d != %0d at rho = %0d (rho index = %0d), theta = %0d.\n", output_data[3], cmp_val, i-RHOS, i, j+3);
            end
            @(negedge clock);
        end
        @(negedge clock); // Remember that the RTL theta loop has to go an extra cycle due to the pipeline so we don't want to be reading output during this cycle cuz its wrong
    end

    $fclose(out_file);
    $fclose(cmp_file);
    $fclose(results_file);

    wait(hough_done);
    @(negedge clock);

    if (left_rho_out != -163) begin
        $display("ERROR: Left rho value is not -163, it is %0d.", left_rho_out);
    end
    if (right_rho_out != 575) begin
        $display("ERROR: Right rho value is not 163, it is %0d.", right_rho_out);
    end
    if (left_theta_out != 128) begin
        $display("ERROR: Left theta value is not 0, it is %0d.", left_theta_out);
    end
    if (right_theta_out != 60) begin
        $display("ERROR: Right theta value is not 179, it is %0d.", right_theta_out);
    end

    $display("Left rho = %0d.", left_rho_out);
    $display("Left theta = %0d.", left_theta_out);
    $display("Right rho = %0d.", right_rho_out);
    $display("Right theta = %0d.", right_theta_out);
    
    // $fclose(rho_file);
    out_read_done = 1'b1;
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int cmp_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    @(posedge finish_draw_a_line);

    $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");
    
    // Copy the BMP header
    r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
        $fwrite(out_file, "%c", bmp_header[i]);
    end

    image_bram_rd_addr = 0;
    while (image_bram_rd_addr < IMAGE_SIZE) begin
        @(negedge clock);
            r = $fread(cmp_dout, cmp_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            $fwrite(out_file, "%c%c%c", image_bram_rd_data[23:16], image_bram_rd_data[15:8], image_bram_rd_data[7:0]);

            
            image_bram_rd_addr ++;
    end

    @(negedge clock);
    $fclose(out_file);
    $fclose(cmp_file);
    out_read_done = 1'b1;
end

endmodule
