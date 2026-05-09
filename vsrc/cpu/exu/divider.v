// ============================================================================
// Radix-2 Non-Restoring Divider 鈥?32 cycles
// Supports: DIV (func3=100), DIVU (101), REM (110), REMU (111)
//
// Modular Architecture:
// 1. Pre-processor: Sign extraction & special case detection
// 2. Iterator: Non-restoring next partial remainder and quotient calculation
// 3. Post-processor: Remainder correction & sign application
// ============================================================================

// ----------------------------------------------------------------------------
// Submodule 1: Pre-processing Stage
// Extracts signs, absolute values, and identifies special cases (e.g. div-by-0)
// ----------------------------------------------------------------------------
module hcpu_divider_pre (
    input  [31:0] src1,
    input  [31:0] src2,
    input  [1:0]  div_op,
    output        dividend_sign,
    output        divisor_sign,
    output [31:0] abs_dividend,
    output [31:0] abs_divisor,
    output        is_special,
    output [31:0] special_q,
    output [31:0] special_r
);
    wire is_signed = ~div_op[0];
    assign dividend_sign = is_signed & src1[31];
    assign divisor_sign  = is_signed & src2[31];

    assign abs_dividend = dividend_sign ? (~src1 + 1'b1) : src1;
    assign abs_divisor  = divisor_sign  ? (~src2 + 1'b1) : src2;

    wire div_by_zero     = (src2 == 32'b0);
    wire signed_overflow = is_signed & (src1 == 32'h80000000) & (src2 == 32'hFFFFFFFF);
    assign is_special    = div_by_zero | signed_overflow;

    assign special_q = div_by_zero     ? 32'hFFFFFFFF :
                       signed_overflow ? 32'h80000000 : 32'b0;
    assign special_r = div_by_zero     ? src1 : 32'b0;
endmodule

// ----------------------------------------------------------------------------
// Submodule 2: Non-Restoring Next Remainder Calculation
// Computes the new partial remainder and next quotient bit
// ----------------------------------------------------------------------------
module hcpu_divider_iter (
    input  [33:0] partial_rem,
    input  [31:0] partial_q,
    input  [33:0] divisor,
    output [33:0] next_rem,
    output [31:0] next_q
);
    wire [33:0] shift_rem = {partial_rem[32:0], partial_q[31]};
    assign next_rem = partial_rem[33] ? (shift_rem + divisor) : (shift_rem - divisor);
    assign next_q   = {partial_q[30:0], ~next_rem[33]};
endmodule

// ----------------------------------------------------------------------------
// Submodule 3: Post-processing Stage
// Reconstructs result, corrects negative remainder, and applies signs
// ----------------------------------------------------------------------------
module hcpu_divider_post (
    input  [31:0] raw_q,         // Final raw quotient
    input  [33:0] raw_rem,       // Final partial remainder
    input  [33:0] divisor,       // Normalized positive divisor
    input         q_neg_req,     // Quotient needs negation
    input         r_neg_req,     // Remainder needs negation
    input  [1:0]  div_op,        // 00=DIV, 01=DIVU, 10=REM, 11=REMU
    input         is_special,    // Was a special case detected?
    input  [31:0] special_q,
    input  [31:0] special_r,
    output [31:0] final_result
);
    // Correct remainder if it ended up negative
    wire [33:0] r_correct_34 = raw_rem[33] ? (raw_rem + divisor) : raw_rem;
    wire [31:0] r_correct    = r_correct_34[31:0];

    // Apply final sign transformations
    wire [31:0] q_signed = q_neg_req ? (~raw_q + 1'b1)    : raw_q;
    wire [31:0] r_signed = r_neg_req ? (~r_correct + 1'b1) : r_correct;

    // Select between Quotient and Remainder based on instruction
    wire return_rem = div_op[1];
    wire [31:0] normal_res  = return_rem ? r_signed  : q_signed;
    wire [31:0] special_res = return_rem ? special_r : special_q;

    // Final output selection
    assign final_result = is_special ? special_res : normal_res;
endmodule

// ============================================================================
// Top Module: Non-Restoring Divider Core
// Connects the FSM, iterative datapath, and modular stages
// ============================================================================
module hcpu_divider (
    input         clock,
    input         reset,
    input  [31:0] src1,          // dividend
    input  [31:0] src2,          // divisor
    input  [1:0]  div_op,        // func3[1:0]
    input         div_valid,     // start signal
    output [31:0] div_result,    // final calculated result
    output        div_done       // completion flag
);

    // ------------------------------------------------------------------------
    // Stage 1: Input Pre-processing
    // ------------------------------------------------------------------------
    wire        dividend_sign, divisor_sign;
    wire [31:0] abs_dividend, abs_divisor;
    wire        is_special;
    wire [31:0] special_q, special_r;

    hcpu_divider_pre u_pre (
        .src1         (src1),
        .src2         (src2),
        .div_op       (div_op),
        .dividend_sign(dividend_sign),
        .divisor_sign (divisor_sign),
        .abs_dividend (abs_dividend),
        .abs_divisor  (abs_divisor),
        .is_special   (is_special),
        .special_q    (special_q),
        .special_r    (special_r)
    );

    // ------------------------------------------------------------------------
    // Stage 2: Control FSM & Datapath Registers
    // ------------------------------------------------------------------------
    localparam S_IDLE = 2'd0;
    localparam S_CALC = 2'd1;
    localparam S_DONE = 2'd2;

    reg [1:0]  state, next_state;
    reg [4:0]  cnt; // 5-bit counter: 0 to 31 (32 cycles)

    // Datapath state registers
    reg [33:0] partial_rem;
    reg [31:0] quotient;
    reg [33:0] divisor_reg;
    reg        q_neg_result, r_neg_result;
    reg [1:0]  op_reg;
    reg        special_case_reg;
    reg [31:0] special_q_reg, special_r_reg;

    // FSM State transitions
    always @(posedge clock or posedge reset) begin
        if (reset) state <= S_IDLE;
        else       state <= next_state;
    end

    // FSM Next-state logic
    always @(*) begin
        case (state)
            S_IDLE: next_state = (div_valid && !is_special) ? S_CALC :
                                 (div_valid &&  is_special) ? S_DONE : S_IDLE;
            S_CALC: next_state = (cnt == 5'd31) ? S_DONE : S_CALC;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Stage 3: Iteration Core (Combinational)
    // ------------------------------------------------------------------------
    wire [33:0] next_partial_rem;
    wire [31:0] next_quotient;

    hcpu_divider_iter u_iter (
        .partial_rem(partial_rem),
        .partial_q  (quotient),
        .divisor    (divisor_reg),
        .next_rem   (next_partial_rem),
        .next_q     (next_quotient)
    );

    // ------------------------------------------------------------------------
    // Stage 4: Register Updates (Sequential)
    // ------------------------------------------------------------------------
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            cnt              <= 5'b0;
            partial_rem      <= 34'b0;
            quotient         <= 32'b0;
            divisor_reg      <= 34'b0;
            q_neg_result     <= 1'b0;
            r_neg_result     <= 1'b0;
            op_reg           <= 2'b0;
            special_case_reg <= 1'b0;
            special_q_reg    <= 32'b0;
            special_r_reg    <= 32'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (div_valid) begin
                        partial_rem      <= 34'b0;
                        quotient         <= abs_dividend;
                        divisor_reg      <= {2'b0, abs_divisor};
                        q_neg_result     <= dividend_sign ^ divisor_sign;
                        r_neg_result     <= dividend_sign;
                        op_reg           <= div_op;
                        cnt              <= 5'b0;
                        special_case_reg <= is_special;
                        special_q_reg    <= special_q;
                        special_r_reg    <= special_r;
                    end
                end
                S_CALC: begin
                    partial_rem <= next_partial_rem;
                    quotient    <= next_quotient;
                    cnt         <= cnt + 1'b1;
                end
                default: ; // Hold registers in S_DONE
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Stage 5: Output Post-processing
    // ------------------------------------------------------------------------
    hcpu_divider_post u_post (
        .raw_q       (quotient),
        .raw_rem     (partial_rem),
        .divisor     (divisor_reg),
        .q_neg_req   (q_neg_result),
        .r_neg_req   (r_neg_result),
        .div_op      (op_reg),
        .is_special  (special_case_reg),
        .special_q   (special_q_reg),
        .special_r   (special_r_reg),
        .final_result(div_result)
    );

    assign div_done = (state == S_DONE);

endmodule
