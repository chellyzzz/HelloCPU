// ============================================================================
// Booth-2 + Wallace Tree Multiplier — 2-cycle pipeline
// Fixed: replaced sign extension prevention trick with full sign extension
// ============================================================================
module hcpu_multiplier (
    input                               clock                      ,
    input                               reset                      ,
    input              [  31:0]         src1                       ,
    input              [  31:0]         src2                       ,
    input              [   1:0]         mul_op                     ,
    input                               mul_valid                  ,
    output             [  31:0]         mul_result                 ,
    output                              mul_done                    
);

// ============================================================================
// Sign handling
// ============================================================================
wire src1_neg = (~mul_op[1] | ~mul_op[0]) & src1[31];
wire src2_neg = ~mul_op[1] & ~mul_op[0] & src2[31] |
                ~mul_op[1] &  mul_op[0] & src2[31];
wire src2_is_signed = ~mul_op[1];

wire [31:0] abs_a = src1_neg ? (~src1 + 1'b1) : src1;
wire [31:0] abs_b = (src2_is_signed & src2[31]) ? (~src2 + 1'b1) : src2;
wire result_neg = src1_neg ^ (src2_is_signed & src2[31]);

// ============================================================================
// Partial Product Generation using Booth-2 Radix-4
// ============================================================================
wire [33:0] b_pad = {1'b0, abs_b, 1'b0};

wire [65:0] pp [16:0];

genvar gi;
generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : booth_ppgen
    wire [2:0] grp;
    if (gi < 16) begin : normal
      assign grp = b_pad[2*gi+2 -: 3];
    end else begin : last
      assign grp = {1'b0, b_pad[33:32]};
    end

    wire neg = grp[2];
    wire one = grp[0] ^ grp[1];
    wire two = (grp[2] & ~grp[1] & ~grp[0]) | (~grp[2] & grp[1] & grp[0]);

    wire [32:0] pp_raw;
    assign pp_raw = two ? {abs_a, 1'b0} :
                    one ? {1'b0, abs_a}  :
                    33'b0;

    wire [32:0] pp_val = neg ? (~pp_raw) : pp_raw;

    // Full sign extension: fill upper bits with MSB of pp_val
    wire [65:0] pp_ext;
    assign pp_ext = {{(34){pp_val[32]}}, pp_val[31:0]};
    
    if (gi == 0) begin : shift0
      assign pp[gi] = pp_ext;
    end else begin : shift_n
      assign pp[gi] = pp_ext << (2*gi);
    end
  end
endgenerate

// Booth correction: only for two's complement (neg_flags at position 2*gi)
wire [16:0] neg_flags;
generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : neg_extract
    assign neg_flags[gi] = booth_ppgen[gi].neg;
  end
endgenerate

wire [65:0] booth_correction;
assign booth_correction = ({65'b0, neg_flags[0]}               ) |
                           ({63'b0, neg_flags[1], 2'b0}          ) |
                           ({61'b0, neg_flags[2], 4'b0}          ) |
                           ({59'b0, neg_flags[3], 6'b0}          ) |
                           ({57'b0, neg_flags[4], 8'b0}          ) |
                           ({55'b0, neg_flags[5], 10'b0}         ) |
                           ({53'b0, neg_flags[6], 12'b0}         ) |
                           ({51'b0, neg_flags[7], 14'b0}         ) |
                           ({49'b0, neg_flags[8], 16'b0}         ) |
                           ({47'b0, neg_flags[9], 18'b0}         ) |
                           ({45'b0, neg_flags[10], 20'b0}        ) |
                           ({43'b0, neg_flags[11], 22'b0}        ) |
                           ({41'b0, neg_flags[12], 24'b0}        ) |
                           ({39'b0, neg_flags[13], 26'b0}        ) |
                           ({37'b0, neg_flags[14], 28'b0}        ) |
                           ({35'b0, neg_flags[15], 30'b0}        ) |
                           ({33'b0, neg_flags[16], 32'b0}        );

// ============================================================================
// Wallace Tree — CSA compression (18 inputs → 2 outputs)
// ============================================================================
wire [65:0] wt [17:0];
generate
  for (gi = 0; gi < 17; gi = gi + 1) begin : wt_in
    assign wt[gi] = pp[gi];
  end
endgenerate
assign wt[17] = booth_correction;

// ----- Layer 1: 18 → 12 (6 CSA3:2) -----
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

// ----- Layer 2: 12 → 8 (4 CSA3:2) -----
wire [65:0] l2s [3:0], l2c [3:0];
assign l2s[0] = l1s[0] ^ l1c[0] ^ l1s[1];
assign l2c[0] = (l1s[0] & l1c[0] | l1c[0] & l1s[1] | l1s[0] & l1s[1]) << 1;
assign l2s[1] = l1c[1] ^ l1s[2] ^ l1c[2];
assign l2c[1] = (l1c[1] & l1s[2] | l1s[2] & l1c[2] | l1c[1] & l1c[2]) << 1;
assign l2s[2] = l1s[3] ^ l1c[3] ^ l1s[4];
assign l2c[2] = (l1s[3] & l1c[3] | l1c[3] & l1s[4] | l1s[3] & l1s[4]) << 1;
assign l2s[3] = l1c[4] ^ l1s[5] ^ l1c[5];
assign l2c[3] = (l1c[4] & l1s[5] | l1s[5] & l1c[5] | l1c[4] & l1c[5]) << 1;

// ----- Layer 3: 8 → 6 (2 CSAs + 2 pass) -----
wire [65:0] l3s [1:0], l3c [1:0];
assign l3s[0] = l2s[0] ^ l2c[0] ^ l2s[1];
assign l3c[0] = (l2s[0] & l2c[0] | l2c[0] & l2s[1] | l2s[0] & l2s[1]) << 1;
assign l3s[1] = l2s[2] ^ l2c[2] ^ l2s[3];
assign l3c[1] = (l2s[2] & l2c[2] | l2c[2] & l2s[3] | l2s[2] & l2s[3]) << 1;
wire [65:0] l3p0 = l2c[1];
wire [65:0] l3p1 = l2c[3];

// ----- Layer 4: 6 → 4 (2 CSAs) -----
wire [65:0] l4s [1:0], l4c [1:0];
assign l4s[0] = l3s[0] ^ l3c[0] ^ l3p0;
assign l4c[0] = (l3s[0] & l3c[0] | l3c[0] & l3p0 | l3s[0] & l3p0) << 1;
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
// Pipeline register — with mul_busy for 1-cycle mul_done pulse
// ============================================================================
reg [65:0] pipe_s, pipe_c;
reg [1:0]  pipe_op;
reg        pipe_valid;
reg        pipe_neg;
reg        mul_busy;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    pipe_s     <= 66'b0;
    pipe_c     <= 66'b0;
    pipe_op    <= 2'b0;
    pipe_valid <= 1'b0;
    pipe_neg   <= 1'b0;
    mul_busy   <= 1'b0;
  end else begin
    pipe_s     <= l6s;
    pipe_c     <= l6c;
    pipe_op    <= mul_op;
    pipe_neg   <= result_neg;
    
    if (mul_valid && !mul_busy) begin
      mul_busy   <= 1'b1;
      pipe_valid <= 1'b0;
    end else if (mul_busy) begin
      mul_busy   <= 1'b0;
      pipe_valid <= 1'b1;
    end else begin
      mul_busy   <= 1'b0;
      pipe_valid <= 1'b0;
    end
  end
end

// ============================================================================
// Cycle 2: Final CPA + result selection
// ============================================================================
wire [65:0] unsigned_product = pipe_s + pipe_c;

wire [63:0] signed_product = pipe_neg ? (~unsigned_product[63:0] + 1'b1) :
                                         unsigned_product[63:0];

assign mul_result = (pipe_op == 2'b00) ? signed_product[31:0] :
                                           signed_product[63:32];

assign mul_done = pipe_valid;

endmodule
