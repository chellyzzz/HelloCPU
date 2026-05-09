module hcpu_vector_cop_decode(
    input      [31:0] i_ins,
    output     [2:0]  o_funct3,
    output     [6:0]  o_funct7,
    output     [3:0]  o_scalar_lane_op
);

localparam LANE_OP_ADD8 = 4'd0;
localparam LANE_OP_XOR8 = 4'd1;
localparam LANE_OP_AND8 = 4'd2;

assign o_funct3 = i_ins[14:12];
assign o_funct7 = i_ins[31:25];

assign o_scalar_lane_op = (o_funct3 == 3'b010) ? LANE_OP_XOR8 :
                          (o_funct3 == 3'b011) ? LANE_OP_AND8 :
                          LANE_OP_ADD8;

endmodule
