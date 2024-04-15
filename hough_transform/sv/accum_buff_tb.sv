`timescale 1ns/1ns

module accum_buff_tb;

`include "globals.sv" 

logic clock, reset;
logic theta_in_full, x_in_full, y_in_full, in_wr_en;
logic [15:0] theta_din, data_in_x, data_in_y;
logic row_out_empty, row_out_rd_en;
logic [15:0] row_out;

logic out_rd_done, in_write_done;


accum_buff_top #(
    .THETAS(THETAS),
    .RHO_RESOLUTION(RHO_RESOLUTION),
    .RHOS(RHOS),
    .IMG_BITS(IMG_BITS),
    .THETA_BITS(THETA_BITS),
    .CORDIC_DATA_WIDTH(CORDIC_DATA_WIDTH),
    .BITS(BITS),
    .FIFO_BUFFER_SIZE(FIFO_BUFFER_SIZE)
) accum_buff_inst (
    .clock(clock),
    .reset(reset),
    .theta_in_full(theta_in_full),
    .x_in_full(x_in_full),
    .y_in_full(y_in_full),
    .in_wr_en(in_wr_en),
    .theta_din(theta_din),
    .data_in_x(data_in_x),
    .data_in_y(data_in_y),
    .row_out_empty(row_out_empty),
    .row_out_rd_en(row_out_rd_en),
    .row_out(row_out)
);

always begin
    clock = 1'b0;
    #(CLOCK_PERIOD/2);
    clock = 1'b1;
    #(CLOCK_PERIOD/2);
end

/* reset */
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
    
    out_rd_done = 1'b0;
    in_write_done = 1'b0;
    row_out_rd_en = 1'b0;

    // start
    $display("@ %0t: Beginning simulation...", start_time);
    @(posedge clock);

    wait(out_rd_done && in_write_done);
    end_time = $time;

    // report metrics
    $display("@ %0t: Simulation completed.", end_time);
    $display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
    // $display("Total error count: %0d", out_errors);

    // end the simulation
    $finish;
end

initial begin : write_data
    shortint i;

    i = 0;

    while (i < THETAS) begin
        @(negedge clock);
        if (theta_in_full == 1'b0 && x_in_full == 1'b0 && y_in_full == 1'b0) begin
            in_wr_en = 1'b1;
            data_in_x = X_START;
            data_in_y = Y_START;
            theta_din = i;
            i++;
        end
    end

    in_write_done = 1'b1;
end

initial begin : read_data
    int j;
    j = 0;

    while (j < THETAS) begin
        @(negedge clock);
        if (row_out_empty == 1'b0) begin
            row_out_rd_en = 1'b1;
            $display("@ %0t: (%0d): %x", $time, j, row_out);
            j++;
        end
    end

    out_rd_done = 1'b1;
end



endmodule