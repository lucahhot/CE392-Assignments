`timescale 1 ns / 1 ns

module motion_detect_tb;

localparam string IMG_BASE_NAME = "../source/base.bmp";
localparam string IMG_IN_NAME  = "../source/pedestrians.bmp";
localparam string IMG_OUT_NAME = "../source/output.bmp";
localparam string IMG_CMP_NAME = "../source/img_out.bmp";
localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

logic           base_full;
logic           base_wr_en = '0;
logic [23:0]    base_din = '0;
logic           img_in_full;
logic           img_in_wr_en = '0;
logic [23:0]    img_in_din = '0;
logic           original_full;
logic           original_wr_en = '0;
logic [23:0]    original_din = '0;
logic           img_out_rd_en;
logic           img_out_empty;
logic [23:0]    img_out_dout;

logic   hold_clock    = '0;
logic   img_in_write_done = '0;
logic   base_write_done = '0;
logic   original_write_done = '0;
logic   img_out_read_done = '0;
integer out_errors    = '0;

localparam WIDTH = 768;
localparam HEIGHT = 576;
localparam FIFO_BUFFER_SIZE = 8; // Change this 
localparam BMP_HEADER_SIZE = 54;
localparam BYTES_PER_PIXEL = 3;
localparam BMP_DATA_SIZE = WIDTH*HEIGHT*BYTES_PER_PIXEL;

motion_detect_top #(
    .WIDTH(WIDTH),
    .HEIGHT(HEIGHT),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) motion_detect_top_inst (
    .clock(clock),
    .reset(reset),
    .base_full(base_full),
    .base_wr_en(base_wr_en),
    .base_din(base_din),
    .img_in_full(img_in_full),
    .img_in_wr_en(img_in_wr_en),
    .img_in_din(img_in_din),
    .original_full(original_full),
    .original_wr_en(original_wr_en),
    .original_din(original_din),
    .img_out_empty(img_out_empty),
    .img_out_rd_en(img_out_rd_en),
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

    wait(img_out_read_done);
    end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    $display("Total error count: %0d", out_errors);

    // end the simulation
    $finish;
end

initial begin : img_in_read_process
    int i, r;
    int in_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];
    logic [23:0] file_value;


    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_IN_NAME);

    in_file = $fopen(IMG_IN_NAME, "rb");
    img_in_wr_en = 1'b0;
    original_wr_en = 1'b0;

    // Skip BMP header
    r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

    // Read data from image file
    i = 0;
    while ( i < BMP_DATA_SIZE ) begin
        @(negedge clock);
        img_in_wr_en = 1'b0;
        original_wr_en = 1'b0;
        if (img_in_full == 1'b0  && original_full == 1'b0) begin
            r = $fread(file_value, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            img_in_din = file_value;
            original_din = file_value;
            img_in_wr_en = 1'b1;
            original_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    img_in_wr_en = 1'b0;
    original_wr_en = 1'b0;
    $fclose(in_file);
    img_in_write_done = 1'b1;
    original_write_done = 1'b1;
end

initial begin : base_read_process
    int i, r;
    int in_file;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    $display("@ %0t: Loading file %s...", $time, IMG_BASE_NAME);

    in_file = $fopen(IMG_BASE_NAME, "rb");
    base_wr_en = 1'b0;

    // Skip BMP header
    r = $fread(bmp_header, in_file, 0, BMP_HEADER_SIZE);

    // Read data from image file
    i = 0;
    while ( i < BMP_DATA_SIZE ) begin
        @(negedge clock);
        base_wr_en = 1'b0;
        if (base_full == 1'b0) begin
            r = $fread(base_din, in_file, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);
            base_wr_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    base_wr_en = 1'b0;
    $fclose(in_file);
    base_write_done = 1'b1;
    
end

initial begin : img_write_process
    int i, r;
    int out_file;
    int cmp_file;
    logic [23:0] cmp_dout;
    logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

    @(negedge reset);
    @(negedge clock);

    $display("@ %0t: Comparing file %s...", $time, IMG_OUT_NAME);
    
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
            $fwrite(out_file, "%c%c%c", img_out_dout[23:16], img_out_dout[15:8] ,img_out_dout[7:0]);

            if (cmp_dout != img_out_dout) begin
                out_errors += 1;
                // $write("@ %0t: %s(%0d): ERROR: %x != %x at address 0x%x.\n", $time, IMG_OUT_NAME, i+1, img_out_dout, cmp_dout, i);
            end
            img_out_rd_en = 1'b1;
            i += BYTES_PER_PIXEL;
        end
    end

    @(negedge clock);
    img_out_rd_en = 1'b0;
    $fclose(out_file);
    $fclose(cmp_file);
    img_out_read_done = 1'b1;
end

endmodule