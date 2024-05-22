// I changed all the data bit widths from 256 bits to 32 bits
// The code given by the repo only provdies the read functionality so I will try and also add
// write functionality to the code.

module avalon_sdr (
    // clk and reset are always required.
    input   logic         clk,
    input   logic         reset,
    // Bidirectional ports i.e. read and write.
    output  logic         avm_m0_read,
    output  logic         avm_m0_write,
    output  logic [31:0]  avm_m0_writedata,
    output  logic [31:0]  avm_m0_address, // Default address width is 32 bits.
    input   logic [31:0]  avm_m0_readdata,
    input   logic         avm_m0_readdatavalid,
    output  logic [3:0]   avm_m0_byteenable, // 4 bits wide since our data width is 32 bits.
    input   logic         avm_m0_waitrequest,
    output  logic [10:0]  avm_m0_burstcount,

    // External ports to module that is reading/writing to SDRAM
    input   logic [31:0]  sdram_address, // This is the address to be used for read/writes
    // Ports for reading
    input   logic         rd_en,
    output  logic [31:0]  read_data, 
    // Ports for writing
    input   logic         wr_en,
    input   logic [31:0]  write_data_input, // Will clock this input
    // Signal ports to indicate read/write completion to the top-level
    output  logic         write_complete,
    output  logic         read_complete
);

typedef enum logic [2:0] {INIT,READ_START,READ_END,WRITE_START} state_types;
state_types cur_state, next_state;

logic [31:0] write_data; // Clocked version of write_data_input in case it changes mid-clock cycle or something

always_ff @(posedge clk) begin
    if (reset) begin
        cur_state <= INIT;
        read_data <= 32'd0;
        write_data <= 32'd0;
    end
    else begin
        cur_state <= next_state;
        // Clock the write data input
        write_data <= write_data_input;

        // Update the read data output on the clock edge instead of combinationally in always_comb
        case (cur_state)
            READ_END: begin
                if (avm_m0_readdatavalid) 
                read_data <= avm_m0_readdata;
            end
        endcase

    end
end

// Combinational block to change FSM states depending on the control signals
always_comb begin
    next_state = cur_state;
    write_complete = 1'b0;
    read_complete = 1'b0;

    // Default avalon signal assignments
    avm_m0_writedata = 32'd0;
    avm_m0_address = 32'd0;
    avm_m0_read = 1'b0;
    avm_m0_write = 1'b0;
    avm_m0_byteenable = 32'd0;
    avm_m0_burstcount = 11'd0;

    case(cur_state)

        // Initial state where we either do nothing and wait, or start reading/writing
        // This will be determined by which enable signal is high, if both are high, then 
        // we'll just prioritize the write command. 
        INIT: begin
            // Priority the write command by checking wr_en first.
            if (wr_en) next_state = WRITE_START;
            // If not write command, then check for read command.
            else if (rd_en) next_state = READ_START;
            // If no command, then just stay in the INIT state.
            else next_state = INIT;
        end

        // Wait for the waitrequest signal to be de-asserted
        WRITE_START: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_START; // Wait here.
                avm_m0_address = sdram_address; // Set avm address to the input address
                avm_m0_write = 1'b1;
                avm_m0_writedata = write_data; // Set the write data to the input data
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go back to 
            // the INIT state since avalon only takes 1 cycle after to complete the write.
            else begin
                next_state = INIT;
                // Assert write_complete signal to tell the top-level that we have finished writing.
                write_complete = 1'b1;
            end
        end

        // Wait for the waitrequest signal to be de-asserted
        READ_START: begin
            if (avm_m0_waitrequest) begin
                next_state = READ_START; // Wait here.
                avm_m0_address = sdram_address; // Set avm address to the input address
                avm_m0_read = 1'b1;
                avm_m0_byteenable = 32'h0000_000F; // Get 32 bits only.
                avm_m0_burstcount = 11'd1; // Get only 1 address value.
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
            end
        end

        default: begin
            next_state = INIT;
        end

    endcase
end

endmodule