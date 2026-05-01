// ============================================================================
// Booth-2 + Wallace Tree Multiplier — 2-cycle pipeline
// Supports: MUL (func3=000), MULH (001), MULHSU (010), MULHU (011)
//
// Architecture:
//   Cycle 1: Sign-extend operands → Booth-2 encode → generate partial products
//            → Wallace Tree CSA compress 18 values to 2 (combinational)
//   Cycle 2: Pipeline register → 66-bit final CPA → select result
// ============================================================================
module ysyx_23060124_multiplier (
    input                               clock                      ,
    input                               reset                      ,
    input              [  31:0]         src1                       ,
    input              [  31:0]         src2                       ,
    input              [   1:0]         mul_op                     , // func3[1:0]
    input                               mul_valid                  ,
    output             [  31:0]         mul_result                 ,
    output                              mul_done                    
);

// ============================================================================
// Sign handling
//   MUL    (00): signed   × signed    → low 32
//   MULH   (01): signed   × signed    → high 32
//   MULHSU (10): signed   × unsigned  → high 32
//   MULHU  (11): unsigned × unsigned  → high 32
// ============================================================================
// For simplicity and correctness, convert to unsigned multiplication
// and handle sign correction afterwards.

wire src1_neg = (~mul_op[1] | ~mul_op[0]) & src1[31];           // src1 treated as signed for MUL/MULH/MULHSU
wire src2_neg = ~mul_op[1] & ~mul_op[0] & src2[31] | // src2 signed only for MUL/MULH
                ~mul_op[1] &  mul_op[0] & src2[31];   // (same: mul_op[1]==0)

// Simpler: src2_neg = ~mul_op[1] & src2[31]
// But for MULHSU (10), src2 is unsigned, so src2_neg must be 0
wire src2_is_signed = ~mul_op[1]; // MUL(00) and MULH(01): src2 signed

wire [32:0] a_ext = src1_neg ? {1'b1, src1} : {1'b0, src1};  // sign-extend to 33
wire [32:0] b_ext = (src2_is_signed & src2[31]) ? {1'b1, src2} : {1'b0, src2};

// Use Verilog's built-in multiplication on 33-bit signed values
// This is the simplest correct approach for the mathematical core.
// The Wallace Tree is for the CSA compression of partial products.
//
// For a proper Booth+Wallace implementation that synthesizes well for ASIC,
// we use a straightforward approach: generate partial products explicitly,
// compress with CSA tree.

// ============================================================================
// Unsigned absolute values for Booth encoding
// ============================================================================
wire [31:0] abs_a = src1_neg ? (~src1 + 1'b1) : src1;
wire [31:0] abs_b = (src2_is_signed & src2[31]) ? (~src2 + 1'b1) : src2;
wire result_neg = src1_neg ^ (src2_is_signed & src2[31]);

// For MUL (op=00), we need low 32 bits regardless of sign handling
// Low 32 bits of signed product = low 32 bits of unsigned product of absolute values
// (two's complement multiplication property)
// For MULH/MULHSU/MULHU, we need high 32 bits with sign correction

// ============================================================================
// Partial Product Generation using Booth-2 Radix-4
// Multiplier: abs_b (32 bits), padded to 34 bits with a 0 at bottom
// Generates 17 partial products from 33-bit groups
// ============================================================================
wire [33:0] b_pad = {1'b0, abs_b, 1'b0}; // 34 bits: {0, abs_b[31:0], 0}

// Booth-2 encoding: each group is b_pad[2i+2:2i] for i=0..16
// But for i>=16, b_pad bits are 0

// Generate 17 partial products (each up to 33 bits before shift)
wire [65:0] pp [16:0];

genvar gi;
generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : booth_ppgen
    // Extract 3-bit booth group
    wire [2:0] grp;
    if (gi < 16) begin : normal
      assign grp = b_pad[2*gi+2 -: 3]; // b_pad[2i+2:2i]
    end else begin : last
      assign grp = {1'b0, b_pad[33:32]}; // top group may be partial
    end

    // Decode booth digit
    wire neg = grp[2];
    wire one = grp[0] ^ grp[1];
    wire two = (grp[2] & ~grp[1] & ~grp[0]) | (~grp[2] & grp[1] & grp[0]);

    // Partial product = (one ? abs_a : 0) | (two ? abs_a<<1 : 0), then negate if neg
    wire [32:0] pp_raw;
    assign pp_raw = two ? {abs_a, 1'b0} :
                    one ? {1'b0, abs_a}  :
                    33'b0;

    wire [32:0] pp_val = neg ? (~pp_raw) : pp_raw;

    // Use one-bit sign extension prevention trick:
    //   Instead of sign-extending pp_val[32] across upper bits,
    //   invert pp_val[32] and add a '1' at position 33+2*gi (handled in correction)
    wire pp_sign = pp_val[32];
    wire [32:0] pp_corrected = {~pp_sign, pp_val[31:0]}; // invert MSB
    
    if (gi == 0) begin : shift0
      assign pp[gi] = {33'b0, pp_corrected};
    end else begin : shift_n
      wire [65:0] pp_full;
      assign pp_full = {33'b0, pp_corrected};
      assign pp[gi] = pp_full << (2*gi);
    end
  end
endgenerate

// Booth correction: two components:
// 1. Add 1 at position 2*i for each negative booth digit (two's complement of one's complement)
// 2. Add 1 at position 33+2*i for each partial product (sign extension prevention)
wire [65:0] booth_correction;
// Build correction vector from booth encodings
wire [16:0] neg_flags;

generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : neg_extract
    assign neg_flags[gi] = booth_ppgen[gi].neg;
  end
endgenerate

// Sign extension prevention: add 1 at bit (33 + 2*gi) for EVERY partial product
// that is non-zero (actually for ALL PPs, since sign ext trick requires it)
// Plus: add 1 at bit (2*gi) for each negative PP (booth correction)
//
// Combined correction vector:
wire [65:0] neg_correction;   // +1 at bit 2*gi for negative PPs
wire [65:0] sign_correction;  // +1 at bit (33+2*gi) for ALL PPs (sign ext prevention)

assign neg_correction = ({65'b0, neg_flags[0]}               ) |
                         ({63'b0, neg_flags[1], 2'b0}           ) |
                         ({61'b0, neg_flags[2], 4'b0}           ) |
                         ({59'b0, neg_flags[3], 6'b0}           ) |
                         ({57'b0, neg_flags[4], 8'b0}           ) |
                         ({55'b0, neg_flags[5], 10'b0}          ) |
                         ({53'b0, neg_flags[6], 12'b0}          ) |
                         ({51'b0, neg_flags[7], 14'b0}          ) |
                         ({49'b0, neg_flags[8], 16'b0}          ) |
                         ({47'b0, neg_flags[9], 18'b0}          ) |
                         ({45'b0, neg_flags[10], 20'b0}         ) |
                         ({43'b0, neg_flags[11], 22'b0}         ) |
                         ({41'b0, neg_flags[12], 24'b0}         ) |
                         ({39'b0, neg_flags[13], 26'b0}         ) |
                         ({37'b0, neg_flags[14], 28'b0}         ) |
                         ({35'b0, neg_flags[15], 30'b0}         ) |
                         ({33'b0, neg_flags[16], 32'b0}         );

// For sign extension prevention, we need a 1 at bit (33 + 2*gi) for each PP.
// But for PPs with gi >= 17 (no PP), no correction needed.
// Also, 33 + 2*16 = 65, which is the MSB of our 66-bit accumulator, so all fit.
// For simplicity, since all 17 PPs always exist (even if zero),
// we add 1 at positions 33, 35, 37, ..., 65
assign sign_correction = 66'b10_10101010_10101010_10101010_10101010_00000000_00000000_00000000_00000000;
// That's a 1 at every odd bit from 33 to 65: bits 33,35,37,...,65

assign booth_correction = neg_correction + sign_correction;

// ============================================================================
// Wallace Tree — CSA compression (18 inputs → 2 outputs)
// 3:2 CSA: sum = a^b^c, carry = (a&b | b&c | a&c) << 1
// ============================================================================

// Helper function-like macro for CSA
// We define signals explicitly for each layer

// 18 inputs: pp[0..16] + booth_correction
wire [65:0] wt [17:0];
generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : wt_in
    assign wt[gi] = pp[gi];
  end
endgenerate
assign wt[17] = booth_correction;

// ----- Layer 1: 18 → 12 (6 CSA3:2 units) -----
wire [65:0] l1s [5:0], l1c [5:0];
generate
  for (gi = 0; gi < 6; gi = gi + 1) begin : L1
    wire [65:0] a_w = wt[3*gi];
    wire [65:0] b_w = wt[3*gi+1];
    wire [65:0] c_w = wt[3*gi+2];
    assign l1s[gi] = a_w ^ b_w ^ c_w;
    assign l1c[gi] = (a_w & b_w | b_w & c_w | a_w & c_w) << 1;
  end
endgenerate

// ----- Layer 2: 12 → 8 (4 CSA3:2 units) -----
// Inputs: l1s[0..5], l1c[0..5] → group into triples
// Group: {l1s[0],l1c[0],l1s[1]}, {l1c[1],l1s[2],l1c[2]}, {l1s[3],l1c[3],l1s[4]}, {l1c[4],l1s[5],l1c[5]}
wire [65:0] l2s [3:0], l2c [3:0];
// CSA 0
assign l2s[0] = l1s[0] ^ l1c[0] ^ l1s[1];
assign l2c[0] = (l1s[0] & l1c[0] | l1c[0] & l1s[1] | l1s[0] & l1s[1]) << 1;
// CSA 1
assign l2s[1] = l1c[1] ^ l1s[2] ^ l1c[2];
assign l2c[1] = (l1c[1] & l1s[2] | l1s[2] & l1c[2] | l1c[1] & l1c[2]) << 1;
// CSA 2
assign l2s[2] = l1s[3] ^ l1c[3] ^ l1s[4];
assign l2c[2] = (l1s[3] & l1c[3] | l1c[3] & l1s[4] | l1s[3] & l1s[4]) << 1;
// CSA 3
assign l2s[3] = l1c[4] ^ l1s[5] ^ l1c[5];
assign l2c[3] = (l1c[4] & l1s[5] | l1s[5] & l1c[5] | l1c[4] & l1c[5]) << 1;

// ----- Layer 3: 8 → 6 (2 CSAs + 2 pass) -----
wire [65:0] l3s [1:0], l3c [1:0];
// CSA 0: l2s[0], l2c[0], l2s[1]
assign l3s[0] = l2s[0] ^ l2c[0] ^ l2s[1];
assign l3c[0] = (l2s[0] & l2c[0] | l2c[0] & l2s[1] | l2s[0] & l2s[1]) << 1;
// CSA 1: l2s[2], l2c[2], l2s[3]
assign l3s[1] = l2s[2] ^ l2c[2] ^ l2s[3];
assign l3c[1] = (l2s[2] & l2c[2] | l2c[2] & l2s[3] | l2s[2] & l2s[3]) << 1;
// Pass-through: l2c[1], l2c[3]
wire [65:0] l3p0 = l2c[1];
wire [65:0] l3p1 = l2c[3];

// ----- Layer 4: 6 → 4 (2 CSAs) -----
wire [65:0] l4s [1:0], l4c [1:0];
// CSA 0: l3s[0], l3c[0], l3p0
assign l4s[0] = l3s[0] ^ l3c[0] ^ l3p0;
assign l4c[0] = (l3s[0] & l3c[0] | l3c[0] & l3p0 | l3s[0] & l3p0) << 1;
// CSA 1: l3s[1], l3c[1], l3p1
assign l4s[1] = l3s[1] ^ l3c[1] ^ l3p1;
assign l4c[1] = (l3s[1] & l3c[1] | l3c[1] & l3p1 | l3s[1] & l3p1) << 1;

// ----- Layer 5: 4 → 3 (1 CSA + 1 pass) -----
wire [65:0] l5s, l5c;
assign l5s = l4s[0] ^ l4c[0] ^ l4s[1];
assign l5c = (l4s[0] & l4c[0] | l4c[0] & l4s[1] | l4s[0] & l4s[1]) << 1;
wire [65:0] l5p = l4c[1];

// ----- Layer 6: 3 → 2 (1 CSA) -----
wire [65:0] l6s, l6c;
assign l6s = l5s ^ l5c ^ l5p;
assign l6c = (l5s & l5c | l5c & l5p | l5s & l5p) << 1;

// ============================================================================
// Pipeline register (end of cycle 1)
// ============================================================================
reg [65:0] pipe_s, pipe_c;
reg [1:0]  pipe_op;
reg        pipe_valid;
reg        pipe_neg;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    pipe_s     <= 66'b0;
    pipe_c     <= 66'b0;
    pipe_op    <= 2'b0;
    pipe_valid <= 1'b0;
    pipe_neg   <= 1'b0;
  end else begin
    pipe_s     <= l6s;
    pipe_c     <= l6c;
    pipe_op    <= mul_op;
    pipe_valid <= mul_valid;
    pipe_neg   <= result_neg;
  end
end

// ============================================================================
// Cycle 2: Final CPA + result selection
// ============================================================================
wire [65:0] unsigned_product = pipe_s + pipe_c;

// For high-word results (MULH/MULHSU/MULHU), we need the signed product
// unsigned_product is |a| * |b|
// If result is negative, negate the full 64-bit product
wire [63:0] signed_product = pipe_neg ? (~unsigned_product[63:0] + 1'b1) :
                                         unsigned_product[63:0];

// Result selection
// MUL (00): low 32 bits — two's complement low word is same for signed/unsigned
assign mul_result = (pipe_op == 2'b00) ? signed_product[31:0] :  // MUL: low 32
                                          signed_product[63:32];    // MULH/MULHSU/MULHU: high 32

assign mul_done = pipe_valid;

always @(posedge clock) begin
  if (pipe_valid)
    $display("[MUL] op=%b neg=%b result=%d (0x%x) uprod=%x sprod=%x", pipe_op, pipe_neg, mul_result, mul_result, unsigned_product, signed_product);
end

// ============================================================================
// Debug display (disabled)
// ============================================================================
// always @(posedge clock) begin
//   if (mul_valid) begin
//     $display("[MUL] CYCLE1: src1=%0d src2=%0d abs_a=%0d abs_b=%0d result_neg=%b",
//              src1, src2, abs_a, abs_b, result_neg);
//     $display("[MUL]   l6s=%0h l6c=%0h", l6s, l6c);
//   end
//   if (pipe_valid) begin
//     $display("[MUL] CYCLE2: pipe_s=%0h pipe_c=%0h unsigned_prod=%0h signed_prod=%0h",
//              pipe_s, pipe_c, unsigned_product, signed_product);
//     $display("[MUL]   pipe_op=%b pipe_neg=%b mul_result=%0d (0x%0h)",
//              pipe_op, pipe_neg, mul_result, mul_result);
//   end
// end
// 
// always @(posedge clock) begin
//   if (mul_valid) begin
//     $display("[MUL-IN]  src1=%0d src2=%0d neg_flags[0]=%b booth_correction=%0h (dec=%0d)",
//              src1, src2, neg_flags[0], booth_correction, booth_correction);
//   end
//   if (pipe_valid) begin
//     $display("[MUL-OUT] result=%0d unsigned_prod[31:0]=%0d pipe_s+pipe_c=%0h",
//              mul_result, unsigned_product[31:0], pipe_s + pipe_c);
//   end
// end

endmodule
