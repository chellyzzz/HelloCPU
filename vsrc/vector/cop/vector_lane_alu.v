module hcpu_vector_lane_alu(
    input      [31:0] i_lhs,
    input      [31:0] i_rhs,
    input      [3:0]  i_op,
    output reg [31:0] o_res
);

localparam OP_ADD8 = 4'd0;
localparam OP_XOR8 = 4'd1;
localparam OP_AND8 = 4'd2;
localparam OP_SUB8 = 4'd3;
localparam OP_MUL8 = 4'd4;
localparam OP_SLL8 = 4'd5;
localparam OP_SRL8 = 4'd6;

wire [31:0] lane_add8 = {
    i_lhs[31:24] + i_rhs[31:24],
    i_lhs[23:16] + i_rhs[23:16],
    i_lhs[15:8]  + i_rhs[15:8],
    i_lhs[7:0]   + i_rhs[7:0]
};
wire [31:0] lane_sub8 = {
    i_lhs[31:24] - i_rhs[31:24],
    i_lhs[23:16] - i_rhs[23:16],
    i_lhs[15:8]  - i_rhs[15:8],
    i_lhs[7:0]   - i_rhs[7:0]
};
wire [31:0] lane_mul8 = {
    i_lhs[31:24] * i_rhs[31:24],
    i_lhs[23:16] * i_rhs[23:16],
    i_lhs[15:8]  * i_rhs[15:8],
    i_lhs[7:0]   * i_rhs[7:0]
};
wire [31:0] lane_sll8 = {
    i_lhs[31:24] << i_rhs[26:24],
    i_lhs[23:16] << i_rhs[18:16],
    i_lhs[15:8]  << i_rhs[10:8],
    i_lhs[7:0]   << i_rhs[2:0]
};
wire [31:0] lane_srl8 = {
    i_lhs[31:24] >> i_rhs[26:24],
    i_lhs[23:16] >> i_rhs[18:16],
    i_lhs[15:8]  >> i_rhs[10:8],
    i_lhs[7:0]   >> i_rhs[2:0]
};

always @(*) begin
    case (i_op)
        OP_ADD8: o_res = lane_add8;
        OP_XOR8: o_res = i_lhs ^ i_rhs;
        OP_AND8: o_res = i_lhs & i_rhs;
        OP_SUB8: o_res = lane_sub8;
        OP_MUL8: o_res = lane_mul8;
        OP_SLL8: o_res = lane_sll8;
        OP_SRL8: o_res = lane_srl8;
        default: o_res = lane_add8;
    endcase
end

endmodule
