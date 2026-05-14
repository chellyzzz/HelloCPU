// ============================================================================
// hcpu_IDU — Instruction Decode Unit
// ============================================================================

module hcpu_IDU (
    input                               clock,
    input              [  31:0]         ins,
    input                               reset,

    output             [  31:0]         o_imm,
    output             [   4:0]         o_rd,
    output             [   4:0]         o_rs1,
    output             [   4:0]         o_rs2,
    output             [  11:0]         o_csr_addr,
    output             [   2:0]         o_exu_opt,
    output             [   9:0]         o_alu_opt,
    output                              o_wen,
    output                              o_csr_wen,
    output             [   1:0]         o_src_sel1,
    output             [   2:0]         o_src_sel2,

    output                              o_mret,
    output                              o_ecall,
    output                              o_load,
    output                              o_store,
    output                              o_brch,
    output                              o_jal,
    output                              o_jalr,
    output                              o_ebreak,
    output                              o_fence_i,
    output                              o_muldiv,
    output                              o_is_cop_insn
);

// ALU operation select (one-hot, 10-bit)
// Note: SRL/SRA naming swapped vs actual function (legacy quirk)
localparam ALU_ADD  = 10'd1;
localparam ALU_SUB  = 10'd2;
localparam ALU_SLL  = 10'd4;
localparam ALU_SLT  = 10'd8;
localparam ALU_SLTU = 10'd16;
localparam ALU_XOR  = 10'd32;
localparam ALU_SRL  = 10'd64;   // actually arithmetic shift
localparam ALU_OR   = 10'd128;
localparam ALU_AND  = 10'd256;
localparam ALU_SRA  = 10'd512;  // actually logical shift

// Source operand selection
localparam SEL1_REG = 2'b01;
localparam SEL1_PC  = 2'b10;
localparam SEL2_REG = 3'b001;
localparam SEL2_IMM = 3'b010;
localparam SEL2_4   = 3'b100;

// func3 aliases
localparam FUN3_ADD     = 3'b000;
localparam FUN3_SLL     = 3'b001;
localparam FUN3_SLT     = 3'b010;
localparam FUN3_SLTU    = 3'b011;
localparam FUN3_XOR     = 3'b100;
localparam FUN3_SRL_SRA = 3'b101;
localparam FUN3_OR      = 3'b110;
localparam FUN3_AND     = 3'b111;
localparam FUN3_CSRRW   = 3'b001;
localparam FUN3_CSRRS   = 3'b010;

// opcode constants
localparam TYPE_I      = 7'b0010011;
localparam TYPE_I_LOAD = 7'b0000011;
localparam TYPE_JALR   = 7'b1100111;
localparam TYPE_EBRK   = 7'b1110011;
localparam TYPE_S      = 7'b0100011;
localparam TYPE_R      = 7'b0110011;
localparam TYPE_AUIPC  = 7'b0010111;
localparam TYPE_LUI    = 7'b0110111;
localparam TYPE_JAL    = 7'b1101111;
localparam TYPE_B      = 7'b1100011;
localparam TYPE_FENCE  = 7'b0001111;
localparam TYPE_COP    = 7'b0001011;
localparam TYPE_OPV    = 7'b1010111;

// Instruction field extraction
wire [2:0] func3  = ins[14:12];
wire [6:0] opcode = ins[6:0];
wire [6:0] func7  = ins[31:25];
wire [4:0] rs1    = ins[19:15];
wire [4:0] rs2    = ins[24:20];
wire [4:0] rd     = ins[11:7];

// Instruction class signals
wire TYPEI      = (opcode == TYPE_I);
wire TYPEI_LOAD = (opcode == TYPE_I_LOAD);
wire TYPER      = (opcode == TYPE_R);
wire TYPEM      = (TYPER && func7 == 7'b0000001);
wire TYPELUI    = (opcode == TYPE_LUI);
wire TYPEAUIPC  = (opcode == TYPE_AUIPC);
wire TYPEJAL    = (opcode == TYPE_JAL);
wire TYPEJALR   = (opcode == TYPE_JALR);
wire TYPES      = (opcode == TYPE_S);
wire TYPEB      = (opcode == TYPE_B);
wire TYPEEBRK   = (opcode == TYPE_EBRK);
wire TYPECOP    = (opcode == TYPE_COP);
wire TYPEVSETIVLI = (opcode == TYPE_OPV) && (func3 == 3'b111) && (ins[31] == 1'b0);
wire TYPEVADDVV = (opcode == TYPE_OPV) && (func3 == 3'b000) && (ins[31:26] == 6'b000000) && (ins[25] == 1'b1);
wire valid_ins  = TYPEI || TYPEI_LOAD || TYPER || TYPELUI || TYPEAUIPC ||
                  TYPEJAL || TYPEJALR || TYPES || TYPEB || TYPEEBRK || TYPECOP || TYPEVSETIVLI || TYPEVADDVV ||
                  (opcode == TYPE_FENCE);

// ========================================================================
// Immediate generation
// ========================================================================
assign o_imm =
    (TYPEI || TYPEI_LOAD)   ? {{20{ins[31]}},ins[31:20]}              :
    (TYPELUI || TYPEAUIPC)  ? {ins[31:12], 12'b0}                     :
    (TYPEJAL)               ? {{12{ins[31]}},ins[19:12],ins[20],ins[30:21],1'b0} :
    (TYPEJALR)              ? {{20{ins[31]}},ins[31:20]}              :
    (TYPEB)                 ? {{20{ins[31]}},ins[7],ins[30:25],ins[11:8],1'b0} :
    (TYPES)                 ? {{20{ins[31]}},ins[31:25],ins[11:7]}    :
    (TYPEVSETIVLI)          ? {21'b0, ins[30:20]}                     :
    32'b0;

// ========================================================================
// Register addresses
// ========================================================================
assign o_rd  = rd;
assign o_rs1 = (TYPEAUIPC || TYPELUI || TYPEJAL || TYPEVADDVV) ? 5'b0 : rs1;
assign o_rs2 = (TYPER || TYPEB || TYPES || TYPECOP) ? rs2 : 5'b0;

// ========================================================================
// CSR address
// ========================================================================
assign o_csr_addr = TYPEEBRK ? ins[31:20] : 12'b0;

// ========================================================================
// Write enables
// ========================================================================
assign o_wen     = valid_ins && !(TYPES || TYPEB || opcode == TYPE_FENCE || TYPEVADDVV);
assign o_csr_wen = (TYPEEBRK && |func3);

// ========================================================================
// Unsigned operation detection
// ========================================================================
wire o_if_unsigned;
assign o_if_unsigned =
    (TYPEI  && func3 == FUN3_SRL_SRA && func7[5]) ? 1'b1 :
    (TYPER  && func3 == FUN3_SRL_SRA && func7[5]) ? 1'b1 :
    (TYPER  && func3 == FUN3_ADD      && func7[5]) ? 1'b1 :
    1'b0;

// ========================================================================
// exu_opt output — raw func3 (EXU uses this for branch condition selection)
// local exu_opt   — branch-modified func3 (used for ALU decode only)
// ========================================================================
wire [2:0] exu_opt = TYPEB ? {1'b0, func3[2:1]} : func3;
assign o_exu_opt = func3;

// ========================================================================
// ALU operation decode
// ========================================================================
assign o_alu_opt =
    (TYPEM)                           ? 10'b0    :
    (TYPES)                           ? ALU_ADD  :
    (TYPEI_LOAD)                      ? ALU_ADD  :
    (TYPELUI)                         ? ALU_ADD  :
    (TYPEAUIPC)                       ? ALU_ADD  :
    (TYPEJAL)                         ? ALU_ADD  :
    (TYPEJALR)                        ? ALU_ADD  :
    (TYPEEBRK && func3 == FUN3_CSRRS) ? ALU_OR   :
    (exu_opt == FUN3_ADD     && ~o_if_unsigned) ? ALU_ADD  :
    (exu_opt == FUN3_ADD     &&  o_if_unsigned) ? ALU_SUB  :
    (exu_opt == FUN3_SLL                ) ? ALU_SLL  :
    (exu_opt == FUN3_SLT                ) ? ALU_SLT  :
    (exu_opt == FUN3_SLTU               ) ? ALU_SLTU :
    (exu_opt == FUN3_XOR                ) ? ALU_XOR  :
    (exu_opt == FUN3_SRL_SRA &&  o_if_unsigned) ? ALU_SRA  :
    (exu_opt == FUN3_SRL_SRA && ~o_if_unsigned) ? ALU_SRL  :
    (exu_opt == FUN3_OR                 ) ? ALU_OR   :
    (exu_opt == FUN3_AND                ) ? ALU_AND  :
    10'b0;

// ========================================================================
// Source operand selection
// ========================================================================
assign o_src_sel1 =
    (TYPEI       || TYPER      || TYPELUI   ||
     TYPEI_LOAD  || TYPES      || TYPEB)      ? SEL1_REG :
    (TYPEAUIPC   || TYPEJAL    || TYPEJALR)   ? SEL1_PC  :
    (TYPEEBRK && (func3 == FUN3_CSRRW || func3 == FUN3_CSRRS)) ? SEL1_REG :
    'b0;

assign o_src_sel2 =
    (TYPEI       || TYPELUI    || TYPEAUIPC  ||
     TYPEI_LOAD  || TYPES)                     ? SEL2_IMM :
     (TYPER       || TYPEB || TYPECOP)         ? SEL2_REG :
     (TYPEVSETIVLI)                             ? SEL2_IMM :
     (TYPEJAL     || TYPEJALR)                  ? SEL2_4   :
    (TYPEEBRK && func3 == FUN3_CSRRW)          ? SEL2_IMM :
    (TYPEEBRK && func3 == FUN3_CSRRS)          ? SEL2_REG :
    'b0;

// ========================================================================
// M-extension
// ========================================================================
assign o_muldiv = TYPEM;
assign o_is_cop_insn = TYPECOP || TYPEVSETIVLI || TYPEVADDVV;

// ========================================================================
// Boolean control signals
// ========================================================================
assign o_load    = TYPEI_LOAD;
assign o_store   = TYPES;
assign o_brch    = TYPEB;
assign o_jal     = TYPEJAL;
assign o_jalr    = TYPEJALR;
assign o_fence_i = (opcode == TYPE_FENCE) && (func3 == 3'b001);
assign o_ecall   = (TYPEEBRK && func3 == 3'b000 && rs2[1:0] == 2'b00);
assign o_mret    = (TYPEEBRK && func3 == 3'b000 && rs2[1:0] == 2'b10);
assign o_ebreak  = (TYPEEBRK && func3 == 3'b000 && rs2[1:0] == 2'b01);

endmodule
