
`timescale 1 ns / 1 ns

module hough_tb;

// localparam string IMG_IN_NAME  = "/home/laa8390/Documents/CE392/CE392-Assignments/hough_transform/images/stage4_hysteresis.bmp";
localparam string IMG_IN_NAME = "/home/laa8390/Documents/CE392/CE392-Assignments/hough_transform/images/road_image_1280_720.bmp";
localparam string IMG_OUT_NAME = "../images/highlight_output.bmp";
localparam string IMG_CMP_NAME = "/home/laa8390/Documents/CE392/CE392-Assignments/hough_transform/images/stage6_hough.bmp";
localparam CLOCK_PERIOD = 10;

localparam WIDTH = 1280;
localparam HEIGHT = 720;
localparam THETA_BITS = 9;
localparam REDUCED_WIDTH = 568;
localparam REDUCED_HEIGHT = 320;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

int x_read = 0;
int y_read = 0;
int x_write = 0;
int y_write = 0;

logic                           image_full;
logic                           image_wr_en  = '0;
logic [23:0]                    image_din    = '0;
logic [7:0]                     highlight_dout;
logic                           highlight_empty;
logic                           highlight_rd_en = '0;
logic                           hough_done;
logic signed [15:0]             left_rho_out;
logic signed [15:0]             right_rho_out;
logic [THETA_BITS-1:0]          left_theta_out;
logic [THETA_BITS-1:0]          right_theta_out;

logic   hold_clock = '0;
logic   in_write_done = '0;
logic   mask_write_done = '0;
logic   out_read_done = '0;
integer error_count = '0;

localparam BMP_HEADER_SIZE = 138; // According to canny_and_hough.c
localparam BYTES_PER_PIXEL = 3; // According to canny_and_hough.c
localparam BMP_DATA_SIZE = WIDTH*HEIGHT*BYTES_PER_PIXEL;

hough_top hough_top_inst (
    .clock(clock),
    .reset(reset),
    .image_full(image_full),
    .image_wr_en(image_wr_en),
    .image_din(image_din),
    .left_rho_out(left_rho_out),
    .right_rho_out(right_rho_out),
    .left_theta_out(left_theta_out),
    .right_theta_out(right_theta_out),
    .hough_done(hough_done),
    .highlight_dout(highlight_dout),
    .highlight_empty(highlight_empty),
    .highlight_rd_en(highlight_rd_en)
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
    logic [23:0] dummy;

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
        if (x_read >= 0 && x_read < REDUCED_WIDTH && y_read >= 0 && y_read < REDUCED_HEIGHT) begin
            if (image_full == 1'b0) begin
                r = $fread(image_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
                image_wr_en = 1'b1;
                i += BYTES_PER_PIXEL;
                // Update x and y coordinates
                if (x_read == WIDTH-1) begin
                    x_read = 0;
                    y_read += 1;
                end else begin
                    x_read += 1;
                end
            end
        end else begin
            r = $fread(dummy, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            i += BYTES_PER_PIXEL;
            // Update x and y coordinates
            if (x_read == WIDTH-1) begin
                x_read = 0;
                y_read += 1;
            end else begin
                x_read += 1;
            end
        end
    end

    @(negedge clock);
    image_wr_en = 1'b0;
    $fclose(in_file);
    in_write_done = 1'b1;
end

initial begin : img_write_process

    int i, r;
    int out_file, cmp_file, image_output_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    out_file = $fopen(IMG_OUT_NAME, "wb");
    cmp_file = $fopen(IMG_CMP_NAME, "rb");
    highlight_rd_en = 1'b0;

    // Copy the BMP header
    r = $fread(bmp_header, cmp_file, 0, BMP_HEADER_SIZE);
    for (i = 0; i < BMP_HEADER_SIZE; i++) begin
        $fwrite(out_file, "%c", bmp_header[i]);
    end

    // Wait for hough to be done to check lane outputs
    wait(hough_done);
    @(negedge clock);

    if (left_rho_out != -163) begin
        $display("ERROR: Left rho value is not -163, it is %0d.", left_rho_out);
    end
    if (right_rho_out != 575) begin
        $display("ERROR: Right rho value is not 575, it is %0d.", right_rho_out);
    end
    if (left_theta_out != 128) begin
        $display("ERROR: Left theta value is not 128, it is %0d.", left_theta_out);
    end
    if (right_theta_out != 60) begin
        $display("ERROR: Right theta value is not 60, it is %0d.", right_theta_out);
    end

    $display("Left rho = %0d.", left_rho_out);
    $display("Left theta = %0d.", left_theta_out);
    $display("Right rho = %0d.", right_rho_out);
    $display("Right theta = %0d.", right_theta_out);

    // Write output to file
    $display("@ %0t: Writing output to file %s...", $time, IMG_OUT_NAME);

    i = 0;
    while (i < BMP_DATA_SIZE) begin
        @(negedge clock);
        highlight_rd_en = 1'b0;
        // Check x and y coordinates to know if we write the output of highlight or a green pixel
        if (x_write >= 0 && x_write < REDUCED_WIDTH && y_write >= 0 && y_write < REDUCED_HEIGHT) begin
            if (highlight_empty == 1'b0) begin
                $fwrite(out_file, "%c%c%c", 8'h00, 8'h00, highlight_dout);
                highlight_rd_en = 1'b1;
                i += BYTES_PER_PIXEL;
                // Update x and y coordinates
                if (x_write == WIDTH-1) begin
                    x_write = 0;
                    y_write += 1;
                end else begin
                    x_write += 1;
                end
            end 
        end else begin
            // If we are outside the 640 x 360 region, write a green pixel
            $fwrite(out_file, "%c%c%c", 0, 255, 0);
            // Update x and y coordinates
            if (x_write == WIDTH-1) begin
                x_write = 0;
                y_write += 1;
            end else begin
                x_write += 1;
            end
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    highlight_rd_en = 1'b0;
    $fclose(out_file);
    out_read_done = 1'b1;
end

endmodule
