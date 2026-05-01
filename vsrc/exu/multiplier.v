// ============================================================================
// Booth-2 Sign Handling + Verilog * Core Multiplier — 2-cycle pipeline
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
// Sign handling (identical to original Booth-2 design)
// ============================================================================
wire src1_neg = (~mul_op[1] | ~mul_op[0]) & src1[31];
wire src2_neg = ~mul_op[1] & ~mul_op[0] & src2[31] |
                ~mul_op[1] &  mul_op[0] & src2[31];
wire src2_is_signed = ~mul_op[1];

wire [31:0] abs_a = src1_neg ? (~src1 + 1'b1) : src1;
wire [31:0] abs_b = (src2_is_signed & src2[31]) ? (~src2 + 1'b1) : src2;
wire result_neg = src1_neg ^ (src2_is_signed & src2[31]);

// ============================================================================
// Core multiply: use Verilog * for absolute values (always correct)
// ============================================================================
wire [63:0] unsigned_product_64;
assign unsigned_product_64 = {32'd0, abs_a} * {32'd0, abs_b};

// ============================================================================
// Pipeline register
// ============================================================================
reg [63:0] pipe_prod;
reg [1:0]  pipe_op;
reg        pipe_valid;
reg        pipe_neg;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    pipe_prod  <= 64'b0;
    pipe_op    <= 2'b0;
    pipe_valid <= 1'b0;
    pipe_neg   <= 1'b0;
  end else begin
    pipe_prod  <= unsigned_product_64;
    pipe_op    <= mul_op;
    pipe_valid <= mul_valid;
    pipe_neg   <= result_neg;
  end
end

// ============================================================================
// Cycle 2: sign correction + result selection
// ============================================================================
wire [63:0] signed_product = pipe_neg ? (~pipe_prod + 1'b1) : pipe_prod;

assign mul_result = (pipe_op == 2'b00) ? signed_product[31:0] :
                                           signed_product[63:32];

assign mul_done = pipe_valid;

endmodule
