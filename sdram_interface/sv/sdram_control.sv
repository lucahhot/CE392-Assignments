// Similar to "avalon_control" from the tutorial I was following but this module will instead connec to my avalon_sdr module
// and try to write and read things into the DDR3. In our actual project this module will probably be hough_top itself or the module
// that is sending data to be written to the DDR3 through avalon_sdr.

module sdram_control (
    input logic   clk,
    input logic   reset,
    // This module will not have any input from the ARM SoC as it will be generating its own data to write to the DDR3
    // and reading the data from the DDR3.

    // Output to the avalon_sdr module
    output logic [31:0] sdram_address,
    output logic rd_en,
    output logic wr_en,
    output logic [31:0] write_data_input,

    // Input from the avalon_sdr module
    input logic write_complete,
    input logic read_complete,
    input logic [31:0] read_data
);

typedef enum logic [2:0] {WRITE,READ,READ_END} state_types;
state_types cur_state, next_state;

logic [31:0] stored_read_data;

// Variables to cycle through some addresses and write values 
logic [31:0] address, address_c;
logic [31:0] write_data, write_data_c;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        cur_state <= WRITE;
        address <= 32'd0;
        write_data <= 32'd0;
    end
    else begin
        cur_state <= next_state;
        address <= address_c;
        write_data <= write_data_c;
        stored_read_data <= read_data;
    end
end

always_comb begin
    next_state = cur_state;
    address_c = address;
    write_data_c = write_data;

    // Default output signal assignment
    sdram_address = 32'd0;
    rd_en = 1'b0;
    wr_en = 1'b0;
    write_data_input = 32'd0;

    case(cur_state)

        WRITE: begin
            wr_en = 1'b1;
            write_data_input = write_data;
            sdram_address = address;
            // If the write_complete signal is not high, stay in the write state
            if (write_complete == 1'b1) begin
                next_state = READ;
            end
        end

        READ: begin
            rd_en = 1'b1;
            sdram_address = address;
            // If the read_complete signal is not high, stay in the read state
            if (read_complete == 1'b1) begin
                next_state = READ_END;
            end
        end

        READ_END: begin
            // Increment address and write data
            address_c = address + 32'd4;
            write_data_c = write_data + 32'd1;
            next_state = WRITE;
        end

    endcase
end

endmodule