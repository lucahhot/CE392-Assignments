module div #(
    parameter DIVIDEND_WIDTH = 32,
    parameter DIVISOR_WIDTH = 32,
    parameter DATA_SIZE = 32
) (
    input  logic                        clk,
    input  logic                        reset,
    input  logic                        valid_in,
    input  logic [DIVIDEND_WIDTH-1:0]   dividend,
    input  logic [DIVISOR_WIDTH-1:0]    divisor,
    output logic [DIVIDEND_WIDTH-1:0]   quotient,
    output logic [DIVISOR_WIDTH-1:0]    remainder,
    output logic                        valid_out,
    output logic                        overflow
);

    // Define the state machine states
    typedef enum logic [2:0] {
        INIT, B_EQ_1, GET_MSB, LOOP, LOOP2,  EPILOGUE, DONE
    } state_t;
    state_t state, next_state;

    // Define internal signals
    logic signed [DIVIDEND_WIDTH-1:0] a, a_c;
    logic signed [DIVISOR_WIDTH-1:0] b, b_c;
    logic signed [DIVIDEND_WIDTH-1:0] q, q_c;
    logic signed [DATA_SIZE-1:0] p, p_c, p_temp;
    logic internal_sign;

    logic signed [DIVIDEND_WIDTH-1:0] dividend_temp, dividend_temp_c;
    logic signed [DIVISOR_WIDTH-1:0] divisor_temp, divisor_temp_c;

    // Registered values for msb(a) and msb_b
    logic [$clog2(DATA_SIZE)-1:0] msb_a, msb_a_c;
    logic [$clog2(DATA_SIZE)-1:0] msb_b, msb_b_c;

    logic signed [DATA_SIZE-1:0] remainder_condition;

    // State machine and calculation logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset == 1'b1) begin
            state <= INIT;
            a <= '0;
            b <= '0;
            q <= '0;
            msb_a <= '0;
            msb_b <= '0;
            p <= '0;
            dividend_temp <= '0;
            divisor_temp <= '0;
        end else begin
            state <= next_state;
            a <= a_c;
            b <= b_c;
            q <= q_c;
            msb_a <= msb_a_c;
            msb_b <= msb_b_c;
            p <= p_c;
            dividend_temp <= dividend_temp_c;
            divisor_temp <= divisor_temp_c;
        end
    end

    // Calculate the most significant bit position of a non-negative number
    // function automatic int get_msb_pos(logic [DIVIDEND_WIDTH-1:0] num);
    //     int pos;
    //     for (pos = DIVIDEND_WIDTH-1; pos >= 0; pos--) begin
    //         if (num[pos] == 1'b1) begin
    //             return pos;
    //         end
    //     end
    //     return -1; // Return -1 if the number is zero
    // endfunction

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
        valid_out = '0;
        msb_a_c = msb_a;
        msb_b_c = msb_b;
        p_c = p;
        quotient = '0;
        remainder = '0;
        valid_out = 1'b0;
        overflow =  1'b0;
        dividend_temp_c = dividend_temp;
        divisor_temp_c = divisor_temp;

        case (state)

            INIT: begin
                // Only assign stuff is valid_in is high
                if (valid_in == 1'b1) begin
                    overflow = 1'b0;
                    a_c = (dividend[DIVIDEND_WIDTH-1] == 1'b0) ? dividend : -dividend;
                    b_c = (divisor[DIVISOR_WIDTH-1] == 1'b0) ? divisor : -divisor;
                    q_c = '0;
                    p_c = '0;
                    
                    // Set temp dividend and divisor registers
                    dividend_temp_c = dividend;
                    divisor_temp_c = divisor;

                    if (divisor == 1) begin
                        next_state = B_EQ_1;
                    end else if (divisor == 0) begin
                        overflow = 1'b1;
                        next_state = B_EQ_1;
                    end else begin
                        next_state = GET_MSB;
                    end
                    // Else stay in this state to wait for valid_in signal to be high
                end else 
                    next_state = INIT;
            end

            B_EQ_1: begin
                q_c = dividend;
                a_c = '0;
                b_c = b;
                next_state = EPILOGUE;
            end

            // State dedicated to calculating MSBs because it's slow 
            GET_MSB: begin
                msb_a_c = get_msb_pos(a,(DIVIDEND_WIDTH-1));
                msb_b_c = get_msb_pos(b,(DIVISOR_WIDTH-1));
                // msb_a_c = get_msb_pos(a);
                // msb_b_c = get_msb_pos(b);
                next_state = LOOP;
            end

            LOOP: begin

                p_temp = msb_a - msb_b;

                p_c = ((b << p_temp) > a) ? p_temp - 1 : p_temp;
                
                next_state = LOOP2;
            end

            LOOP2: begin

                q_c = q + (1 << p);

                if ((b != '0) && (b <= a)) begin
                    a_c = a - (b << p);
                    next_state = GET_MSB;
                end else begin
                    next_state = EPILOGUE;
                end

            end

            EPILOGUE: begin
                internal_sign = dividend_temp[DIVIDEND_WIDTH-1] ^ divisor_temp[DIVISOR_WIDTH-1];
                quotient = (internal_sign == 1'b0) ? q : -q;
                remainder_condition = dividend_temp[DIVIDEND_WIDTH-1];
                remainder = (remainder_condition == 1'b0) ? a : -a;
                valid_out = 1'b1;
                next_state = INIT;
            end

            default: begin
                quotient = '0;
                remainder = '0;
                valid_out = 1'b0;
                overflow  = 1'b0;
                next_state = INIT;
                a_c = 'X;
                b_c = 'X;
                q_c = 'X;
                msb_a_c = 'X;
                msb_b_c = 'X;
                p_c = 'X;
                dividend_temp_c = 'X;
                divisor_temp_c = 'X;
            end

        endcase
    end

endmodule