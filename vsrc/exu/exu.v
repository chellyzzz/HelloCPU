module hcpu_EXU(
    input                               clock                      ,
    input                               reset                      ,
    input              [  31:0]         i_src1                     ,
    input              [  31:0]         i_src2                     ,
    input              [  31:0]         i_pc                       ,
    input              [  31:0]         i_imm                      ,
    input              [   1:0]         i_src_sel1                 ,
    input              [   2:0]         i_src_sel2                 ,

    //control signal
    input                               i_load                     ,
    input                               i_store                    ,
    input                               i_brch                     ,
    input                               i_jal                      ,
    input                               i_jalr                     ,
    //ecall and mret
    input                               i_ecall                    ,
    input                               i_mret                     ,
    input              [   9:0]         i_alu_opt                  ,
    input              [   2:0]         exu_opt                    ,
    input                               i_muldiv                   ,

    output             [  31:0]         o_res                      ,
    output                              o_brch                     ,
    output             [  31:0]         o_pc_next                  ,

    //write address channel  
    output             [  31:0]         M_AXI_AWADDR               ,
    output                              M_AXI_AWVALID              ,
    input                               M_AXI_AWREADY              ,
    output             [   7:0]         M_AXI_AWLEN                ,
    output             [   2:0]         M_AXI_AWSIZE               ,
    output             [   1:0]         M_AXI_AWBURST              ,
    output             [   3:0]         M_AXI_AWID                 ,

    //write data channel
    output                              M_AXI_WVALID               ,
    input                               M_AXI_WREADY               ,
    output             [  31:0]         M_AXI_WDATA                ,
    output             [   3:0]         M_AXI_WSTRB                ,
    output                              M_AXI_WLAST                ,

    //read data channel
    input              [  31:0]         M_AXI_RDATA                ,
    input              [   1:0]         M_AXI_RRESP                ,
    input                               M_AXI_RVALID               ,
    output                              M_AXI_RREADY               ,
    input              [   3:0]         M_AXI_RID                  ,
    input                               M_AXI_RLAST                ,

    //read adress channel
    output             [  31:0]         M_AXI_ARADDR               ,
    output                              M_AXI_ARVALID              ,
    input                               M_AXI_ARREADY              ,
    output             [   3:0]         M_AXI_ARID                 ,
    output             [   7:0]         M_AXI_ARLEN                ,
    output             [   2:0]         M_AXI_ARSIZE               ,
    output             [   1:0]         M_AXI_ARBURST              ,

    //write back channel
    input              [   1:0]         M_AXI_BRESP                ,
    input                               M_AXI_BVALID               ,
    output                              M_AXI_BREADY               ,
    input              [   3:0]         M_AXI_BID                  ,
  //exu -> wbu handshake
    input                               i_post_ready               ,
    input                               i_pre_valid                ,
    output                              o_post_valid               ,
    output                              o_pre_ready                 
);

/******************parameter******************/
parameter BEQ   = 3'b000;
parameter BNE   = 3'b001;
parameter BLT   = 3'b100;
parameter BGE   = 3'b101;
parameter BLTU  = 3'b110;
parameter BGEU  = 3'b111;

wire                   [  31:0]         alu_res, load_res          ;
wire                                    if_lsu                     ;
wire                                    lsu_done                   ;

// M extension signals
wire                   [  31:0]         mul_result, div_result     ;
wire                                    mul_done, div_done         ;
wire                                    if_mul, if_div             ;
wire                                    muldiv_done                ;
wire                   [  31:0]         muldiv_res                 ;

assign if_mul  = i_muldiv & ~exu_opt[2]; // func3[2]==0: MUL/MULH/MULHSU/MULHU
assign if_div  = i_muldiv &  exu_opt[2]; // func3[2]==1: DIV/DIVU/REM/REMU
assign muldiv_done = if_mul ? mul_done : if_div ? div_done : 1'b0;
assign muldiv_res  = if_mul ? mul_result : div_result;

reg post_valid;

assign if_lsu = i_load || i_store;
assign o_post_valid =  if_lsu   ?  lsu_done    :
                       i_muldiv ?  muldiv_done :
                       post_valid;

assign o_pre_ready  =  if_lsu   ?  lsu_done    :
                       i_muldiv ?  muldiv_done :
                       1'b1;

always @(posedge clock or posedge reset) begin
    if(reset) begin
        post_valid <= 1'b0;   
    end
    else post_valid <= i_pre_valid;
end

reg                  [  31:0]         alu_src1                   ;
reg                  [  31:0]         alu_src2                   ;

// always_comb begin
//     unique case(1'b1)
//         i_src_sel1[0]:  alu_src1 = i_src1;
//         default: alu_src1 = i_pc;
//     endcase
// end

// always_comb begin
//     unique case(1'b1)
//         i_src_sel2[0]:  alu_src2 = i_src2;
//         i_src_sel2[1]:  alu_src2 = i_imm;
//         i_src_sel2[2]:  alu_src2 = 32'h4;
//         default: alu_src2 = 32'h0;
//     endcase
// end

wire src_sel1_0 = i_src_sel1[0];
wire src_sel2_0 = i_src_sel2[0];
wire src_sel2_1 = i_src_sel2[1];
wire src_sel2_2 = i_src_sel2[2];

always @(*) begin
    unique case (1'b1)
        src_sel1_0:  alu_src1 = i_src1;
        default:     alu_src1 = i_pc;
    endcase
end

always @(*) begin
    unique case (1'b1)
        src_sel2_0:  alu_src2 = i_src2;
        src_sel2_1:  alu_src2 = i_imm;
        src_sel2_2:  alu_src2 = 32'h4;
        default:     alu_src2 = 32'h0;
    endcase
end

assign o_pc_next =    i_jal             ? i_pc    + i_imm : 
                      i_jalr            ? i_src1  + i_imm : 
                      i_brch            ? i_pc    + i_imm :
                      i_ecall           ? i_src1          :
                      i_mret            ? i_src1          : 
                      i_pc + 4;

hcpu_ALU exu_alu(
    .src1                              (alu_src1                  ),
    .src2                              (alu_src2                  ),
    .opt                               (i_alu_opt                 ),
    .res                               (alu_res                   ) 
);

// ============================================================================
// Multiplier (2-cycle)
// ============================================================================
hcpu_multiplier exu_mul(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .src1                              (i_src1                    ),
    .src2                              (i_src2                    ),
    .mul_op                            (exu_opt[1:0]              ),
    .mul_valid                         (if_mul        ),
    .mul_result                        (mul_result                ),
    .mul_done                          (mul_done                  ) 
);

// ============================================================================
// Divider (16-cycle)
// ============================================================================
hcpu_divider exu_div(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .src1                              (i_src1                    ),
    .src2                              (i_src2                    ),
    .div_op                            (exu_opt[1:0]              ),
    .div_valid                         (if_div      ),
    .div_result                        (div_result                ),
    .div_done                          (div_done                  ) 
);

// ============================================================================
// LSU
// ============================================================================
hcpu_LSU exu_lsu(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .store_src                         (i_src2                    ),
    .alu_res                           (alu_res                   ),
    .exu_opt                           (exu_opt                   ),
    .load_res                          (load_res                  ),
    .i_load                            (i_load                    ),
    .i_store                           (i_store                   ),
  //lsu ->exu sram axi
  //write address channel  
    .M_AXI_AWADDR                      (M_AXI_AWADDR              ),
    .M_AXI_AWVALID                     (M_AXI_AWVALID             ),
    .M_AXI_AWREADY                     (M_AXI_AWREADY             ),
    .M_AXI_AWLEN                       (M_AXI_AWLEN               ),
    .M_AXI_AWSIZE                      (M_AXI_AWSIZE              ),
    .M_AXI_AWBURST                     (M_AXI_AWBURST             ),
    .M_AXI_AWID                        (M_AXI_AWID                ),

  //write data channel
    .M_AXI_WVALID                      (M_AXI_WVALID              ),
    .M_AXI_WREADY                      (M_AXI_WREADY              ),
    .M_AXI_WDATA                       (M_AXI_WDATA               ),
    .M_AXI_WSTRB                       (M_AXI_WSTRB               ),
    .M_AXI_WLAST                       (M_AXI_WLAST               ),
  //read data channel
    .M_AXI_RDATA                       (M_AXI_RDATA               ),
    .M_AXI_RRESP                       (M_AXI_RRESP               ),
    .M_AXI_RVALID                      (M_AXI_RVALID              ),
    .M_AXI_RREADY                      (M_AXI_RREADY              ),
    .M_AXI_RID                         (M_AXI_RID                 ),
    .M_AXI_RLAST                       (M_AXI_RLAST               ),
  //read adress channel
    .M_AXI_ARADDR                      (M_AXI_ARADDR              ),
    .M_AXI_ARVALID                     (M_AXI_ARVALID             ),
    .M_AXI_ARREADY                     (M_AXI_ARREADY             ),
    .M_AXI_ARID                        (M_AXI_ARID                ),
    .M_AXI_ARLEN                       (M_AXI_ARLEN               ),
    .M_AXI_ARSIZE                      (M_AXI_ARSIZE              ),
    .M_AXI_ARBURST                     (M_AXI_ARBURST             ),
  //write back channel
    .M_AXI_BRESP                       (M_AXI_BRESP               ),
    .M_AXI_BVALID                      (M_AXI_BVALID              ),
    .M_AXI_BREADY                      (M_AXI_BREADY              ),
    .M_AXI_BID                         (M_AXI_BID                 ),
  //handshake
    .o_pre_ready                       (o_pre_ready               ),
    .lsu_done                          (lsu_done                  )
);

wire beq, bne;
assign beq = (alu_src1 == alu_src2);
assign bne = ~beq;
reg                                     brch_res                   ;
wire [2:0] brch_opt;
assign brch_opt = exu_opt;
always @(*) begin
  case(brch_opt)
    BEQ:  brch_res = beq;
    BNE:  brch_res = bne;
    BLT:  brch_res = alu_res[0] ;
    BGE:  brch_res = ~alu_res[0] ;
    BLTU: brch_res = alu_res[0];
    BGEU: brch_res = ~alu_res[0];
    default: brch_res = 1'b0;
  endcase
end
assign o_res  = i_load   ? load_res   :
                i_muldiv ? muldiv_res :
                alu_res;
assign o_brch = i_brch && brch_res;

endmodule
