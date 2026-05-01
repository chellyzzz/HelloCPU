
module ysyx_23060124_IDU (
    input                               clock                      ,
    input              [  31:0]         ins                        ,
    input                               reset                      ,

    output             [  31:0]         o_imm                      ,
    output             [   4:0]         o_rd                       ,
    output             [   4:0]         o_rs1                      ,
    output             [   4:0]         o_rs2                      ,
    output             [  11:0]         o_csr_addr                 ,
    output             [   2:0]         o_exu_opt                  ,
    output             [   9:0]         o_alu_opt                  ,
    output                              o_wen                      ,
    output                              o_csr_wen                  ,
    output             [   1:0]         o_src_sel1                 ,
    output             [   2:0]         o_src_sel2                 ,

    output                              o_mret                     ,
    output                              o_ecall                    ,
    output                              o_load                     ,
    output                              o_store                    ,
    output                              o_brch                     ,
    output                              o_jal                      ,
    output                              o_jalr                     ,
    output                              o_ebreak                   ,
    output                              o_fence_i                  ,
    output                              o_muldiv                    
);
/************************parameter**********************/
//TYPE_R_FUN3
localparam                              ADD         =  3'b000      ;
localparam                              SUB         =  3'b000      ;
localparam                              SLL         =  3'b001      ;
localparam                              SLT         =  3'b010      ;
localparam                              SLTU        =  3'b011      ;
localparam                              XOR         =  3'b100      ;
localparam                              SRL_SRA     =  3'b101      ;
localparam                              OR          =  3'b110      ;
localparam                              AND         =  3'b111      ;
//
localparam                              ALU_ADD         =  10'd1   ;
localparam                              ALU_SUB         =  10'd2   ;
localparam                              ALU_SLL         =  10'd4   ;
localparam                              ALU_SLT         =  10'd8   ;
localparam                              ALU_SLTU        =  10'd16  ;
localparam                              ALU_XOR         =  10'd32  ;
localparam                              ALU_SRL         =  10'd64  ;
localparam                              ALU_SRA         =  10'd512  ;
localparam                              ALU_OR          =  10'd128 ;
localparam                              ALU_AND         =  10'd256 ;

//EXU_SRC_SEL
localparam                              EXU_SEL_REG = 4'b0001        ;
localparam                              EXU_SEL_IMM = 4'b0010        ;
localparam                              EXU_SEL_PC4 = 4'b0100        ;
localparam                              EXU_SEL_PCI = 4'b1000        ;
//
localparam                              SEL1_REG = 2'b01        ;
localparam                              SEL1_PC  = 2'b10        ;

localparam                              SEL2_REG = 3'b001        ;
localparam                              SEL2_IMM = 3'b010        ;
localparam                              SEL2_4   = 3'b100        ;


localparam                              TYPE_I       =  7'b0010011;
localparam                              TYPE_I_LOAD  =  7'b0000011;
localparam                              TYPE_JALR    =  7'b1100111;
localparam                              TYPE_EBRK    =  7'b1110011;
localparam                              TYPE_S       =  7'b0100011;
localparam                              TYPE_R       =  7'b0110011;
localparam                              TYPE_AUIPC   =  7'b0010111;
localparam                              TYPE_LUI     =  7'b0110111;
localparam                              TYPE_JAL     =  7'b1101111;
localparam                              TYPE_B       =  7'b1100011;
localparam                              TYPE_FENCE   =  7'b0001111;
//TYPE_I_FUN3
localparam                              FUN3_SRL_SRA =  3'b101     ;
//CSRR
localparam                              FUN3_CSRRW = 3'b001        ;
localparam                              FUN3_CSRRS = 3'b010        ;
localparam                              FUN3_EXCPT = 3'b000        ;
//TYPE_EXCPT_RS2
localparam                              RS2_ECALL   =  5'b00000    ;
localparam                              RS2_MRET    =  5'b00010    ;

wire [2:0] func3    = ins[14:12];
wire [6:0] opcode   = ins[6:0];
wire [6:0] func7    = ins[31:25];
wire [4:0] rs1      = ins[19:15];
wire [4:0] rs2      = ins[24:20];
wire [4:0] rd       = ins[11:7];

wire TYPEI       = (opcode == TYPE_I         );
wire TYPEI_LOAD  = (opcode == TYPE_I_LOAD    );
wire TYPER       = (opcode == TYPE_R         );     
wire TYPEM       = (TYPER && func7 == 7'b0000001); // M extension
wire TYPELUI     = (opcode == TYPE_LUI       );   
wire TYPEAUIPC   = (opcode == TYPE_AUIPC     ); 
wire TYPEJAL     = (opcode == TYPE_JAL       );   
wire TYPEJALR    = (opcode == TYPE_JALR      );  
wire TYPES       = (opcode == TYPE_S         );     
wire TYPEB       = (opcode == TYPE_B         );     
wire TYPEEBRK    = (opcode == TYPE_EBRK      );   

assign o_imm = (TYPEI || TYPEI_LOAD) ? {{20{ins[31]}}, ins[31:20]} :
               (TYPELUI || TYPEAUIPC) ? {ins[31:12], 12'b0} :
               (TYPEJAL) ? {{12{ins[31]}}, ins[19:12], ins[20], ins[30:21], 1'b0} :
               (TYPEJALR) ? {{20{ins[31]}}, ins[31:20]} :
               (TYPEB) ? {{20{ins[31]}}, ins[7], ins[30:25], ins[11:8], 1'b0} :
               (TYPES) ? {{20{ins[31]}}, ins[31:25], ins[11:7]} :
               32'b0;

assign o_rd = rd;

assign o_rs1 = (TYPEAUIPC || TYPELUI ||TYPEJAL) ? 5'b0 : rs1;

assign o_rs2 = (TYPER || TYPEB || TYPES) ? rs2 : 5'b0;

//TODO: TYPE_I
assign o_csr_addr = (TYPEEBRK) ? ins[31:20] : 12'b0;

assign o_wen        = (TYPES || TYPEB || opcode == TYPE_FENCE) ? 1'b0 : 1'b1;

assign o_csr_wen    = (TYPEEBRK && |func3);

wire o_if_unsigned;
assign o_if_unsigned =  (TYPEI && func3 == SRL_SRA && func7[5]) ? 1'b1 :
                        (TYPER && func3 == SRL_SRA && func7[5]) ? 1'b1 :
                        (TYPER && func3 == ADD     && func7[5]) ? 1'b1 :
                        1'b0;

assign o_exu_opt =  func3;
wire [2:0] exu_opt;
assign exu_opt =  (TYPEB)       ? {1'b0,func3[2:1]}:
                  func3;

assign o_alu_opt =  (TYPEM)                         ? 10'b0   :
                    (TYPES)                         ? ALU_ADD  :
                    (TYPEI_LOAD)                    ? ALU_ADD  :
                    (TYPELUI)                       ? ALU_ADD:
                    (TYPEAUIPC)                     ? ALU_ADD:
                    (TYPEJAL)                       ? ALU_ADD:
                    (TYPEEBRK && func3 == FUN3_CSRRS) ? ALU_OR:  
                    (exu_opt ==  ADD && ~o_if_unsigned           )  ? ALU_ADD  :
                    (exu_opt ==  SUB &&  o_if_unsigned           )  ? ALU_SUB  :
                    (exu_opt ==  SLL           )  ? ALU_SLL  :
                    (exu_opt ==  SLT           )  ? ALU_SLT  :
                    (exu_opt ==  SLTU          )  ? ALU_SLTU :
                    (exu_opt ==  XOR           )  ? ALU_XOR  :
                    (exu_opt ==  SRL_SRA &&  o_if_unsigned      )  ? ALU_SRL  :
                    (exu_opt ==  SRL_SRA && ~o_if_unsigned      )  ? ALU_SRA  :
                    (exu_opt ==  OR            )  ? ALU_OR   :
                    (exu_opt ==  AND           )  ? ALU_AND  :
                    10'b0;

assign o_muldiv   = TYPEM;

assign o_src_sel1 =   (TYPEI)       ? SEL1_REG:
                      (TYPER)       ? SEL1_REG:
                      (TYPELUI)     ? SEL1_REG:
                      (TYPEAUIPC)   ? SEL1_PC:
                      (TYPEJAL)     ? SEL1_PC:
                      (TYPEJALR)    ? SEL1_PC:
                      (TYPEI_LOAD)  ? SEL1_REG:
                      (TYPES)       ? SEL1_REG:
                      (TYPEB)       ? SEL1_REG:
                      (TYPEEBRK && func3 == FUN3_CSRRW) ? SEL1_REG:
                      (TYPEEBRK && func3 == FUN3_CSRRS) ? SEL1_REG:
                      'b0;
assign o_src_sel2 =   (TYPEI)       ? SEL2_IMM:
                      (TYPER)       ? SEL2_REG:
                      (TYPELUI)     ? SEL2_IMM:
                      (TYPEAUIPC)   ? SEL2_IMM:
                      (TYPEJAL)     ? SEL2_4:
                      (TYPEJALR)    ? SEL2_4:
                      (TYPEI_LOAD)  ? SEL2_IMM:
                      (TYPES)       ? SEL2_IMM:
                      (TYPEB)       ? SEL2_REG:
                      (TYPEEBRK && func3 == FUN3_CSRRW) ? SEL2_IMM:
                      (TYPEEBRK && func3 == FUN3_CSRRS) ? SEL2_REG:
                      'b0;
                                        
assign o_ecall      = (TYPEEBRK && func3 == 3'b0 && rs2[1:0] == 2'b00);
assign o_mret       = (TYPEEBRK && func3 == 3'b0 && rs2[1:0] == 2'b10);

assign o_load       = (TYPEI_LOAD) ?  'b1: 'b0;
assign o_store      = (TYPES)      ?  'b1: 'b0;
assign o_brch       = (TYPEB)      ?  'b1: 'b0;
assign o_jal        = (TYPEJAL)    ?  'b1: 'b0;
assign o_jalr       = (TYPEJALR)   ?  'b1: 'b0;
assign o_fence_i    = (opcode == TYPE_FENCE)&&(func3 == 3'b001) ? 'b1: 'b0;
assign o_ebreak     = (TYPEEBRK && func3 == 3'b0 && rs2[1:0] == 2'b01);

endmodule
