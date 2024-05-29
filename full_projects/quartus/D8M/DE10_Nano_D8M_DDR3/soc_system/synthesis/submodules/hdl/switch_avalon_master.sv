// This module is the Avalon MM Master to connect to the VIP Switch's slave interface.
// Since we want to hardcode the presets, this module will write the necessary data to the switch registers and
// then just sit during the entire time the program is up and running.

// NOTE: We know exactly what signals this switch should have given the generate HDL results in Platform Designer.

module switch_avalon_master (
    // clk and reset are always required.
    input   logic         clk,
    input   logic         reset,
    // These are the Avalon MM Master ports that will connect to the Mixer Avalon MM Slave ports.
    output  logic         avm_m0_read,
    output  logic         avm_m0_write,
    output  logic [31:0]  avm_m0_writedata,
    output  logic [31:0]   avm_m0_address, // Default address width is 32 bits 
    input   logic [31:0]  avm_m0_readdata,
    input   logic         avm_m0_readdatavalid,
    output  logic [3:0]   avm_m0_byteenable, // 4 bits wide since our data width is 32 bits.
    input   logic         avm_m0_waitrequest,
    output  logic [10:0]  avm_m0_burstcount
);

// Refer to page 33 of Session 4 OSD Overlay Lab Manual

typedef enum logic [3:0] {INIT, STOP, WRITE_DOUT0, WRITE_DOUT1, WRITE_SWITCH, ENABLE, DONE} state_types;
state_types cur_state, next_state;

always_ff @(posedge clk) begin
    if (reset) begin
        cur_state <= INIT;
    end
    else begin
        cur_state <= next_state;
    end
end

// Combinational block to change FSM states depending on the control signals
always_comb begin
    next_state = cur_state;

    // Default avalon signal assignments
    avm_m0_writedata = 32'd0;
    avm_m0_address = 5'd0;
    avm_m0_read = 1'b0;
    avm_m0_write = 1'b0;
    avm_m0_byteenable = 32'd0;
    avm_m0_burstcount = 11'd0;

    case(cur_state)

        // Init state, we go straight into STOP 
        INIT: begin
            next_state = STOP;
        end

        // Writing 0 to the Go bit will stop the switch
        STOP: begin
            if (avm_m0_waitrequest) begin
                avm_m0_address = 5'd0; // Address = 0
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Stop the switch
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end else 
                next_state = WRITE_DOUT0;
        end

        // A 1 here means this output is connected to din_0 input stream
        WRITE_DOUT0: begin
            if (avm_m0_waitrequest) begin
                avm_m0_address = 5'd4; // Address = 4
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Set DOUT0 to 1
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end else 
                next_state = WRITE_DOUT1;
        end

        // A 1 here means this output is connected to din_0 input stream
        WRITE_DOUT1: begin
            if (avm_m0_waitrequest) begin
                avm_m0_address = 5'd5; // Address = 5
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Set DOUT1 to 1
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end else
                next_state = WRITE_SWITCH;
        end

        // Writing a 1 to bit 0 indicates that the video output streams must be synchronized; and the new values in the output control registers must be loaded
        // (Need to set last)
        WRITE_SWITCH: begin
            if (avm_m0_waitrequest) begin
                avm_m0_address = 5'd3; // Address = 3
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Set SWITCH to 1
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end else
                next_state = ENABLE;
        end

        ENABLE: begin
            if (avm_m0_waitrequest) begin
                avm_m0_address = 32'h0000_0000; // Address = 0
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Enable the switch
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end else
                next_state = DONE;
        end

        // When we are dont with the Mixer, we just sit here.
        DONE: begin
            next_state = DONE;
        end

        default: begin
            next_state = INIT;
        end

    endcase
end

endmodule