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
    input                               i_is_cop_insn              ,

    // branch prediction inputs
    input                               i_predict_taken            ,
    input              [  31:2]         i_predict_target           ,
    input                               i_predict_btb_hit          ,
    // register addresses for RAS
    input              [   4:0]         i_rd_addr                  ,
    input              [   4:0]         i_rs1_addr                 ,

    output             [  31:0]         o_res                      ,
    output                              o_brch                     ,
    output             [  31:0]         o_pc_next                  ,

    // Mispredict recovery
    output                              o_mispredict_flush         ,
    output             [  31:0]         o_redirect_pc              ,

    // BTB update
    output                              o_btb_update_en            ,
    output             [  31:0]         o_btb_update_pc            ,
    output             [  31:2]         o_btb_update_target        ,
    output                              o_btb_update_taken         ,

    // Prediction correctness (for WBU pc_update skip)
    output                              o_predict_correct          ,

    // RAS update
    output                              o_ras_push_en              ,
    output             [  31:2]         o_ras_push_data            ,
    output                              o_ras_pop_en               ,

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

    // LSU debug / perf classification
    output                              o_lsu_dbg_wait_start       ,
    output                              o_lsu_dbg_wait_hit         ,
    output                              o_lsu_dbg_wait_refill      ,
    output                              o_lsu_dbg_wait_refill_ar   ,
    output                              o_lsu_dbg_wait_refill_r    ,
    output                              o_lsu_dbg_wait_uncached    ,
    output                              o_lsu_dbg_wait_wb          ,

    // scalar memory service boundary (V1, semantic only)
    output                              o_mem_req_valid            ,
    output                              o_mem_req_store            ,
    output             [  31:0]         o_mem_req_addr             ,
    output             [  31:0]         o_mem_req_wdata            ,
    output             [   2:0]         o_mem_req_size             ,
    output                              o_mem_resp_valid           ,
    output             [  31:0]         o_mem_resp_rdata           ,
  //exu -> wbu handshake
    input                               i_post_ready               ,
    input                               i_pre_valid                ,
    output                              o_post_valid               ,
    output                              o_pre_ready                ,
    input                               i_flush                     
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
wire                   [   2:0]         mem_req_size               ;

// M extension signals
wire                   [  31:0]         mul_result, div_result     ;
wire                                    mul_done, div_done         ;
wire                                    if_mul, if_div             ;
wire                                    if_mul_low                 ;
wire                   [  31:0]         mul_low_res                ;
wire                                    muldiv_done                ;
wire                   [  31:0]         muldiv_res                 ;
wire                   [  31:0]         cop_res                    ;
wire                                    cop_done                   ;
wire                                    if_cop                     ;

`ifdef PERF_BRANCH_PRED
import "DPI-C" function void br_misp_pred_nt_dpic();
import "DPI-C" function void br_misp_pred_taken_nt_dpic();
import "DPI-C" function void br_misp_target_bad_dpic();
import "DPI-C" function void br_misp_pred_nt_btb_hit_dpic();
import "DPI-C" function void br_misp_pred_nt_btb_miss_dpic();
import "DPI-C" function void br_misp_pred_taken_nt_btb_hit_dpic();
import "DPI-C" function void br_misp_pred_taken_nt_btb_miss_dpic();
import "DPI-C" function void branch_trace_dpic(input int pc,
                                               input int btb_hit,
                                               input int pred_taken,
                                               input int pred_target,
                                               input int actual_taken,
                                               input int branch_target);
`endif

assign if_mul  = i_muldiv & ~exu_opt[2]; // func3[2]==0: MUL/MULH/MULHSU/MULHU
assign if_div  = i_muldiv &  exu_opt[2]; // func3[2]==1: DIV/DIVU/REM/REMU
assign if_mul_low = if_mul & (exu_opt[1:0] == 2'b00);
assign mul_low_res = i_src1 * i_src2;
assign muldiv_done = if_mul_low ? i_pre_valid : if_mul ? mul_done : if_div ? div_done : 1'b0;
assign muldiv_res  = if_mul_low ? mul_low_res : if_mul ? mul_result : div_result;
assign if_cop = i_is_cop_insn;
assign mem_req_size = (exu_opt == 3'b001 || exu_opt == 3'b101) ? 3'd1 :
                      (exu_opt == 3'b010)                       ? 3'd2 :
                                                                   3'd0;

reg post_valid;

assign if_lsu = i_load || i_store;
assign o_post_valid =  if_lsu   ?  lsu_done    :
                       if_cop   ?  cop_done    :
                       i_muldiv ?  muldiv_done :
                       i_pre_valid;
assign o_pre_ready  =  if_lsu   ?  lsu_done    :
                       if_cop   ?  cop_done    :
                       i_muldiv ?  muldiv_done :
                       1'b1;

assign o_mem_req_valid  = i_pre_valid && if_lsu;
assign o_mem_req_store  = i_store;
assign o_mem_req_addr   = alu_res;
assign o_mem_req_wdata  = i_src2;
assign o_mem_req_size   = mem_req_size;
assign o_mem_resp_valid = i_pre_valid && if_lsu && lsu_done;
assign o_mem_resp_rdata = load_res;

always @(posedge clock or posedge reset) begin
    if(reset || i_flush) begin
        post_valid <= 1'b0;   
    end
    else post_valid <= i_pre_valid;
end

reg                  [  31:0]         alu_src1                   ;
reg                  [  31:0]         alu_src2                   ;

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
    .mul_valid                         (if_mul && !if_mul_low      ),
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

hcpu_dummy_coprocessor exu_cop(
    .clock                             (clock                     ),
    .reset                             (reset || i_flush          ),
    .i_valid                           (i_pre_valid && if_cop     ),
    .i_src1                            (i_src1                    ),
    .i_src2                            (i_src2                    ),
    .i_ins                             (32'b0                     ),
    .o_res                             (cop_res                   ),
    .o_done                            (cop_done                  )
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
    .lsu_done                          (lsu_done                  ),
    .o_dbg_wait_start                  (o_lsu_dbg_wait_start      ),
    .o_dbg_wait_hit                    (o_lsu_dbg_wait_hit        ),
    .o_dbg_wait_refill                 (o_lsu_dbg_wait_refill     ),
    .o_dbg_wait_refill_ar              (o_lsu_dbg_wait_refill_ar  ),
    .o_dbg_wait_refill_r               (o_lsu_dbg_wait_refill_r   ),
    .o_dbg_wait_uncached               (o_lsu_dbg_wait_uncached   ),
    .o_dbg_wait_wb                     (o_lsu_dbg_wait_wb         )
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
                if_cop   ? cop_res    :
                i_muldiv ? muldiv_res :
                alu_res;
assign o_brch = i_brch && brch_res;

// ============================================================================
// Branch predictor: mispredict detection and recovery
// ============================================================================
wire actual_taken = (i_brch && brch_res) || i_jal || i_jalr;
wire is_control   = i_brch || i_jal || i_jalr;
wire [31:0] pred_target_full = {i_predict_target, 2'b00};
wire branch_resolve_fire = i_pre_valid && !i_flush && i_brch;
wire br_misp_pred_nt = branch_resolve_fire && brch_res && !i_predict_taken;
wire br_misp_pred_taken_nt = branch_resolve_fire && !brch_res && i_predict_taken;
wire br_misp_target_bad = branch_resolve_fire && brch_res && i_predict_taken && (pred_target_full != o_pc_next);
wire br_misp_pred_nt_btb_hit = br_misp_pred_nt && i_predict_btb_hit;
wire br_misp_pred_nt_btb_miss = br_misp_pred_nt && !i_predict_btb_hit;
wire br_misp_pred_taken_nt_btb_hit = br_misp_pred_taken_nt && i_predict_btb_hit;
wire br_misp_pred_taken_nt_btb_miss = br_misp_pred_taken_nt && !i_predict_btb_hit;

wire mispredict = (is_control && (i_predict_taken != actual_taken)) ||
                  ((i_jal || i_jalr || i_brch) && i_predict_taken && (pred_target_full != o_pc_next));

assign o_mispredict_flush = mispredict && i_pre_valid;
assign o_redirect_pc     = actual_taken ? o_pc_next : (i_pc + 32'd4);

wire predict_correct = !mispredict && is_control;
assign o_predict_correct = predict_correct && i_pre_valid;

`ifdef PERF_BRANCH_PRED
always @(posedge clock) begin
    if (!reset) begin
        if (br_misp_pred_nt) br_misp_pred_nt_dpic();
        if (br_misp_pred_taken_nt) br_misp_pred_taken_nt_dpic();
        if (br_misp_target_bad) br_misp_target_bad_dpic();
        if (br_misp_pred_nt_btb_hit) br_misp_pred_nt_btb_hit_dpic();
        if (br_misp_pred_nt_btb_miss) br_misp_pred_nt_btb_miss_dpic();
        if (br_misp_pred_taken_nt_btb_hit) br_misp_pred_taken_nt_btb_hit_dpic();
        if (br_misp_pred_taken_nt_btb_miss) br_misp_pred_taken_nt_btb_miss_dpic();
        if (branch_resolve_fire) begin
            branch_trace_dpic(i_pc,
                              {31'b0, i_predict_btb_hit},
                              {31'b0, i_predict_taken},
                              pred_target_full,
                              {31'b0, brch_res},
                              o_pc_next);
        end
    end
end
`endif

// ============================================================================
// BTB update (all conditional branches)
// Registered to capture stable values
// ============================================================================
reg        btb_update_en_r;
reg [31:0] btb_update_pc_r;
reg [29:0] btb_update_target_r;
reg        btb_update_taken_r;

wire btb_capture = i_brch && i_pre_valid && !i_flush;
wire [31:0] btb_target_raw = i_pc + i_imm;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        btb_update_en_r     <= 1'b0;
        btb_update_pc_r     <= 32'b0;
        btb_update_target_r <= 30'b0;
        btb_update_taken_r  <= 1'b0;
    end else if (btb_capture) begin
        btb_update_en_r     <= 1'b1;
        btb_update_pc_r     <= i_pc;
        btb_update_target_r <= btb_target_raw[31:2];
        btb_update_taken_r  <= brch_res;
    end else begin
        btb_update_en_r     <= 1'b0;
    end
end

assign o_btb_update_en     = btb_update_en_r;
assign o_btb_update_pc     = btb_update_pc_r;
assign o_btb_update_target = btb_update_target_r;
assign o_btb_update_taken  = btb_update_taken_r;

// ============================================================================
// RAS update (function calls and returns)
// ============================================================================
wire is_call = (i_jal || i_jalr) && (i_rd_addr == 5'd1);
wire is_ret  = i_jalr && (i_rd_addr == 5'd0) && (i_rs1_addr == 5'd1);
wire [31:0] ras_push_addr = i_pc + 32'd4;

assign o_ras_push_en   = is_call && i_pre_valid;
assign o_ras_push_data = ras_push_addr[31:2];
assign o_ras_pop_en    = is_ret && i_pre_valid;

endmodule
