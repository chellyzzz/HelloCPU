// ============================================================================
// Simple Correct Multiplier — 2-cycle pipeline using Verilog * operator
// Supports: MUL (func3=000), MULH (001), MULHSU (010), MULHU (011)
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

// Signed and unsigned 64-bit products
wire signed [63:0] s_product;
wire        [63:0] u_product;

assign s_product = $signed(src1) * $signed(src2);
assign u_product = src1 * src2;

// For MULHSU: signed src1 * unsigned src2
wire signed [63:0] su_product;
assign su_product = $signed(src1) * $unsigned(src2);

// Result mux
wire [63:0] result_64;
assign result_64 = (mul_op == 2'b00) ? s_product                 :  // MUL:    signed × signed, low 32
                   (mul_op == 2'b01) ? s_product                 :  // MULH:   signed × signed, high 32
                   (mul_op == 2'b10) ? su_product                :  // MULHSU: signed × unsigned, high 32
                                       u_product;                   // MULHU:  unsigned × unsigned, high 32

// Result selection: MUL returns low 32, all others return high 32
wire [31:0] next_result;
assign next_result = (mul_op == 2'b00) ? result_64[31:0] : result_64[63:32];

// Pipeline register
reg [31:0] pipe_result;
reg        pipe_valid;
reg [1:0]  pipe_op;
reg [31:0] pipe_src1;
reg [31:0] pipe_src2;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        pipe_result <= 32'b0;
        pipe_valid  <= 1'b0;
        pipe_op     <= 2'b0;
        pipe_src1   <= 32'b0;
        pipe_src2   <= 32'b0;
    end else begin
        pipe_result <= next_result;
        pipe_valid  <= mul_valid;
        pipe_op     <= mul_op;
        pipe_src1   <= src1;
        pipe_src2   <= src2;
    end
end

assign mul_result = pipe_result;
assign mul_done   = pipe_valid;

endmodule
