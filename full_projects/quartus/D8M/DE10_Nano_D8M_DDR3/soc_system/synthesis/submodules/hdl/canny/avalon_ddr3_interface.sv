// I changed all the data bit widths from 256 bits to 32 bits
// The code given by the repo only provdies the read functionality so I will try and also add
// write functionality to the code.

module avalon_ddr3_interface (
    // clk and reset are always required.
    input   logic         clk,
    input   logic         reset,
    // mem clock and reset
    // input   logic         mem_clk,
    // input   logic         mem_reset,
    // Bidirectional ports i.e. read and write.
    output  logic         avm_m0_read,
    output  logic         avm_m0_write,
    output  logic [127:0] avm_m0_writedata,
    output  logic [31:0]  avm_m0_address, // Default address width is 32 bits.
    input   logic [127:0] avm_m0_readdata,
    input   logic         avm_m0_readdatavalid,
    output  logic [15:0]  avm_m0_byteenable, // 16 bits
    input   logic         avm_m0_waitrequest,
    output  logic [6:0]   avm_m0_burstcount, // VFB has 7 bit wide burst count

    // External ports to module that is reading/writing to SDRAM
    input   logic [31:0]  sdram_address, // This is the address to be used for read/writes
    // Ports for reading
    input   logic         rd_en,
    output  logic [127:0] read_data, 
    // Ports for writing
    input   logic         wr_en,
    input   logic [127:0] write_data_input, // Will clock this input
    // Signal ports to indicate read/write completion to the top-level
    output  logic         write_complete,
    output  logic         read_complete
);

typedef enum logic [2:0] {INIT,READ_START,READ_END,WRITE_START} state_types;
state_types cur_state, next_state;

// Clocked versions of inputs so the top-module doesn't have to constantly assert them
logic [127:0] write_data_registered, write_data_registered_c;
logic [31:0] sdram_address_registered, sdram_address_registered_c;

always_ff @(posedge clk) begin
    if (reset) begin
        cur_state <= INIT;
        write_data_registered <= 128'd0;
        sdram_address_registered <= 32'd0;
    end
    else begin
        cur_state <= next_state;
        write_data_registered <= write_data_registered_c;
        sdram_address_registered <= sdram_address_registered_c;

        // // Update the read data output on the clock edge instead of combinationally in always_comb
        // case (cur_state)
        //     READ_END: begin
        //         if (avm_m0_readdatavalid) 
        //         read_data <= avm_m0_readdata;
        //     end
        // endcase

    end
end

// Combinational block to change FSM states depending on the control signals
always_comb begin
    next_state = cur_state;
    write_complete = 1'b0;
    read_complete = 1'b0;
    read_data = 128'd255; // Default white (idk)

    // Default avalon signal assignments
    avm_m0_writedata = 128'd0;
    avm_m0_address = 32'd0;
    avm_m0_read = 1'b0;
    avm_m0_write = 1'b0;
    avm_m0_byteenable = 32'd0;
    avm_m0_burstcount = 7'd0;

    write_data_registered_c = '0;
    sdram_address_registered_c = '0;

    case(cur_state)

        // Initial state where we either do nothing and wait, or start reading/writing
        // This will be determined by which enable signal is high, if both are high, then 
        // we'll just prioritize the write command. 
        INIT: begin
            // Priority the write command by checking wr_en first.
            if (wr_en) begin
                next_state = WRITE_START;
                // Register the write data and address to be used in the WRITE_START state.
                write_data_registered_c = write_data_input;
                sdram_address_registered_c = sdram_address;
            end
            // If not write command, then check for read command.
            else if (rd_en) begin
                next_state = READ_START;
                // Register the address to be used in the READ_START state.
                sdram_address_registered_c = sdram_address;
            end
            // If no command, then just stay in the INIT state.
            else next_state = INIT;
        end

        // Wait for the waitrequest signal to be de-asserted
        WRITE_START: begin
            avm_m0_address = sdram_address_registered; // Set avm address to the input address
            avm_m0_write = 1'b1;
            avm_m0_writedata = write_data_registered; // Set the write data to the input data
            avm_m0_byteenable = 32'h0000_FFFF; // Set the byte enable to 32 bits.
            avm_m0_burstcount = 7'd1; // Set the burst count to 1.
            // Change state if waitrequest is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_START; // Wait here.
            end else begin
                next_state = INIT;
                // Assert write_complete signal to tell the top-level that we have finished writing.
                write_complete = 1'b1;
            end
        end

        // Wait for the waitrequest signal to be de-asserted
        READ_START: begin
            avm_m0_address = sdram_address_registered; // Set avm address to the input address
            avm_m0_read = 1'b1;
            avm_m0_burstcount = 7'd1; // Get only 1 address value.
            if (avm_m0_waitrequest) begin
                next_state = READ_START; // Wait here.
            end else next_state = READ_END;
        end

        READ_END: begin
            if (!avm_m0_readdatavalid) next_state = READ_END; // Wait here.
            // If readdatavalid is high (meaning read data is available), then we can move to the next state,
            // the data will be clocked into the output port on the next positive clock edge
            else begin
                next_state = INIT;
                // Assert read_complete signal to tell the top-level that we have finished reading.
                read_complete = 1'b1;
                // Assign read_data
                // read_data = avm_m0_readdata;
                // Hardcoding this to see if at least this logic is working 
                read_data = 128'd255;
            end
        end

        default: begin
            next_state = INIT;
        end

    endcase
end

endmodule