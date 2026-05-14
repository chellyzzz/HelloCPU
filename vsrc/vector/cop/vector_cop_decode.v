module hcpu_vector_cop_decode(
    input      [31:0] i_ins,
    output     [2:0]  o_funct3,
    output     [6:0]  o_funct7,
    output     [3:0]  o_scalar_lane_op,
    output     [3:0]  o_vrf_lane_op,
    output            o_is_vrf_op,
    output            o_is_vrf_lane,
    output            o_is_mem_load,
    output            o_is_mem_store,
    output            o_scratch_write,
    output            o_vlen_write,
    output            o_vtype_write,
    output            o_vtype_read,
    output            o_vstate_add,
    output            o_vsetivli_proto,
    output            o_vsetivli_standard,
    output            o_vadd_vv_standard
);

localparam LANE_OP_ADD8 = 4'd0;
localparam LANE_OP_XOR8 = 4'd1;
localparam LANE_OP_AND8 = 4'd2;
localparam LANE_OP_SUB8 = 4'd3;
localparam LANE_OP_MUL8 = 4'd4;
localparam LANE_OP_SLL8 = 4'd5;
localparam LANE_OP_SRL8 = 4'd6;
localparam LANE_OP_SRA8 = 4'd7;
localparam LANE_OP_OR8  = 4'd8;

assign o_funct3 = i_ins[14:12];
assign o_funct7 = i_ins[31:25];

assign o_scalar_lane_op = (o_funct3 == 3'b010) ? LANE_OP_XOR8 :
                          (o_funct3 == 3'b011) ? LANE_OP_AND8 :
                          LANE_OP_ADD8;

assign o_vrf_lane_op = (o_funct7 == 7'd6) ? LANE_OP_XOR8 :
                       (o_funct7 == 7'd7) ? LANE_OP_AND8 :
                       (o_funct7 == 7'd8) ? LANE_OP_SUB8 :
                       (o_funct7 == 7'd9) ? LANE_OP_MUL8 :
                       (o_funct7 == 7'd10) ? LANE_OP_SLL8 :
                       (o_funct7 == 7'd11) ? LANE_OP_SRL8 :
                       (o_funct7 == 7'd12) ? LANE_OP_SRA8 :
                       (o_funct7 == 7'd13) ? LANE_OP_OR8 :
                       LANE_OP_ADD8;

assign o_is_vrf_op   = (o_funct3 == 3'b000) && (o_funct7 >= 7'd3) && (o_funct7 <= 7'd13);
assign o_is_vrf_lane = (o_funct3 == 3'b000) && (o_funct7 >= 7'd5) && (o_funct7 <= 7'd13);
assign o_is_mem_load  = (o_funct3 == 3'b000) && (o_funct7 == 7'd14);
assign o_is_mem_store = (o_funct3 == 3'b000) && (o_funct7 == 7'd15);
assign o_scratch_write = (o_funct3 == 3'b100);
assign o_vlen_write    = (o_funct3 == 3'b101);
assign o_vtype_write   = (o_funct3 == 3'b000) && (o_funct7 == 7'd16);
assign o_vtype_read    = (o_funct3 == 3'b000) && (o_funct7 == 7'd17);
assign o_vstate_add    = (o_funct3 == 3'b000) && (o_funct7 == 7'd18);
assign o_vsetivli_proto = (o_funct3 == 3'b000) && (o_funct7 == 7'd19);
assign o_vsetivli_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b111) && (i_ins[31] == 1'b0);
assign o_vadd_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b000000) && (i_ins[25] == 1'b1);

endmodule
