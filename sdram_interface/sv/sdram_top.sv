// This dummy top level module will just instantiate the avalon_sdr module and trigger some read and 
// write operations to test the module.

module sdram_top (
    input  logic        clock,
    input  logic        reset,

    // Output ports to the SDRAM bridge
    output  logic         avm_m0_read,
    output  logic         avm_m0_write,
    output  logic [31:0]  avm_m0_writedata,
    output  logic [31:0]  avm_m0_address, 
    input   logic [31:0]  avm_m0_readdata,
    input   logic         avm_m0_readdatavalid,
    output  logic [31:0]  avm_m0_byteenable,
    input   logic         avm_m0_waitrequest,
    output  logic [10:0]  avm_m0_burstcount
);

// Wires to connect input/output to the avalon_sdr module
logic [31:0]    sdram_address;
logic           rd_en;
logic [31:0]    read_data;
logic           wr_en;
logic [31:0]    write_data_input;
logic           write_complete;
logic           read_complete;


// Instantiate the avalon_sdr module
avalon_sdr avalon_sdr_inst (
    .clk(clock),
    .reset(reset),
    .avm_m0_read(avm_m0_read),
    .avm_m0_write(avm_m0_write),
    .avm_m0_writedata(avm_m0_writedata),
    .avm_m0_address(avm_m0_address),
    .avm_m0_readdata(avm_m0_readdata),
    .avm_m0_readdatavalid(avm_m0_readdatavalid),
    .avm_m0_byteenable(avm_m0_byteenable),
    .avm_m0_waitrequest(avm_m0_waitrequest),
    .avm_m0_burstcount(avm_m0_burstcount),
    .sdram_address(sdram_address),
    .rd_en(rd_en),
    .read_data(read_data),
    .wr_en(wr_en),
    .write_data_input(write_data_input),
    .write_complete(write_complete),
    .read_complete(read_complete)
);

typedef enum logic [2:0] {WRITE, READ, INCREMENT} state_types;
state_types cur_state, next_state;

logic [31:0] address_counter, address_counter_c;
logic [31:0] write_data, write_data_c;

always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        cur_state <= WRITE;
        address_counter <= 32'd0;
        write_data <= 32'd0;
    end
    else begin
        cur_state <= next_state;
        address_counter <= address_counter_c;
        write_data <= write_data_c;
    end
end

always_comb begin
    next_state = cur_state;
    address_counter_c = address_counter;
    write_data_c = write_data;
    sdram_address = 32'd0;
    rd_en = 1'b0;
    wr_en = 1'b0;
    write_data_input = 32'd0;

    case(curr_state)

        WRITE: begin
            // Set write signals to write to SDRAM
            sdram_address = address_counter;
            wr_en = 1'b1;
            write_data_input = write_data;
            // Wait in this state until write_complete is high (we need this so that we keep these signals constant while waitrequest is high)
            if (write_complete) begin
                next_state = READ;
            end
        end

        READ: begin
            // Set read signals to read from SDRAM
            sdram_address = address_counter;
            rd_en = 1'b1;
            // Wait in this state until read_complete is high (we need this so that we keep these signals constant while waitrequest is high)
            if (read_complete) begin
                next_state = INCREMENT;
            end
        end

        INCREMENT: begin
            // Increment address and write data to simulate writing to different addresses
            address_counter_c = address_counter + 32'd4;
            write_data_c = address_counter;
            next_state = WRITE;
        end

    endcase
end

endmodule