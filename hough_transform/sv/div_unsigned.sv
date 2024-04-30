// Adapted for UNSIGNED division for the Canny Edge Detection project (gaussian_blur module)

module div_unsigned #(
    parameter DIVIDEND_WIDTH = 16,
    parameter DIVISOR_WIDTH = 8
) (
    input  logic                        clk,
    input  logic                        reset,
    input  logic                        valid_in,
    input  logic [DIVIDEND_WIDTH-1:0]   dividend,
    input  logic [DIVISOR_WIDTH-1:0]    divisor,
    output logic [DIVIDEND_WIDTH-1:0]   quotient,
    // output logic [DIVISOR_WIDTH-1:0]    remainder,
    output logic                        valid_out
    // output logic                        overflow
);

    // Define the state machine states
    typedef enum logic [2:0] {INIT, B_EQ_1, LOOP} state_t;
    state_t state, next_state;

    // Define internal signals
    logic [DIVIDEND_WIDTH-1:0] a, a_c;
    logic [DIVISOR_WIDTH-1:0] b, b_c;
    logic [DIVIDEND_WIDTH-1:0] q, q_c;
    logic [DIVIDEND_WIDTH-1:0] p;

    logic [DIVIDEND_WIDTH-1:0] dividend_temp, dividend_temp_c;
    logic [DIVISOR_WIDTH-1:0] divisor_temp, divisor_temp_c;

    // Wires for msb_a and msb_b
    logic [$clog2(DIVIDEND_WIDTH)-1:0] msb_a;
    logic [$clog2(DIVIDEND_WIDTH)-1:0] msb_b;

    // State machine and calculation logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            state <= INIT;
            a <= '0;
            b <= '0;
            q <= '0;
            dividend_temp <= '0;
            divisor_temp <= '0;
        end else begin
            state <= next_state;
            a <= a_c;
            b <= b_c;
            q <= q_c;
            dividend_temp <= dividend_temp_c;
            divisor_temp <= divisor_temp_c;
        end
    end

    // Recursive get_msb
    function automatic logic [$clog2(DIVIDEND_WIDTH)-1:0] get_msb_pos(logic [DIVIDEND_WIDTH-1:0] input_vector, logic [$clog2(DIVIDEND_WIDTH)-1:0] index);
    
        logic [$clog2(DIVIDEND_WIDTH)-1:0] left_result;
        logic [$clog2(DIVIDEND_WIDTH)-1:0] right_result;

        if (input_vector[index] == 1'b1) 
            return index;
        else if (index == 1'b0) 
            return '0;
        else begin

            left_result = get_msb_pos(input_vector, index - 1);
            right_result = get_msb_pos(input_vector, (index - 1) / 2);

            if (left_result >= '0) 
                return left_result;
            else if (right_result >= '0)  
                return right_result;
            else 
                return '0;

        end
    endfunction

    always_comb begin
        next_state = state;
        a_c = a;
        b_c = b;
        q_c = q;
        quotient = '0;
        // remainder = '0;
        valid_out = 1'b0;
        // overflow =  1'b0;
        dividend_temp_c = dividend_temp;
        divisor_temp_c = divisor_temp;

        case (state)

            INIT: begin
                // Only assign stuff is valid_in is high
                if (valid_in == 1'b1) begin
                    // overflow = 1'b0;
                    a_c = dividend;
                    b_c = divisor;
                    q_c = '0;
                    
                    // Set temp dividend and divisor registers
                    dividend_temp_c = dividend;
                    divisor_temp_c = divisor;

                    if (divisor == 1) begin
                        next_state = B_EQ_1;
                    end else if (divisor == 0) begin
                        // overflow = 1'b1;
                        next_state = B_EQ_1;
                    end else begin
                        next_state = LOOP;
                    end
                    // Else stay in this state to wait for valid_in signal to be high
                end else 
                    next_state = INIT;
            end

            B_EQ_1: begin
                q_c = dividend_temp;
                quotient = dividend_temp;
                valid_out = 1'b1;
                next_state = INIT;
            end

            LOOP: begin

                msb_a = get_msb_pos(a,(DIVIDEND_WIDTH-1));
                msb_b = get_msb_pos(b,(DIVISOR_WIDTH-1));

                p = msb_a - msb_b;

                p = ((b << p) > a) ? p - 1 : p;
                
                q_c = q + (1 << p);

                if ((b != '0) && (b <= a)) begin
                    a_c = a - (b << p);
                    next_state = LOOP;
                end else begin
                    // next_state = EPILOGUE;
                    quotient = q_c;
                    // remainder = a_c;
                    valid_out = 1'b1;
                    next_state = INIT;
                end
            end
            
            default: begin
                next_state = INIT;
                a_c = 'X;
                b_c = 'X;
                q_c = 'X;
                valid_out = 1'b0;
                quotient = 'X;
                divisor_temp_c = 'X;
                dividend_temp_c = 'X;
            end

        endcase
    end

endmodule