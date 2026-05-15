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
    output            o_vadd_vv_standard,
    output            o_vadd_vx_standard,
    output            o_vadd_vi_standard,
    output            o_vand_vv_standard,
    output            o_vor_vv_standard,
    output            o_vxor_vv_standard,
    output            o_vand_vx_standard,
    output            o_vor_vx_standard,
    output            o_vxor_vx_standard,
    output            o_vand_vi_standard,
    output            o_vor_vi_standard,
    output            o_vxor_vi_standard,
    output            o_vsub_vv_standard,
    output            o_vsub_vx_standard,
    output            o_vmul_vv_standard,
    output            o_vmul_vx_standard,
    output            o_vsll_vv_standard,
    output            o_vsll_vx_standard,
    output            o_vsrl_vv_standard,
    output            o_vsrl_vx_standard,
    output            o_vsra_vv_standard,
    output            o_vsra_vx_standard,
    output            o_vmv_v_v_standard,
    output            o_vmv_v_x_standard,
    output            o_vle8_v_standard,
    output            o_vse8_v_standard,
    output            o_vle16_v_standard,
    output            o_vse16_v_standard,
    output            o_vle32_v_standard,
    output            o_vse32_v_standard
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

wire is_custom_cop = (i_ins[6:0] == 7'b0001011);

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

assign o_is_vrf_op   = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 >= 7'd3) && (o_funct7 <= 7'd13);
assign o_is_vrf_lane = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 >= 7'd5) && (o_funct7 <= 7'd13);
assign o_is_mem_load  = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd14);
assign o_is_mem_store = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd15);
assign o_scratch_write = is_custom_cop && (o_funct3 == 3'b100);
assign o_vlen_write    = is_custom_cop && (o_funct3 == 3'b101);
assign o_vtype_write   = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd16);
assign o_vtype_read    = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd17);
assign o_vstate_add    = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd18);
assign o_vsetivli_proto = is_custom_cop && (o_funct3 == 3'b000) && (o_funct7 == 7'd19);
assign o_vsetivli_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b111) && (i_ins[31] == 1'b0);
assign o_vadd_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b000000);
assign o_vadd_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b000000);
assign o_vadd_vi_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b011) && (i_ins[31:26] == 6'b000000);
assign o_vand_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b001001);
assign o_vor_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b001010);
assign o_vxor_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b001011);
assign o_vand_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b001001);
assign o_vor_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b001010);
assign o_vxor_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b001011);
assign o_vand_vi_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b011) && (i_ins[31:26] == 6'b001001);
assign o_vor_vi_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b011) && (i_ins[31:26] == 6'b001010);
assign o_vxor_vi_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b011) && (i_ins[31:26] == 6'b001011);
assign o_vsub_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b000010);
assign o_vsub_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b000010);
assign o_vmul_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b010) && (i_ins[31:26] == 6'b100101);
assign o_vmul_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b110) && (i_ins[31:26] == 6'b100101);
assign o_vsll_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b100101);
assign o_vsll_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b100101);
assign o_vsrl_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b101000);
assign o_vsrl_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b101000);
assign o_vsra_vv_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b101001);
assign o_vsra_vx_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b101001);
assign o_vmv_v_v_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b000) && (i_ins[31:26] == 6'b010111);
assign o_vmv_v_x_standard = (i_ins[6:0] == 7'b1010111) && (o_funct3 == 3'b100) && (i_ins[31:26] == 6'b010111);
assign o_vle8_v_standard = (i_ins[6:0] == 7'b0000111) && (o_funct3 == 3'b000) && (i_ins[31:20] == 12'b000000100000);
assign o_vse8_v_standard = (i_ins[6:0] == 7'b0100111) && (o_funct3 == 3'b000) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);
assign o_vle16_v_standard = (i_ins[6:0] == 7'b0000111) && (o_funct3 == 3'b101) && (i_ins[31:20] == 12'b000000100000);
assign o_vse16_v_standard = (i_ins[6:0] == 7'b0100111) && (o_funct3 == 3'b101) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);
assign o_vle32_v_standard = (i_ins[6:0] == 7'b0000111) && (o_funct3 == 3'b110) && (i_ins[31:20] == 12'b000000100000);
assign o_vse32_v_standard = (i_ins[6:0] == 7'b0100111) && (o_funct3 == 3'b110) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);

endmodule
