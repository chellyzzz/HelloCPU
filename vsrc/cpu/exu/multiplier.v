module hcpu_multiplier (
    input                               clock,
    input                               reset,
    input              [31:0]           src1,
    input              [31:0]           src2,
    input              [1:0]            mul_op,
    input                               mul_valid,
    output             [31:0]           mul_result,
    output                              mul_done
);

wire signed [32:0] src1_signed_ext = {src1[31], src1};
wire signed [32:0] src2_signed_ext = {src2[31], src2};
wire signed [32:0] src2_unsigned_ext = {1'b0, src2};
wire        [32:0] src1_unsigned_ext = {1'b0, src1};

wire signed [65:0] product_ss_wide = src1_signed_ext * src2_signed_ext;
wire signed [65:0] product_su_wide = src1_signed_ext * src2_unsigned_ext;
wire        [65:0] product_uu_wide = src1_unsigned_ext * src2_unsigned_ext;

wire [63:0] product_ss = product_ss_wide[63:0];
wire [63:0] product_su = product_su_wide[63:0];
wire [63:0] product_uu = product_uu_wide[63:0];

wire [63:0] selected_product = (mul_op == 2'b01) ? product_ss :
                               (mul_op == 2'b10) ? product_su :
                                                    product_uu;

reg [63:0] pipe_product;
reg [1:0]  pipe_op;
reg        pipe_valid;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    pipe_product <= 64'b0;
    pipe_op      <= 2'b0;
    pipe_valid   <= 1'b0;
  end else begin
    if (pipe_valid) begin
      pipe_valid <= 1'b0;
    end else if (mul_valid) begin
      pipe_product <= selected_product;
      pipe_op      <= mul_op;
      pipe_valid   <= 1'b1;
    end
  end
end

assign mul_result = (pipe_op == 2'b00) ? pipe_product[31:0] :
                                         pipe_product[63:32];
assign mul_done = pipe_valid;

endmodule
