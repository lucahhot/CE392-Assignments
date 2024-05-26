// This module is the Avalon MM Master to connect the to VIP Mixer's slave interface.
// Since we want to hardcode the presetts, this module will write the necessary data to the mixer registers and 
// then just sit during the entire time the program is up and running. 

module mixer_avalon_master (
    // clk and reset are always required.
    input   logic         clk,
    input   logic         reset,
    // These are the Avalon MM Master ports that will connect to the Mixer Avalon MM Slave ports.
    output  logic         avm_m0_read,
    output  logic         avm_m0_write,
    output  logic [31:0]  avm_m0_writedata,
    output  logic [31:0]  avm_m0_address, // Default address width is 32 bits.
    input   logic [31:0]  avm_m0_readdata,
    input   logic         avm_m0_readdatavalid,
    output  logic [3:0]   avm_m0_byteenable, // 4 bits wide since our data width is 32 bits.
    input   logic         avm_m0_waitrequest,
    output  logic [10:0]  avm_m0_burstcount
);

typedef enum logic [3:0] {INIT,STOP,WRITE_X_OFFSET_0,WRITE_Y_OFFSET_0,WRITE_CONTROL_0,
                          WRITE_X_OFFSET_1, WRITE_Y_OFFSET_1, WRITE_CONTROL_1, ENABLE, DONE} state_types;
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
    avm_m0_address = 32'd0;
    avm_m0_read = 1'b0;
    avm_m0_write = 1'b0;
    avm_m0_byteenable = 32'd0;
    avm_m0_burstcount = 11'd0;

    case(cur_state)

        // Init state, we go straight into STOP 
        INIT: begin
            next_state = STOP;
        end

        STOP: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = STOP; // Wait here.
                avm_m0_address = 32'h0000_0000; // Address = 0
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Stop the Mixer
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_X_OFFSET_0;
            end
        end

        WRITE_X_OFFSET_0: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_X_OFFSET_0; // Wait here.
                avm_m0_address = 32'h0000_0008; // Address = 8
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Set the X Offset to 0
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_Y_OFFSET_0;
            end
        end

        WRITE_Y_OFFSET_0: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_Y_OFFSET_0; // Wait here.
                avm_m0_address = 32'h0000_0009; // Address = 9
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Set the Y Offset to 0
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_CONTROL_0;
            end
        end

        WRITE_CONTROL_0: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_CONTROL_0; // Wait here.
                avm_m0_address = 32'h0000_000A; // Address = A
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Enable the Mixer
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_X_OFFSET_1;
            end
        end

        WRITE_X_OFFSET_1: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_X_OFFSET_1; // Wait here.
                avm_m0_address = 32'h0000_000D; // Address = D
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Set the X Offset to 0
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_Y_OFFSET_1;
            end
        end

        WRITE_Y_OFFSET_1: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_Y_OFFSET_1; // Wait here.
                avm_m0_address = 32'h0000_000E; // Address = E
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0000; // Set the Y Offset to 0
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = WRITE_CONTROL_1;
            end
        end

        WRITE_CONTROL_1: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = WRITE_CONTROL_1; // Wait here.
                avm_m0_address = 32'h0000_000F; // Address = F
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Enable the Mixer
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = ENABLE;
            end
        end

        ENABLE: begin
            // We need to set our write signals here and keep them until the waitrequest signal is de-asserted.
            if (avm_m0_waitrequest) begin
                next_state = ENABLE; // Wait here.
                avm_m0_address = 32'h0000_0000; // Address = 0
                avm_m0_write = 1'b1;
                avm_m0_writedata = 32'h0000_0001; // Enable the Mixer
                avm_m0_byteenable = 32'h0000_000F; // Set the byte enable to 32 bits.
                avm_m0_burstcount = 11'd1; // Set the burst count to 1.
            end 
            // We don't need to wait for anything else after waitrequest is de-asserted so we can go to the next state
            else begin
                next_state = DONE;
            end
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