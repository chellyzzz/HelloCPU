`include "perf_counters.vh"

module hcpu
(
    input                               clock                        ,
    input                               reset                      ,
    input                               io_interrupt               ,
  //     | AXI4 Master鎬荤嚎 |
    input                               io_master_awready          ,
    output                              io_master_awvalid          ,
    output             [  31:0]         io_master_awaddr           ,
    output             [   3:0]         io_master_awid             ,
    output             [   7:0]         io_master_awlen            ,
    output             [   2:0]         io_master_awsize           ,
    output             [   1:0]         io_master_awburst          ,
    input                               io_master_wready           ,
    output                              io_master_wvalid           ,
    output             [  31:0]         io_master_wdata            ,
    output             [   3:0]         io_master_wstrb            ,
    output                              io_master_wlast            ,
    output                              io_master_bready           ,
    input                               io_master_bvalid           ,
    input              [   1:0]         io_master_bresp            ,
    input              [   3:0]         io_master_bid              ,
    input                               io_master_arready          ,
    output                              io_master_arvalid          ,
    output             [  31:0]         io_master_araddr           ,
    output             [   3:0]         io_master_arid             ,
    output             [   7:0]         io_master_arlen            ,
    output             [   2:0]         io_master_arsize           ,
    output             [   1:0]         io_master_arburst          ,
    output                              io_master_rready           ,
    input                               io_master_rvalid           ,
    input              [   1:0]         io_master_rresp            ,
    input              [  31:0]         io_master_rdata            ,
    input                               io_master_rlast            ,
    input              [   3:0]         io_master_rid              ,
    //    | AXI4 Slave鎬荤嚎 |                   
    output                              io_slave_awready           ,
    input                               io_slave_awvalid           ,
    input              [  31:0]         io_slave_awaddr            ,
    input              [   3:0]         io_slave_awid              ,
    input              [   7:0]         io_slave_awlen             ,
    input              [   2:0]         io_slave_awsize            ,
    input              [   1:0]         io_slave_awburst           ,
    output                              io_slave_wready            ,
    input                               io_slave_wvalid            ,
    input              [  31:0]         io_slave_wdata             ,
    input              [   3:0]         io_slave_wstrb             ,
    input                               io_slave_wlast             ,
    input                               io_slave_bready            ,
    output                              io_slave_bvalid            ,
    output             [   1:0]         io_slave_bresp             ,
    output             [   3:0]         io_slave_bid               ,
    output                              io_slave_arready           ,
    input                               io_slave_arvalid           ,
    input              [  31:0]         io_slave_araddr            ,
    input              [   3:0]         io_slave_arid              ,
    input              [   7:0]         io_slave_arlen             ,
    input              [   2:0]         io_slave_arsize            ,
    input              [   1:0]         io_slave_arburst           ,
    input                               io_slave_rready            ,
    output                              io_slave_rvalid            ,
    output             [   1:0]         io_slave_rresp             ,
    output             [  31:0]         io_slave_rdata             ,
    output                              io_slave_rlast             ,
    output             [   3:0]         io_slave_rid
`ifdef COP_MEM_PENDING_KILL_TB
    ,input                              tb_cop_kill                ,
    output                              tb_cop_mem_bus_active      ,
    output                              tb_cop_mem_done            ,
    output                              tb_cop_mem_killed          ,
    output                              tb_cop_mem_resp_valid      ,
    output             [   1:0]         tb_cop_mem_state           ,
    output                              tb_cop_mem_store           ,
    output                              tb_cop_mem_aw_fire         ,
    output                              tb_cop_mem_w_fire          ,
    output                              tb_cop_mem_b_fire          ,
    output                              tb_cop_mem_ar_fire         ,
    output                              tb_cop_mem_r_fire          ,
    output             [  31:0]         tb_cop_mem_addr
`endif
`ifdef SCALAR_MEM_PENDING_KILL_TB
    ,input                              tb_scalar_flush            ,
    output                              tb_scalar_mem_req_valid    ,
    output                              tb_scalar_mem_resp_valid   ,
    output                              tb_scalar_mem_kill_pending ,
    output                              tb_scalar_mem_ar_fire      ,
    output                              tb_scalar_mem_r_fire       ,
    output             [  31:0]         tb_scalar_mem_addr
`endif

);
/*****************para************************/
localparam                              ISA_WIDTH = 32             ;
localparam                              REG_ADDR = 5               ;
localparam                              CSR_ADDR=12                ;

/******************global wires****************/
wire                                    rst_n_sync                 ;

wire                   [ISA_WIDTH-1:0]  imm,ins                    ;
wire                   [REG_ADDR-1:0]   idu_addr_rs1,idu_addr_rs2,idu_addr_rd;
wire                   [CSR_ADDR-1:0]   idu_csr_raddr              ;
wire                   [ISA_WIDTH-1:0]  rs1, rs2, wbu_rd_wdata     ;
wire                   [ISA_WIDTH-1:0]  dbg_s0, dbg_s1, dbg_s2     ;
wire                   [ISA_WIDTH-1:0]  dbg_s3, dbg_s4             ;
//csr wdata rd_wdata
wire                   [ISA_WIDTH-1:0]  csr_rd_wdata               ;

wire                   [ISA_WIDTH-1:0]  exu_res                    ;
wire                   [ISA_WIDTH-1:0]  scalar_exu_res             ;
wire                   [ISA_WIDTH-1:0]  cop_exu_res                ;
wire                                    exu_brch                   ;
wire                                    scalar_exu_brch            ;
//mret ecall
wire                   [ISA_WIDTH-1:0]  csr_rs2                    ;
// wire                   [ISA_WIDTH-1:0]  mcause, mstatus            ;
wire                   [ISA_WIDTH-1:0]  mepc, mtvec;

//load store
wire                   [3-1:0]          exu_opt                    ;
wire                   [   9:0]         alu_opt                    ;
wire                                    idu_wen, csr_wen, wbu_wen, wbu_csr_wen;
wire                   [ISA_WIDTH-1:0]  pc_next, ifu_pc_next       ;
wire                   [   1:0]         i_src_sel1                 ;
wire                   [   2:0]         i_src_sel2                 ;
wire                                    brch,jal,jalr              ;// idu -> pcu.
wire                                    ebreak                     ;
wire                                    if_store,if_load           ;// idu -> exu.
wire                                    ecall,mret                 ;// idu -> pcu.
wire                                    pc_update_en               ;
// branch predictor
wire                                    btb_predict_taken          ;
wire                   [  31:2]         btb_predict_target         ;
wire                                    btb_lookup_hit             ;
wire                                    ras_predict_valid          ;
wire                   [  31:2]         ras_predict_target         ;
wire                                    exu_mispredict_flush       ;
wire                   [  31:0]         exu_redirect_pc            ;
wire                                    exu_btb_update_en          ;
wire                   [  31:0]         exu_btb_update_pc          ;
wire                   [  31:2]         exu_btb_update_target      ;
wire                                    exu_btb_update_taken       ;
wire                                    exu_ras_push_en            ;
wire                   [  31:2]         exu_ras_push_data          ;
wire                                    exu_ras_pop_en             ;
wire                                    scalar_exu_mispredict_flush;
wire                   [  31:0]         scalar_exu_redirect_pc     ;
wire                                    scalar_exu_btb_update_en   ;
wire                   [  31:0]         scalar_exu_btb_update_pc   ;
wire                   [  31:2]         scalar_exu_btb_update_target;
wire                                    scalar_exu_btb_update_taken;
wire                                    scalar_exu_ras_push_en     ;
wire                   [  31:2]         scalar_exu_ras_push_data   ;
wire                                    scalar_exu_ras_pop_en      ;
// prediction through pipeline
wire                                    ifu_predict_taken          ;
wire                   [  31:2]         ifu_predict_target         ;
wire                                    ifu_predict_btb_hit        ;
wire                                    idu2exu_predict_taken      ;
wire                   [  31:2]         idu2exu_predict_target     ;
wire                                    idu2exu_predict_btb_hit    ;
wire                   [   4:0]         idu2exu_rs1_addr           ;
wire                                    exu2wbu_predict_taken      ;
wire                                    exu_predict_correct        ;
wire                                    exu2wbu_predict_correct    ;
wire                                    exu_wbu_valid              ;  // EXU-WBU register's own valid
// registered mispredict signals (stable for 1 full cycle)
reg                                     exu_mispredict_flush_r     ;
reg                    [  31:0]         exu_redirect_pc_r          ;
//
wire                                    ifu_fetch_ready            ;
wire                                    ifu2idu_valid, idu2ifu_ready;
wire                                    idu2exu_valid, exu2idu_ready;
wire                                    exu2wbu_valid, wbu2exu_ready;
wire                                    frontend_flush             ;
wire                                    exu_lsu_dbg_wait_start    ;
wire                                    exu_lsu_dbg_wait_hit      ;
wire                                    exu_lsu_dbg_wait_refill   ;
wire                                    exu_lsu_dbg_wait_refill_ar;
wire                                    exu_lsu_dbg_wait_refill_r ;
wire                                    exu_lsu_dbg_wait_uncached ;
wire                                    exu_lsu_dbg_wait_wb       ;
wire                                    scalar_mem_req_valid      ;
wire                                    scalar_mem_req_store      ;
wire                   [  31:0]         scalar_mem_req_addr       ;
wire                   [  31:0]         scalar_mem_req_wdata      ;
wire                   [   2:0]         scalar_mem_req_size       ;
wire                                    scalar_mem_resp_valid     ;
wire                   [  31:0]         scalar_mem_resp_rdata     ;
wire                                    scalar_mem_service_req_valid;
wire                                    scalar_mem_service_req_store;
wire                   [  31:0]         scalar_mem_service_req_addr;
wire                   [  31:0]         scalar_mem_service_req_wdata;
wire                   [   2:0]         scalar_mem_service_req_size;
wire                                    scalar_mem_service_resp_valid;
wire                   [  31:0]         scalar_mem_service_resp_rdata;
wire                                    mem_owner_scalar_active   ;
wire                                    mem_owner_cop_active      ;
wire                                    mem_service_req_valid     ;
wire                                    mem_service_req_store     ;
wire                   [  31:0]         mem_service_req_addr      ;
wire                   [  31:0]         mem_service_req_wdata     ;
wire                   [   2:0]         mem_service_req_size      ;
wire                                    mem_service_resp_valid    ;
wire                   [  31:0]         mem_service_resp_rdata    ;
wire                                    scalar_exu2wbu_valid       ;
wire                                    scalar_exu2idu_ready       ;
wire                                    cop_exu2wbu_valid          ;
wire                                    cop_exu2idu_ready          ;
wire                                    scalar_backend_commit_visible;
wire                                    cop_backend_commit_visible ;
wire                                    cop_backend_resp_fire      ;
wire                                    cop_backend_commit_fire    ;
//cache 
wire                   [ISA_WIDTH-1:0]  icache_ins                 ;
wire                   [ISA_WIDTH-1:0]  ifu_req_addr               ;
wire                                    icache_hit                 ;
wire                                    fence_i                    ;
wire                                    muldiv                     ;
wire                                    is_cop_insn                ;


//write address channel  
wire                   [  31:0]         LSU_SRAM_AXI_AWADDR        ;
wire                                    LSU_SRAM_AXI_AWVALID       ;
wire                                    LSU_SRAM_AXI_AWREADY       ;
wire                   [   7:0]         LSU_SRAM_AXI_AWLEN         ;
wire                   [   2:0]         LSU_SRAM_AXI_AWSIZE        ;
wire                   [   1:0]         LSU_SRAM_AXI_AWBURST       ;
wire                   [   3:0]         LSU_SRAM_AXI_AWID          ;
//write data channel
wire                                    LSU_SRAM_AXI_WVALID        ;
wire                                    LSU_SRAM_AXI_WREADY        ;
wire                   [  31:0]         LSU_SRAM_AXI_WDATA         ;
wire                   [   3:0]         LSU_SRAM_AXI_WSTRB         ;
wire                                    LSU_SRAM_AXI_WLAST         ;
//read data channel
wire                   [  31:0]         IFU_SRAM_AXI_RDATA         ;
wire                   [  31:0]         LSU_SRAM_AXI_RDATA         ;
wire                   [   1:0]         IFU_SRAM_AXI_RRESP, LSU_SRAM_AXI_RRESP;
wire                                    IFU_SRAM_AXI_RVALID, LSU_SRAM_AXI_RVALID;
wire                                    IFU_SRAM_AXI_RREADY, LSU_SRAM_AXI_RREADY;
wire                   [   3:0]         IFU_SRAM_AXI_RID,LSU_SRAM_AXI_RID;
wire                                    IFU_SRAM_AXI_RLAST,LSU_SRAM_AXI_RLAST;
//read address channel
wire                   [  31:0]         IFU_SRAM_AXI_ARADDR, LSU_SRAM_AXI_ARADDR;
wire                                    IFU_SRAM_AXI_ARVALID, LSU_SRAM_AXI_ARVALID;
wire                                    IFU_SRAM_AXI_ARREADY, LSU_SRAM_AXI_ARREADY;
wire                   [   3:0]         IFU_SRAM_AXI_ARID,LSU_SRAM_AXI_ARID;
wire                   [   7:0]         IFU_SRAM_AXI_ARLEN   ,LSU_SRAM_AXI_ARLEN;
wire                   [   2:0]         IFU_SRAM_AXI_ARSIZE  ,LSU_SRAM_AXI_ARSIZE;
wire                   [   1:0]         IFU_SRAM_AXI_ARBURST ,LSU_SRAM_AXI_ARBURST;
//write back channel
wire                   [   1:0]         LSU_SRAM_AXI_BRESP         ;
wire                                    LSU_SRAM_AXI_BVALID        ;
wire                                    LSU_SRAM_AXI_BREADY        ;
wire                   [   3:0]         LSU_SRAM_AXI_BID           ;
wire                                    COP_MEM_REQ_VALID          ;
wire                                    COP_MEM_REQ_STORE          ;
wire                   [  31:0]         COP_MEM_ADDR               ;
wire                   [  31:0]         COP_MEM_WDATA              ;
wire                   [   2:0]         COP_MEM_SIZE               ;
wire                                    COP_MEM_RESP_VALID         ;
wire                   [  31:0]         COP_MEM_RDATA              ;
wire                                    LSU_ARB_AXI_AWVALID        ;
wire                   [  31:0]         LSU_ARB_AXI_AWADDR         ;
wire                   [   3:0]         LSU_ARB_AXI_AWID           ;
wire                   [   7:0]         LSU_ARB_AXI_AWLEN          ;
wire                   [   2:0]         LSU_ARB_AXI_AWSIZE         ;
wire                   [   1:0]         LSU_ARB_AXI_AWBURST        ;
wire                                    LSU_ARB_AXI_WVALID         ;
wire                   [  31:0]         LSU_ARB_AXI_WDATA          ;
wire                   [   3:0]         LSU_ARB_AXI_WSTRB          ;
wire                                    LSU_ARB_AXI_WLAST          ;
wire                                    LSU_ARB_AXI_BREADY         ;
wire                                    LSU_ARB_AXI_ARVALID        ;
wire                   [  31:0]         LSU_ARB_AXI_ARADDR         ;
wire                   [   3:0]         LSU_ARB_AXI_ARID           ;
wire                   [   7:0]         LSU_ARB_AXI_ARLEN          ;
wire                   [   2:0]         LSU_ARB_AXI_ARSIZE         ;
wire                   [   1:0]         LSU_ARB_AXI_ARBURST        ;
wire                                    LSU_ARB_AXI_RREADY         ;
reg                    [   1:0]         cop_mem_state              ;
reg                                     cop_mem_wen_r              ;
reg                                     cop_mem_aw_done            ;
reg                                     cop_mem_w_done             ;
reg                                     cop_mem_killed_r           ;
reg                                     cop_mem_done_r             ;
reg                    [  31:0]         cop_mem_rdata_r            ;
reg                    [  31:0]         cop_mem_addr_r             ;
reg                    [  31:0]         cop_mem_wdata_r            ;
reg                    [   2:0]         cop_mem_size_r             ;
wire                                    cop_mem_new_req            ;
wire                                    cop_mem_aw_fire            ;
wire                                    cop_mem_w_fire             ;
wire                                    cop_mem_b_fire             ;
wire                                    cop_mem_ar_fire            ;
wire                                    cop_mem_r_fire             ;
wire                                    cop_mem_bus_active         ;
wire                                    cop_mem_resp_active        ;

//read data channel
wire                   [  31:0]         CLINT_AXI_RDATA            ;
wire                   [   1:0]         CLINT_AXI_RRESP            ;
wire                                    CLINT_AXI_RVALID           ;
wire                                    CLINT_AXI_RREADY           ;
wire                   [   3:0]         CLINT_AXI_RID              ;
wire                                    CLINT_AXI_RLAST            ;
    
//read adress channel
wire                                    CLINT_AXI_ARADDR           ;
wire                                    CLINT_AXI_ARVALID          ;
wire                                    CLINT_AXI_ARREADY          ;
wire                   [   3:0]         CLINT_AXI_ARID             ;
wire                   [   7:0]         CLINT_AXI_ARLEN            ;
wire                   [   2:0]         CLINT_AXI_ARSIZE           ;
wire                   [   1:0]         CLINT_AXI_ARBURST          ;


hcpu_stdrst u_stdrst(
    .clock                             (clock                     ),
    .i_rst_n                           (reset                     ),
    .o_rst_n_sync                      (rst_n_sync                ) 
);

wire                   [   4:0]         wbu_rd_addr                ;
wire                   [  11:0]         wbu_csr_addr               ;
wire [31:0] ifu2idu_ins;
wire [31:0] ifu2idu_pc;
wire        ifu2idu_predict_taken;
wire [31:2] ifu2idu_predict_target;
wire        ifu2idu_predict_btb_hit;
wire [4:0] ifu2idu_predecode_rd;
wire [4:0] ifu2idu_predecode_rs1_addr;
wire [4:0] ifu2idu_predecode_rs2_addr;
wire       ifu2idu_predecode_wen;
wire       ifu2idu_predecode_csr_wen;
wire       ifu2idu_predecode_load;
wire       ifu2idu_predecode_store;
wire       ifu2idu_predecode_brch;
wire       ifu2idu_predecode_jal;
wire       ifu2idu_predecode_jalr;
wire       ifu2idu_predecode_fence_i;
wire       ifu2idu_predecode_muldiv;
wire       ifu2idu_predecode_is_cop_insn;
wire       ifu2idu_predecode_ecall;
wire       ifu2idu_predecode_mret;
wire       ifu2idu_predecode_ebreak;

hcpu_CSR_RegisterFile Csrs(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_csr_wen                         (wbu_csr_wen               ),
    .i_ecall                           (ecall                     ),
    .i_mret                            (mret                      ),
    .i_pc                              (ifu2idu_pc                ),

    .i_csr_raddr                       (idu_csr_raddr             ),
    .o_csr_rdata                       (csr_rs2                   ),

    .i_csr_waddr                       (wbu_csr_addr              ),
    .i_csr_wdata                       (csr_rd_wdata              ),

    .o_mepc                            (mepc                      ),
    .o_mtvec                           (mtvec                     ) 
);
  

wire                   [  31:0]         idu2exu_pc                 ;
wire                   [  31:0]         idu2exu_ins                ;
wire                   [  31:0]         idu2exu_src1               ;
wire                   [  31:0]         idu2exu_src2               ;
wire                   [  31:0]         idu2exu_imm                ;
wire                   [   1:0]         idu2exu_src_sel1           ;
wire                   [   2:0]         idu2exu_src_sel2           ;
wire                   [   4:0]         idu2exu_rd                 ;
wire                   [   2:0]         idu2exu_exu_opt            ;
wire                   [   9:0]         idu2exu_alu_opt            ;
wire                                    idu2exu_wen                ;
wire                                    idu2exu_csr_wen            ;
wire                                    idu2exu_mret               ;
wire                                    idu2exu_ecall              ;
wire                                    idu2exu_load               ;
wire                                    idu2exu_store              ;
wire                                    idu2exu_brch               ;
wire                                    idu2exu_jal                ;
wire                                    idu2exu_jalr               ;
wire                                    idu2exu_ebreak             ;
wire                                    idu2exu_fence_i            ;
wire                                    idu2exu_muldiv             ;
wire                                    idu2exu_is_cop_insn        ;
wire                   [  11:0]         idu2exu_csr_addr           ;

hcpu_icache icache1(
    .clock                             (clock                     ),
    .rst_n_sync                        (rst_n_sync                ),
    .addr                              (ifu_req_addr              ),
    .data                              (icache_ins                ),
    .hit                               (icache_hit                ),
    .fence_i                           (idu2exu_fence_i           ),
  //read data channel
    .M_AXI_RDATA                       (IFU_SRAM_AXI_RDATA        ),
    .M_AXI_RRESP                       (IFU_SRAM_AXI_RRESP        ),
    .M_AXI_RVALID                      (IFU_SRAM_AXI_RVALID       ),
    .M_AXI_RREADY                      (IFU_SRAM_AXI_RREADY       ),
    .M_AXI_RID                         (IFU_SRAM_AXI_RID          ),
    .M_AXI_RLAST                       (IFU_SRAM_AXI_RLAST        ),
  //read adress channel
    .M_AXI_ARADDR                      (IFU_SRAM_AXI_ARADDR       ),
    .M_AXI_ARVALID                     (IFU_SRAM_AXI_ARVALID      ),
    .M_AXI_ARREADY                     (IFU_SRAM_AXI_ARREADY      ),
    .M_AXI_ARID                        (IFU_SRAM_AXI_ARID         ),
    .M_AXI_ARLEN                       (IFU_SRAM_AXI_ARLEN        ),
    .M_AXI_ARSIZE                      (IFU_SRAM_AXI_ARSIZE       ),
    .M_AXI_ARBURST                     (IFU_SRAM_AXI_ARBURST      )
);

// ============================================================================
// Branch predictor: BTB + RAS
// ============================================================================
hcpu_btb btb1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .lookup_pc                         (ifu_pc_next               ),
    .predict_taken                     (btb_predict_taken         ),
    .predict_target                    (btb_predict_target        ),
    .lookup_hit                        (btb_lookup_hit            ),
    .update_en                         (exu_btb_update_en         ),
    .update_pc                         (exu_btb_update_pc         ),
    .update_target                     (exu_btb_update_target     ),
    .update_taken                      (exu_btb_update_taken      )
);

hcpu_ras ras1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .push_en                           (exu_ras_push_en           ),
    .push_data                         (exu_ras_push_data         ),
    .pop_en                            (exu_ras_pop_en            ),
    .predict_valid                     (ras_predict_valid         ),
    .predict_target                    (ras_predict_target        )
);

hcpu_IFU ifu1
(
    .i_pc_next                         (pc_next                   ),
    .clock                             (clock                     ),
    .rst_n_sync                        (rst_n_sync                ),
    .i_pc_update                       (pc_update_en              ),
    .ins                               (ins                       ),
  //ifu -> idu handshake
    .i_post_ready                      (ifu_fetch_ready           ),
    .pc_next                           (ifu_pc_next               ),
  //cache -> ifu
    .hit                               (icache_hit                ),
    .icache_ins                        (icache_ins                ),
    .req_addr                          (ifu_req_addr              ),
  // branch predictor
    .btb_predict_taken                 (btb_predict_taken         ),
    .btb_predict_target                (btb_predict_target        ),
    .btb_lookup_hit                    (btb_lookup_hit            ),
    .ras_predict_valid                 (ras_predict_valid         ),
    .ras_predict_target                (ras_predict_target        ),
  // mispredict recovery
    .exu_mispredict_flush              (exu_mispredict_flush       ),
    .exu_redirect_pc                   (exu_redirect_pc            ),
  // prediction outputs to pipeline
    .o_predict_taken                   (ifu_predict_taken         ),
    .o_predict_target                  (ifu_predict_target        ),
    .o_predict_btb_hit                 (ifu_predict_btb_hit       )
);

hcpu_ifu_fetch_queue ifu_fetch_queue(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .flush                             (frontend_flush            ),
    .i_enq_valid                       (icache_hit                ),
    .o_enq_ready                       (ifu_fetch_ready           ),
    .i_pc                              (ifu_pc_next               ),
    .i_ins                             (ins                       ),
    .i_predict_taken                   (ifu_predict_taken         ),
    .i_predict_target                  (ifu_predict_target        ),
    .i_predict_btb_hit                 (ifu_predict_btb_hit       ),
    .i_deq_ready                       (idu2ifu_ready             ),
    .o_deq_valid                       (ifu2idu_valid             ),
    .o_pc                              (ifu2idu_pc                ),
    .o_ins                             (ifu2idu_ins               ),
    .o_predict_taken                   (ifu2idu_predict_taken     ),
    .o_predict_target                  (ifu2idu_predict_target    ),
    .o_predict_btb_hit                 (ifu2idu_predict_btb_hit   ),
    .o_predecode_rd                    (ifu2idu_predecode_rd      ),
    .o_predecode_rs1_addr              (ifu2idu_predecode_rs1_addr),
    .o_predecode_rs2_addr              (ifu2idu_predecode_rs2_addr),
    .o_predecode_wen                   (ifu2idu_predecode_wen     ),
    .o_predecode_csr_wen               (ifu2idu_predecode_csr_wen ),
    .o_predecode_load                  (ifu2idu_predecode_load    ),
    .o_predecode_store                 (ifu2idu_predecode_store   ),
    .o_predecode_brch                  (ifu2idu_predecode_brch    ),
    .o_predecode_jal                   (ifu2idu_predecode_jal     ),
    .o_predecode_jalr                  (ifu2idu_predecode_jalr    ),
    .o_predecode_fence_i               (ifu2idu_predecode_fence_i ),
    .o_predecode_muldiv                (ifu2idu_predecode_muldiv  ),
    .o_predecode_is_cop_insn           (ifu2idu_predecode_is_cop_insn),
    .o_predecode_ecall                 (ifu2idu_predecode_ecall   ),
    .o_predecode_mret                  (ifu2idu_predecode_mret    ),
    .o_predecode_ebreak                (ifu2idu_predecode_ebreak  )
);

hcpu_IDU idu1(
    .clock                             (clock                     ),
    .ins                               (ifu2idu_ins               ),
    .reset                             (reset                     ),

    .o_imm                             (imm                       ),
    .o_rd                              (idu_addr_rd               ),
    .o_rs1                             (idu_addr_rs1              ),
    .o_rs2                             (idu_addr_rs2              ),
    .o_csr_addr                        (idu_csr_raddr             ),
    .o_exu_opt                         (exu_opt                   ),
    .o_alu_opt                         (alu_opt                   ),
    .o_wen                             (idu_wen                   ),
    .o_csr_wen                         (csr_wen                   ),
    .o_src_sel1                        (i_src_sel1                ),
    .o_src_sel2                        (i_src_sel2                ),
    .o_ecall                           (ecall                     ),
    .o_mret                            (mret                      ),
    .o_load                            (if_load                   ),
    .o_store                           (if_store                  ),
    .o_brch                            (brch                      ),
    .o_jal                             (jal                       ),
    .o_jalr                            (jalr                      ),
    .o_ebreak                          (ebreak                    ),
    .o_fence_i                         (fence_i                   ),
    .o_muldiv                          (muldiv                    ),
    .o_is_cop_insn                     (is_cop_insn               )
);

`ifndef SYNTHESIS
always @(*) begin
    if (ifu2idu_valid) begin
        if (ifu2idu_predecode_rd != idu_addr_rd)
            $fatal(1, "hcpu predecode rd mismatch vs IDU decode");
        if (ifu2idu_predecode_rs1_addr != idu_addr_rs1)
            $fatal(1, "hcpu predecode rs1 mismatch vs IDU decode");
        if (ifu2idu_predecode_rs2_addr != idu_addr_rs2)
            $fatal(1, "hcpu predecode rs2 mismatch vs IDU decode");
        if (ifu2idu_predecode_wen != idu_wen)
            $fatal(1, "hcpu predecode wen mismatch vs IDU decode");
        if (ifu2idu_predecode_csr_wen != csr_wen)
            $fatal(1, "hcpu predecode csr_wen mismatch vs IDU decode");
        if (ifu2idu_predecode_load != if_load)
            $fatal(1, "hcpu predecode load mismatch vs IDU decode");
        if (ifu2idu_predecode_store != if_store)
            $fatal(1, "hcpu predecode store mismatch vs IDU decode");
        if (ifu2idu_predecode_brch != brch)
            $fatal(1, "hcpu predecode branch mismatch vs IDU decode");
        if (ifu2idu_predecode_jal != jal)
            $fatal(1, "hcpu predecode jal mismatch vs IDU decode");
        if (ifu2idu_predecode_jalr != jalr)
            $fatal(1, "hcpu predecode jalr mismatch vs IDU decode");
        if (ifu2idu_predecode_fence_i != fence_i)
            $fatal(1, "hcpu predecode fence.i mismatch vs IDU decode");
        if (ifu2idu_predecode_muldiv != muldiv)
            $fatal(1, "hcpu predecode muldiv mismatch vs IDU decode");
        if (ifu2idu_predecode_is_cop_insn != is_cop_insn)
            $fatal(1, "hcpu predecode cop mismatch vs IDU decode");
        if (ifu2idu_predecode_ecall != ecall)
            $fatal(1, "hcpu predecode ecall mismatch vs IDU decode");
        if (ifu2idu_predecode_mret != mret)
            $fatal(1, "hcpu predecode mret mismatch vs IDU decode");
        if (ifu2idu_predecode_ebreak != ebreak)
            $fatal(1, "hcpu predecode ebreak mismatch vs IDU decode");
    end
end
`endif


hcpu_idu_exu_regs idu2exu_regs(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .flush                             (frontend_flush            ),
    .i_pre_valid                       (ifu2idu_valid             ),
    .i_post_ready                      (exu2idu_ready             ),
    .o_pre_ready                       (idu2ifu_ready             ),
    .o_post_valid                      (idu2exu_valid             ),

    .i_pc                              (ifu2idu_pc                ),
    .i_ins                             (ifu2idu_ins               ),
    .i_imm                             (imm                       ),
    .i_csr_addr                        (idu_csr_raddr             ),
    .i_src1                            (rs1                       ),
    .i_src2                            (rs2                       ),
    //mepc mtvec
    .i_mepc                            (mepc                      ),
    .i_mtvec                           (mtvec                     ),
    //
    .i_rd                              (idu_addr_rd               ),
    .i_csr_rs2                         (csr_rs2                   ),
    .i_csr_src_sel                     (csr_wen                   ),
    .i_exu_opt                         (exu_opt                   ),
    .i_alu_opt                         (alu_opt                   ),

    .i_wen                             (idu_wen                   ),
    .i_csr_wen                         (csr_wen                   ),
    .i_src_sel1                        (i_src_sel1                ),
    .i_src_sel2                        (i_src_sel2                ),
    .i_mret                            (mret                      ),
    .i_ecall                           (ecall                     ),
    .i_load                            (if_load                   ),
    .i_store                           (if_store                  ),
    .i_brch                            (brch                      ),
    .i_jal                             (jal                       ),
    .i_jalr                            (jalr                      ),
    .i_fence_i                         (fence_i                   ),
    .i_muldiv                          (muldiv                    ),
    .i_ebreak                          (ebreak                    ),
    .i_is_cop_insn                     (is_cop_insn               ),

    .i_predict_taken                   (ifu2idu_predict_taken     ),
    .i_predict_target                  (ifu2idu_predict_target    ),
    .i_predict_btb_hit                 (ifu2idu_predict_btb_hit   ),
    .i_rs1_addr                        (idu_addr_rs1              ),
    
    .o_pc                              (idu2exu_pc                ),
    .o_ins                             (idu2exu_ins               ),
    .o_src1                            (idu2exu_src1              ),
    .o_src2                            (idu2exu_src2              ),
    .o_imm                             (idu2exu_imm               ),
    .o_src_sel1                        (idu2exu_src_sel1          ),
    .o_src_sel2                        (idu2exu_src_sel2          ),
    .o_rd                              (idu2exu_rd                ),
    .o_exu_opt                         (idu2exu_exu_opt           ),
    .o_alu_opt                         (idu2exu_alu_opt           ),
    .o_wen                             (idu2exu_wen               ),

    .o_csr_wen                         (idu2exu_csr_wen           ),
    .o_mret                            (idu2exu_mret              ),
    .o_ecall                           (idu2exu_ecall             ),
    .o_load                            (idu2exu_load              ),
    .o_store                           (idu2exu_store             ),
    .o_brch                            (idu2exu_brch              ),
    .o_jal                             (idu2exu_jal               ),
    .o_jalr                            (idu2exu_jalr              ),
    .o_ebreak                          (idu2exu_ebreak            ),
    .o_fence_i                         (idu2exu_fence_i           ),
    .o_muldiv                          (idu2exu_muldiv            ),
    .o_is_cop_insn                     (idu2exu_is_cop_insn       ),
    //
    .o_csr_addr                        (idu2exu_csr_addr          ),
    .o_predict_taken                   (idu2exu_predict_taken     ),
    .o_predict_target                  (idu2exu_predict_target    ),
    .o_predict_btb_hit                 (idu2exu_predict_btb_hit   ),
    .o_rs1_addr                        (idu2exu_rs1_addr          )
);

wire                   [  31:0]         exu_pc_next                ;
wire                   [  31:0]         exu_commit_pc_next         ;
wire                   [  31:0]         scalar_exu_pc_next         ;
wire                   [  31:0]         cop_active_pc              ;
wire                   [  31:0]         cop_active_src1            ;
wire                   [  31:0]         cop_active_src2            ;
wire                                    scalar_exu_predict_correct ;
wire                                    scalar_issue               ;
wire                                    cop_decode_active          ;
wire                                    cop_issue_valid            ;
wire                                    cop_issue                  ;
wire                                    cop_issue_ready            ;
wire                                    cop_issue_active           ;
wire                                    cop_commit_active          ;
wire                                    cop_pipeline_active        ;
wire                                    cop_refetch_flush          ;
wire                                    cop_inflight               ;
wire                                    cop_backend_busy           ;
wire                   [  31:0]         cop_inflight_pc            ;
wire                   [  31:0]         cop_active_ins             ;
wire                   [   4:0]         cop_inflight_rd            ;
wire                                    cop_inflight_wen           ;
wire                                    cop_kill                   ;
wire                                    cop_queue_dequeue          ;
wire                                    cop_resp_fire              ;
wire                                    scalar_flush_test          ;

assign cop_decode_active = idu2exu_is_cop_insn;
assign scalar_flush_test =
`ifdef SCALAR_MEM_PENDING_KILL_TB
                           tb_scalar_flush
`else
                           1'b0
`endif
                           ;
assign cop_issue_valid = cop_decode_active && !cop_inflight && !cop_backend_busy;
assign cop_issue_active = cop_decode_active;
assign cop_commit_active = cop_inflight;
assign cop_pipeline_active = cop_commit_active || cop_issue_active;
assign cop_mem_bus_active = (cop_mem_state != 2'd0);
assign cop_mem_resp_active = cop_mem_bus_active || cop_mem_done_r;
assign scalar_mem_service_req_valid = scalar_mem_req_valid;
assign scalar_mem_service_req_store = scalar_mem_req_store;
assign scalar_mem_service_req_addr = scalar_mem_req_addr;
assign scalar_mem_service_req_wdata = scalar_mem_req_wdata;
assign scalar_mem_service_req_size = scalar_mem_req_size;
assign scalar_mem_service_resp_valid = scalar_mem_resp_valid;
assign scalar_mem_service_resp_rdata = scalar_mem_resp_rdata;
assign mem_owner_cop_active = cop_mem_bus_active;
assign mem_owner_scalar_active = !mem_owner_cop_active && scalar_mem_service_req_valid;
assign mem_service_req_valid = mem_owner_cop_active ? 1'b1 : scalar_mem_service_req_valid;
assign mem_service_req_store = mem_owner_cop_active ? cop_mem_wen_r : scalar_mem_service_req_store;
assign mem_service_req_addr = mem_owner_cop_active ? cop_mem_addr_r : scalar_mem_service_req_addr;
assign mem_service_req_wdata = mem_owner_cop_active ? cop_mem_wdata_r : scalar_mem_service_req_wdata;
assign mem_service_req_size = mem_owner_cop_active ? cop_mem_size_r : scalar_mem_service_req_size;
assign mem_service_resp_valid = cop_mem_resp_active ? (cop_mem_done_r && !cop_mem_killed_r) : scalar_mem_service_resp_valid;
assign mem_service_resp_rdata = cop_mem_resp_active ? cop_mem_rdata_r : scalar_mem_service_resp_rdata;
assign scalar_issue = idu2exu_valid && !idu2exu_is_cop_insn && !cop_pipeline_active;
assign cop_refetch_flush = cop_backend_commit_fire;
assign cop_active_pc = cop_commit_active ? cop_inflight_pc : idu2exu_pc;
assign exu_res = cop_pipeline_active ? cop_exu_res : scalar_exu_res;
assign exu_brch = scalar_exu_brch;
assign exu_pc_next = scalar_exu_pc_next;
assign exu_commit_pc_next = cop_pipeline_active ? (cop_active_pc + 32'd4) :
                            (idu2exu_brch ? exu_redirect_pc : exu_pc_next);
assign exu_mispredict_flush = scalar_exu_mispredict_flush || cop_refetch_flush;
assign exu_predict_correct = cop_pipeline_active ? 1'b1 : scalar_exu_predict_correct;
assign exu_redirect_pc = cop_refetch_flush ? (cop_inflight_pc + 32'd4) : scalar_exu_redirect_pc;
assign exu_btb_update_en = scalar_exu_btb_update_en;
assign exu_btb_update_pc = scalar_exu_btb_update_pc;
assign exu_btb_update_target = scalar_exu_btb_update_target;
assign exu_btb_update_taken = scalar_exu_btb_update_taken;
assign exu_ras_push_en = scalar_exu_ras_push_en;
assign exu_ras_push_data = scalar_exu_ras_push_data;
assign exu_ras_pop_en = scalar_exu_ras_pop_en;
assign scalar_backend_commit_visible = scalar_exu2wbu_valid;
assign cop_backend_commit_visible = cop_exu2wbu_valid;
assign exu2wbu_valid = cop_commit_active ? cop_backend_commit_visible :
                       idu2exu_is_cop_insn ? 1'b0 : scalar_backend_commit_visible;
assign exu2idu_ready = cop_pipeline_active ? 1'b0 : scalar_exu2idu_ready;
assign cop_kill = idu2exu_fence_i || exu_mispredict_flush_r
`ifdef COP_MEM_PENDING_KILL_TB
                || tb_cop_kill
`endif
                ;
assign cop_backend_resp_fire = cop_backend_commit_visible && wbu2exu_ready;
assign cop_backend_commit_fire = cop_backend_resp_fire;
assign cop_resp_fire = cop_backend_commit_fire;
assign cop_queue_dequeue = cop_backend_commit_fire;
assign frontend_flush = pc_update_en || idu2exu_fence_i || exu_mispredict_flush;

hcpu_idu_cop_regs idu2cop_regs(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_issue_valid                     (cop_issue_valid           ),
    .i_kill                            (cop_kill                  ),
    .i_dequeue                         (cop_queue_dequeue         ),
    .i_backend_busy                    (cop_backend_busy          ),
    .i_pc                              (idu2exu_pc                ),
    .i_ins                             (idu2exu_ins               ),
    .i_src1                            (idu2exu_src1              ),
    .i_src2                            (idu2exu_src2              ),
    .i_rd                              (idu2exu_rd                ),
    .i_wen                             (idu2exu_wen               ),
    .o_inflight                        (cop_inflight              ),
    .o_issue_ready                     (cop_issue_ready           ),
    .o_issue_fire                      (cop_issue                 ),
    .o_pc                              (cop_inflight_pc           ),
    .o_ins                             (cop_active_ins            ),
    .o_active_src1                     (cop_active_src1           ),
    .o_active_src2                     (cop_active_src2           ),
    .o_rd                              (cop_inflight_rd           ),
    .o_wen                             (cop_inflight_wen          )
);

hcpu_EXU exu1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_src1                            (idu2exu_src1              ),
    .i_src2                            (idu2exu_src2              ),
    .i_imm                             (idu2exu_imm               ),
    .i_pc                              (idu2exu_pc                ),
    .i_src_sel1                         (idu2exu_src_sel1           ), 
    .i_src_sel2                         (idu2exu_src_sel2           ),
    //control signal
    .i_load                            (idu2exu_load              ),
    .i_store                           (idu2exu_store             ),
    .i_brch                            (idu2exu_brch              ),
    .i_jal                             (idu2exu_jal               ),
    .i_jalr                            (idu2exu_jalr              ),
    //
    .i_ecall                           (idu2exu_ecall             ),
    .i_mret                            (idu2exu_mret              ),

    .exu_opt                           (idu2exu_exu_opt           ),
    .i_alu_opt                         (idu2exu_alu_opt           ),
    .i_muldiv                          (idu2exu_muldiv            ),
    .i_is_cop_insn                     (1'b0                      ),
    .i_predict_taken                   (idu2exu_predict_taken     ),
    .i_predict_target                  (idu2exu_predict_target    ),
    .i_predict_btb_hit                 (idu2exu_predict_btb_hit   ),
    .i_rd_addr                         (idu2exu_rd                ),
    .i_rs1_addr                        (idu2exu_rs1_addr          ),
    .o_res                             (scalar_exu_res            ),
    .o_brch                            (scalar_exu_brch           ),
    .o_pc_next                         (scalar_exu_pc_next        ),
    .o_mispredict_flush                (scalar_exu_mispredict_flush),
    .o_predict_correct                 (scalar_exu_predict_correct),
    .o_redirect_pc                     (scalar_exu_redirect_pc    ),
    .o_btb_update_en                   (scalar_exu_btb_update_en  ),
    .o_btb_update_pc                   (scalar_exu_btb_update_pc  ),
    .o_btb_update_target               (scalar_exu_btb_update_target),
    .o_btb_update_taken                (scalar_exu_btb_update_taken),
    .o_ras_push_en                     (scalar_exu_ras_push_en    ),
    .o_ras_push_data                   (scalar_exu_ras_push_data  ),
    .o_ras_pop_en                      (scalar_exu_ras_pop_en     ),
  //lsu -> sram axi
  //write address channel  
    .M_AXI_AWADDR                      (LSU_SRAM_AXI_AWADDR       ),
    .M_AXI_AWVALID                     (LSU_SRAM_AXI_AWVALID      ),
    .M_AXI_AWREADY                     (LSU_SRAM_AXI_AWREADY      ),
    .M_AXI_AWLEN                       (LSU_SRAM_AXI_AWLEN        ),
    .M_AXI_AWSIZE                      (LSU_SRAM_AXI_AWSIZE       ),
    .M_AXI_AWBURST                     (LSU_SRAM_AXI_AWBURST      ),
    .M_AXI_AWID                        (LSU_SRAM_AXI_AWID         ),
  //write data channel
    .M_AXI_WVALID                      (LSU_SRAM_AXI_WVALID       ),
    .M_AXI_WREADY                      (LSU_SRAM_AXI_WREADY       ),
    .M_AXI_WDATA                       (LSU_SRAM_AXI_WDATA        ),
    .M_AXI_WSTRB                       (LSU_SRAM_AXI_WSTRB        ),
    .M_AXI_WLAST                       (LSU_SRAM_AXI_WLAST        ),
  //read data channel
    .M_AXI_RDATA                       (LSU_SRAM_AXI_RDATA        ),
    .M_AXI_RRESP                       (LSU_SRAM_AXI_RRESP        ),
    .M_AXI_RVALID                      (LSU_SRAM_AXI_RVALID       ),
    .M_AXI_RREADY                      (LSU_SRAM_AXI_RREADY       ),
    .M_AXI_RID                         (LSU_SRAM_AXI_RID          ),
    .M_AXI_RLAST                       (LSU_SRAM_AXI_RLAST        ),
  //read address channel
    .M_AXI_ARADDR                      (LSU_SRAM_AXI_ARADDR       ),
    .M_AXI_ARVALID                     (LSU_SRAM_AXI_ARVALID      ),
    .M_AXI_ARREADY                     (LSU_SRAM_AXI_ARREADY      ),
    .M_AXI_ARID                        (LSU_SRAM_AXI_ARID         ),
    .M_AXI_ARLEN                       (LSU_SRAM_AXI_ARLEN        ),
    .M_AXI_ARSIZE                      (LSU_SRAM_AXI_ARSIZE       ),
    .M_AXI_ARBURST                     (LSU_SRAM_AXI_ARBURST      ),
  //write back channel
    .M_AXI_BRESP                       (LSU_SRAM_AXI_BRESP        ),
    .M_AXI_BVALID                      (LSU_SRAM_AXI_BVALID       ),
    .M_AXI_BREADY                      (LSU_SRAM_AXI_BREADY       ),
    .M_AXI_BID                         (LSU_SRAM_AXI_BID          ),
    .o_lsu_dbg_wait_start              (exu_lsu_dbg_wait_start    ),
    .o_lsu_dbg_wait_hit                (exu_lsu_dbg_wait_hit      ),
    .o_lsu_dbg_wait_refill             (exu_lsu_dbg_wait_refill   ),
    .o_lsu_dbg_wait_refill_ar          (exu_lsu_dbg_wait_refill_ar),
    .o_lsu_dbg_wait_refill_r           (exu_lsu_dbg_wait_refill_r ),
    .o_lsu_dbg_wait_uncached           (exu_lsu_dbg_wait_uncached ),
    .o_lsu_dbg_wait_wb                 (exu_lsu_dbg_wait_wb       ),
    .o_mem_req_valid                   (scalar_mem_req_valid      ),
    .o_mem_req_store                   (scalar_mem_req_store      ),
    .o_mem_req_addr                    (scalar_mem_req_addr       ),
    .o_mem_req_wdata                   (scalar_mem_req_wdata      ),
    .o_mem_req_size                    (scalar_mem_req_size       ),
    .o_mem_resp_valid                  (scalar_mem_resp_valid     ),
    .o_mem_resp_rdata                  (scalar_mem_resp_rdata     ),
  //exu -> wbu handshake
    .i_pre_valid                       (scalar_issue              ),
    .i_post_ready                      (wbu2exu_ready             ),
    .o_post_valid                      (scalar_exu2wbu_valid      ),
    .o_pre_ready                       (scalar_exu2idu_ready      ),
    .i_flush                           (exu_mispredict_flush_r || scalar_flush_test) 
);

hcpu_cop_backend cop_backend1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_pre_valid                       (cop_issue                 ),
    .i_post_ready                      (wbu2exu_ready             ),
    .i_flush                           (cop_kill                  ),
    .i_src1                            (cop_active_src1           ),
    .i_src2                            (cop_active_src2           ),
    .i_ins                             (cop_active_ins            ),
    .o_cop_mem_req_valid               (COP_MEM_REQ_VALID         ),
    .o_cop_mem_req_store               (COP_MEM_REQ_STORE         ),
    .o_cop_mem_req_addr                (COP_MEM_ADDR              ),
    .o_cop_mem_req_wdata               (COP_MEM_WDATA             ),
    .o_cop_mem_req_size                (COP_MEM_SIZE              ),
    .i_cop_mem_resp_valid              (COP_MEM_RESP_VALID        ),
    .i_cop_mem_resp_rdata              (COP_MEM_RDATA             ),
    .o_pre_ready                       (cop_exu2idu_ready         ),
    .o_post_valid                      (cop_exu2wbu_valid         ),
    .o_busy                            (cop_backend_busy          ),
    .o_res                             (cop_exu_res               )
);

assign LSU_ARB_AXI_AWADDR  = cop_mem_bus_active ? mem_service_req_addr : LSU_SRAM_AXI_AWADDR;
assign LSU_ARB_AXI_AWVALID = (cop_mem_state == 2'd1) ? (cop_mem_wen_r && !cop_mem_aw_done) : LSU_SRAM_AXI_AWVALID;
assign LSU_ARB_AXI_AWID    = cop_mem_bus_active ? 4'b0 : LSU_SRAM_AXI_AWID;
assign LSU_ARB_AXI_AWLEN   = cop_mem_bus_active ? 8'b0 : LSU_SRAM_AXI_AWLEN;
assign LSU_ARB_AXI_AWSIZE  = cop_mem_bus_active ? mem_service_req_size : LSU_SRAM_AXI_AWSIZE;
assign LSU_ARB_AXI_AWBURST = cop_mem_bus_active ? 2'b00 : LSU_SRAM_AXI_AWBURST;
assign LSU_ARB_AXI_WDATA   = cop_mem_bus_active ? mem_service_req_wdata : LSU_SRAM_AXI_WDATA;
assign LSU_ARB_AXI_WSTRB   = cop_mem_bus_active ? 4'b0001 : LSU_SRAM_AXI_WSTRB;
assign LSU_ARB_AXI_WVALID  = (cop_mem_state == 2'd1) ? (cop_mem_wen_r && !cop_mem_w_done) : LSU_SRAM_AXI_WVALID;
assign LSU_ARB_AXI_WLAST   = cop_mem_bus_active ? 1'b1 : LSU_SRAM_AXI_WLAST;
assign LSU_ARB_AXI_BREADY  = (cop_mem_state == 2'd2 || cop_mem_state == 2'd3) ? cop_mem_wen_r : LSU_SRAM_AXI_BREADY;
assign LSU_ARB_AXI_ARADDR  = cop_mem_bus_active ? mem_service_req_addr : LSU_SRAM_AXI_ARADDR;
assign LSU_ARB_AXI_ARVALID = (cop_mem_state == 2'd1) ? !cop_mem_wen_r : LSU_SRAM_AXI_ARVALID;
assign LSU_ARB_AXI_ARID    = cop_mem_bus_active ? 4'b0 : LSU_SRAM_AXI_ARID;
assign LSU_ARB_AXI_ARLEN   = cop_mem_bus_active ? 8'b0 : LSU_SRAM_AXI_ARLEN;
assign LSU_ARB_AXI_ARSIZE  = cop_mem_bus_active ? mem_service_req_size : LSU_SRAM_AXI_ARSIZE;
assign LSU_ARB_AXI_ARBURST = cop_mem_bus_active ? 2'b00 : LSU_SRAM_AXI_ARBURST;
assign LSU_ARB_AXI_RREADY  = (cop_mem_state == 2'd2 || cop_mem_state == 2'd3) ? !cop_mem_wen_r : LSU_SRAM_AXI_RREADY;
assign COP_MEM_RESP_VALID  = cop_mem_done_r && !cop_mem_killed_r;
assign COP_MEM_RDATA       = mem_service_resp_rdata;
assign cop_mem_new_req     = COP_MEM_REQ_VALID && (cop_mem_state == 2'd0) && !cop_mem_done_r && !mem_owner_scalar_active;
assign cop_mem_aw_fire     = LSU_ARB_AXI_AWVALID && LSU_SRAM_AXI_AWREADY;
assign cop_mem_w_fire      = LSU_ARB_AXI_WVALID && LSU_SRAM_AXI_WREADY;
assign cop_mem_b_fire      = LSU_ARB_AXI_BREADY && LSU_SRAM_AXI_BVALID;
assign cop_mem_ar_fire     = LSU_ARB_AXI_ARVALID && LSU_SRAM_AXI_ARREADY;
assign cop_mem_r_fire      = LSU_ARB_AXI_RREADY && LSU_SRAM_AXI_RVALID && LSU_SRAM_AXI_RLAST;

`ifdef COP_MEM_PENDING_KILL_TB
assign tb_cop_mem_bus_active = cop_mem_bus_active;
assign tb_cop_mem_done = cop_mem_done_r;
assign tb_cop_mem_killed = cop_mem_killed_r;
assign tb_cop_mem_resp_valid = COP_MEM_RESP_VALID;
assign tb_cop_mem_state = cop_mem_state;
assign tb_cop_mem_store = cop_mem_wen_r;
assign tb_cop_mem_aw_fire = cop_mem_bus_active && cop_mem_aw_fire;
assign tb_cop_mem_w_fire = cop_mem_bus_active && cop_mem_w_fire;
assign tb_cop_mem_b_fire = cop_mem_bus_active && cop_mem_b_fire;
assign tb_cop_mem_ar_fire = cop_mem_bus_active && cop_mem_ar_fire;
assign tb_cop_mem_r_fire = cop_mem_bus_active && cop_mem_r_fire;
assign tb_cop_mem_addr = cop_mem_addr_r;
`endif

`ifdef SCALAR_MEM_PENDING_KILL_TB
assign tb_scalar_mem_req_valid = scalar_mem_req_valid;
assign tb_scalar_mem_resp_valid = scalar_mem_resp_valid;
assign tb_scalar_mem_kill_pending = exu1.lsu_kill_pending;
assign tb_scalar_mem_ar_fire = !cop_mem_bus_active && LSU_ARB_AXI_ARVALID && LSU_SRAM_AXI_ARREADY;
assign tb_scalar_mem_r_fire = !cop_mem_resp_active && LSU_ARB_AXI_RREADY && LSU_SRAM_AXI_RVALID && LSU_SRAM_AXI_RLAST;
assign tb_scalar_mem_addr = scalar_mem_req_addr;
`endif

always @(posedge clock or posedge reset) begin
    if (reset) begin
        cop_mem_state   <= 2'd0;
        cop_mem_wen_r   <= 1'b0;
        cop_mem_aw_done <= 1'b0;
        cop_mem_w_done  <= 1'b0;
        cop_mem_killed_r <= 1'b0;
        cop_mem_done_r  <= 1'b0;
        cop_mem_rdata_r <= 32'b0;
        cop_mem_addr_r  <= 32'b0;
        cop_mem_wdata_r <= 32'b0;
        cop_mem_size_r  <= 3'b0;
    end else begin
        cop_mem_done_r <= 1'b0;
        if (cop_kill) begin
            if ((cop_mem_state == 2'd1) && !cop_mem_wen_r && !cop_mem_ar_fire) begin
                cop_mem_state <= 2'd0;
                cop_mem_killed_r <= 1'b0;
            end else if ((cop_mem_state == 2'd1) && cop_mem_wen_r &&
                         !(cop_mem_aw_done || cop_mem_aw_fire) && !(cop_mem_w_done || cop_mem_w_fire)) begin
                cop_mem_state <= 2'd0;
                cop_mem_killed_r <= 1'b0;
            end else if (cop_mem_state != 2'd0) begin
                cop_mem_killed_r <= 1'b1;
                if ((cop_mem_state == 2'd2) && (cop_mem_wen_r ? cop_mem_b_fire : cop_mem_r_fire)) begin
                    cop_mem_state <= 2'd0;
                    cop_mem_killed_r <= 1'b0;
                end
                if ((cop_mem_state == 2'd1) && !cop_mem_wen_r && cop_mem_ar_fire) begin
                    cop_mem_state <= 2'd2;
                end
                if ((cop_mem_state == 2'd1) && cop_mem_wen_r) begin
                    if (cop_mem_aw_fire) begin
                        cop_mem_aw_done <= 1'b1;
                    end
                    if (cop_mem_w_fire) begin
                        cop_mem_w_done <= 1'b1;
                    end
                    if ((cop_mem_aw_done || cop_mem_aw_fire) && (cop_mem_w_done || cop_mem_w_fire)) begin
                        cop_mem_state <= 2'd2;
                    end
                end
            end
        end else begin
        case (cop_mem_state)
            2'd0: begin
                if (cop_mem_new_req) begin
                    cop_mem_state   <= 2'd1;
                    cop_mem_wen_r   <= COP_MEM_REQ_STORE;
                    cop_mem_aw_done <= 1'b0;
                    cop_mem_w_done  <= 1'b0;
                    cop_mem_killed_r <= 1'b0;
                    cop_mem_addr_r  <= COP_MEM_ADDR;
                    cop_mem_wdata_r <= COP_MEM_WDATA;
                    cop_mem_size_r  <= COP_MEM_SIZE;
                end
            end
            2'd1: begin
                if (cop_mem_wen_r) begin
                    if (!cop_mem_aw_done && cop_mem_aw_fire) begin
                        cop_mem_aw_done <= 1'b1;
                    end
                    if (!cop_mem_w_done && cop_mem_w_fire) begin
                        cop_mem_w_done <= 1'b1;
                    end
                    if ((cop_mem_aw_done || cop_mem_aw_fire) && (cop_mem_w_done || cop_mem_w_fire)) begin
                        cop_mem_state <= 2'd2;
                    end
                end else if (cop_mem_ar_fire) begin
                    cop_mem_state <= 2'd2;
                end
            end
            2'd2: begin
                if (cop_mem_wen_r ? cop_mem_b_fire : cop_mem_r_fire) begin
                    cop_mem_state   <= cop_mem_killed_r ? 2'd0 : 2'd3;
                    cop_mem_rdata_r <= LSU_SRAM_AXI_RDATA;
                end
            end
            2'd3: begin
                cop_mem_state  <= 2'd0;
                cop_mem_done_r <= 1'b1;
                cop_mem_killed_r <= 1'b0;
            end
            default: begin
                cop_mem_state <= 2'd0;
            end
        endcase
        end
    end
end

// Latch mispredict signals for one full cycle
reg mispredict_latched;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        exu_mispredict_flush_r <= 1'b0;
        exu_redirect_pc_r      <= 32'b0;
        mispredict_latched     <= 1'b0;
    end else begin
        if (exu_mispredict_flush && !mispredict_latched) begin
            exu_redirect_pc_r  <= exu_redirect_pc;
            mispredict_latched <= 1'b1;
        end
        exu_mispredict_flush_r <= exu_mispredict_flush && !mispredict_latched;
        if (!exu_mispredict_flush)
            mispredict_latched <= 1'b0;
    end
end

wire                   [  31:0]         exu2wbu_pc_next            ;
wire                   [  31:0]         exu2wbu_pc                 ;
wire                   [  11:0]         exu2wbu_csr_addr           ;
wire                   [   4:0]         exu2wbu_rd_addr            ;
wire                                    exu2wbu_wen                ;
wire                                    exu2wbu_csr_wen            ;
wire                                    exu2wbu_commit_wen         ;
wire                                    exu2wbu_commit_csr_wen     ;
wire                                    exu_commit_visible         ;
wire                                    exu2wbu_brch               ;
wire                                    exu2wbu_jal                ;
wire                                    exu2wbu_jalr               ;
wire                                    exu2wbu_mret               ;
wire                                    exu2wbu_ecall              ;
wire                   [  31:0]         exu2wbu_res                ;
wire                                    exu2wbu_ebreak             ;
wire                                    exu2wbu_load               ;
wire                                    exu2wbu_store              ;
wire                                    exu2wbu_muldiv             ;
wire                                    exu2wbu_fence_i            ;
wire                                    exu2wbu_is_brch            ;
wire                                    exu2wbu_is_div             ;
// wire                                    exu2wbu_next               ;

// ===========================================================================
// Delay idu2exu instruction-type signals by 1 cycle to align with EXU latency
// These delayed versions are used ONLY for perf counter accuracy.
// ===========================================================================
reg  idu2exu_load_d;
reg  idu2exu_store_d;
reg  idu2exu_muldiv_d;
reg  idu2exu_cop_d;
reg  idu2exu_fence_i_d;
reg  idu2exu_brch_d;
reg  idu2exu_is_div_d;
reg  idu2exu_is_mul_low_d;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    idu2exu_load_d    <= 1'b0;
    idu2exu_store_d   <= 1'b0;
    idu2exu_muldiv_d  <= 1'b0;
    idu2exu_cop_d     <= 1'b0;
    idu2exu_fence_i_d <= 1'b0;
    idu2exu_brch_d    <= 1'b0;
    idu2exu_is_div_d  <= 1'b0;
    idu2exu_is_mul_low_d <= 1'b0;
  end else begin
    idu2exu_load_d    <= idu2exu_load;
    idu2exu_store_d   <= idu2exu_store;
    idu2exu_muldiv_d  <= idu2exu_muldiv;
    idu2exu_cop_d     <= idu2exu_is_cop_insn;
    idu2exu_fence_i_d <= idu2exu_fence_i;
    idu2exu_brch_d    <= idu2exu_brch;
    idu2exu_is_div_d  <= idu2exu_muldiv && idu2exu_exu_opt[2];
    idu2exu_is_mul_low_d <= idu2exu_muldiv && !idu2exu_exu_opt[2] && (idu2exu_exu_opt[1:0] == 2'b00);
  end
end

hcpu_exu_wbu_regs exu_wbu_regs (
    .clock                             (clock                     ),
    .reset                             (reset || pc_update_en     ),
    .i_brch                            (cop_commit_active ? 1'b0 : exu_brch),
    .i_jal                             (cop_commit_active ? 1'b0 : idu2exu_jal),
    .i_wen                             (cop_commit_active ? cop_inflight_wen : idu2exu_wen),

    .i_csr_wen                         (cop_commit_active ? 1'b0 : idu2exu_csr_wen),
    .i_jalr                            (cop_commit_active ? 1'b0 : idu2exu_jalr),
    .i_ebreak                          (cop_commit_active ? 1'b0 : idu2exu_ebreak),
    .i_mret                            (cop_commit_active ? 1'b0 : idu2exu_mret),
    .i_ecall                           (cop_commit_active ? 1'b0 : idu2exu_ecall),
    .i_predict_taken                   (cop_commit_active ? 1'b0 : idu2exu_predict_taken),
    .i_predict_correct                 (exu_predict_correct       ),
    .i_load                            (cop_commit_active ? 1'b0 : idu2exu_load_d),
    .i_store                           (cop_commit_active ? 1'b0 : idu2exu_store_d),
    .i_muldiv                          (cop_commit_active ? 1'b0 : idu2exu_muldiv_d),
    .i_fence_i                         (cop_commit_active ? 1'b0 : idu2exu_fence_i_d),
    .i_is_brch                         (cop_commit_active ? 1'b0 : idu2exu_brch),
    .i_is_div                          (cop_commit_active ? 1'b0 : idu2exu_is_div_d),
    .i_res                             (exu_res                   ),
    .i_pc                              (cop_active_pc             ),
    .i_pc_next                         (exu_commit_pc_next        ),
    .i_csr_addr                        (cop_commit_active ? 12'b0 : idu2exu_csr_addr),
    .i_rd_addr                         (cop_commit_active ? cop_inflight_rd : idu2exu_rd),

    .o_pc_next                         (exu2wbu_pc_next           ),
    .o_pc                              (exu2wbu_pc                ),
    .o_csr_addr                        (exu2wbu_csr_addr          ),
    .o_rd_addr                         (exu2wbu_rd_addr           ),
    .o_wen                             (exu2wbu_wen               ),
    .o_csr_wen                         (exu2wbu_csr_wen           ),
    .o_brch                            (exu2wbu_brch              ),
    .o_jal                             (exu2wbu_jal               ),
    .o_jalr                            (exu2wbu_jalr              ),
    .o_mret                            (exu2wbu_mret              ),
    .o_ecall                           (exu2wbu_ecall             ),
    .o_predict_taken                   (exu2wbu_predict_taken     ),
    .o_predict_correct                 (exu2wbu_predict_correct   ),
    .o_res                             (exu2wbu_res               ),
    .o_ebreak                          (exu2wbu_ebreak            ),
    .o_load                            (exu2wbu_load              ),
    .o_store                           (exu2wbu_store             ),
    .o_muldiv                          (exu2wbu_muldiv            ),
    .o_fence_i                         (exu2wbu_fence_i           ),
    .o_is_brch                         (exu2wbu_is_brch           ),
    .o_is_div                          (exu2wbu_is_div            ),
    .o_valid                           (exu_wbu_valid             ),
    .i_post_ready                      (wbu2exu_ready             ),
    .o_post_valid                      (exu2wbu_valid             ),
    .i_flush                            (exu_mispredict_flush_r || scalar_flush_test) 
);

hcpu_WBU wbu1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_pc_next                         (exu2wbu_pc_next           ),
    .i_pre_valid                       (exu_wbu_valid             ),  // use EXU-WBU's own valid
    // .i_next                            (exu2wbu_next              ),

    .i_rd_addr                         (exu2wbu_rd_addr           ),
    .i_csr_addr                        (exu2wbu_csr_addr          ),
    .i_brch                            (exu2wbu_brch              ),
    .i_jal                             (exu2wbu_jal               ),
    .i_wen                             (exu2wbu_wen               ),
    .i_csr_wen                         (exu2wbu_csr_wen           ),
    .i_is_brch                         (exu2wbu_is_brch           ),
    .i_jalr                            (exu2wbu_jalr              ),
    .i_ebreak                          (exu2wbu_ebreak            ),
    .i_mret                            (exu2wbu_mret              ),
    .i_ecall                           (exu2wbu_ecall             ),
    .i_predict_taken                   (exu2wbu_predict_taken     ),
    .i_predict_correct                 (exu2wbu_predict_correct   ),

    .i_res                             (exu2wbu_res               ),

    .o_pc_next                         (pc_next                   ),
    .o_pc_update                       (pc_update_en              ),
    .o_rd_wdata                        (wbu_rd_wdata              ),
    .o_rd_addr                         (wbu_rd_addr               ),
    //
    .o_csr_addr                        (wbu_csr_addr              ),
    .o_csr_rd_wdata                    (csr_rd_wdata              ),
    //
    .o_wbu_wen                         (wbu_wen                   ),
    .o_wbu_csr_wen                     (wbu_csr_wen               ),
    .o_pre_ready                       (wbu2exu_ready             ) 
);

assign exu_commit_visible     = exu_wbu_valid;
assign exu2wbu_commit_wen     = exu_commit_visible && exu2wbu_wen;
assign exu2wbu_commit_csr_wen = exu_commit_visible && exu2wbu_csr_wen;

hcpu_Xbar xbar
(
    .clock                             (clock                     ),
    .RESETN                            (rst_n_sync                ),

    .IFU_RDATA                         (IFU_SRAM_AXI_RDATA        ),
    .IFU_RRESP                         (IFU_SRAM_AXI_RRESP        ),
    .IFU_RVALID                        (IFU_SRAM_AXI_RVALID       ),
    .IFU_RREADY                        (IFU_SRAM_AXI_RREADY       ),
    .IFU_RID                           (IFU_SRAM_AXI_RID          ),
    .IFU_RLAST                         (IFU_SRAM_AXI_RLAST        ),
    .IFU_ARADDR                        (IFU_SRAM_AXI_ARADDR       ),
    .IFU_ARVALID                       (IFU_SRAM_AXI_ARVALID      ),
    .IFU_ARREADY                       (IFU_SRAM_AXI_ARREADY      ),
    .IFU_ARID                          (IFU_SRAM_AXI_ARID         ),
    .IFU_ARLEN                         (IFU_SRAM_AXI_ARLEN        ),
    .IFU_ARSIZE                        (IFU_SRAM_AXI_ARSIZE       ),
    .IFU_ARBURST                       (IFU_SRAM_AXI_ARBURST      ),

  // LSU AXI-FULL Interface
    .LSU_AWADDR                        (LSU_ARB_AXI_AWADDR        ),
    .LSU_AWVALID                       (LSU_ARB_AXI_AWVALID       ),
    .LSU_AWREADY                       (LSU_SRAM_AXI_AWREADY      ),
    .LSU_AWLEN                         (LSU_ARB_AXI_AWLEN         ),
    .LSU_AWSIZE                        (LSU_ARB_AXI_AWSIZE        ),
    .LSU_AWBURST                       (LSU_ARB_AXI_AWBURST       ),
    .LSU_AWID                          (LSU_ARB_AXI_AWID          ),
    .LSU_WVALID                        (LSU_ARB_AXI_WVALID        ),
    .LSU_WREADY                        (LSU_SRAM_AXI_WREADY       ),
    .LSU_WDATA                         (LSU_ARB_AXI_WDATA         ),
    .LSU_WSTRB                         (LSU_ARB_AXI_WSTRB         ),
    .LSU_WLAST                         (LSU_ARB_AXI_WLAST         ),
    .LSU_RDATA                         (LSU_SRAM_AXI_RDATA        ),
    .LSU_RRESP                         (LSU_SRAM_AXI_RRESP        ),
    .LSU_RVALID                        (LSU_SRAM_AXI_RVALID       ),
    .LSU_RREADY                        (LSU_ARB_AXI_RREADY        ),
    .LSU_RID                           (LSU_SRAM_AXI_RID          ),
    .LSU_RLAST                         (LSU_SRAM_AXI_RLAST        ),
    .LSU_ARADDR                        (LSU_ARB_AXI_ARADDR        ),
    .LSU_ARVALID                       (LSU_ARB_AXI_ARVALID       ),
    .LSU_ARREADY                       (LSU_SRAM_AXI_ARREADY      ),
    .LSU_ARID                          (LSU_ARB_AXI_ARID          ),
    .LSU_ARLEN                         (LSU_ARB_AXI_ARLEN         ),
    .LSU_ARSIZE                        (LSU_ARB_AXI_ARSIZE        ),
    .LSU_ARBURST                       (LSU_ARB_AXI_ARBURST       ),
    .LSU_BRESP                         (LSU_SRAM_AXI_BRESP        ),
    .LSU_BVALID                        (LSU_SRAM_AXI_BVALID       ),
    .LSU_BREADY                        (LSU_ARB_AXI_BREADY        ),
    .LSU_BID                           (LSU_SRAM_AXI_BID          ),

    .CLINT_ARADDR                      (CLINT_AXI_ARADDR          ),
    .CLINT_ARVALID                     (CLINT_AXI_ARVALID         ),
    .CLINT_ARREADY                     (CLINT_AXI_ARREADY         ),
    .CLINT_ARID                        (CLINT_AXI_ARID            ),
    .CLINT_ARLEN                       (CLINT_AXI_ARLEN           ),
    .CLINT_ARSIZE                      (CLINT_AXI_ARSIZE          ),
    .CLINT_ARBURST                     (CLINT_AXI_ARBURST         ),
    .CLINT_RDATA                       (CLINT_AXI_RDATA           ),
    .CLINT_RRESP                       (CLINT_AXI_RRESP           ),
    .CLINT_RVALID                      (CLINT_AXI_RVALID          ),
    .CLINT_RREADY                      (CLINT_AXI_RREADY          ),
    .CLINT_RLAST                       (CLINT_AXI_RLAST           ),
    .CLINT_RID                         (CLINT_AXI_RID             ),

    .SRAM_AWADDR                       (io_master_awaddr          ),
    .SRAM_AWVALID                      (io_master_awvalid         ),
    .SRAM_AWREADY                      (io_master_awready         ),
    .SRAM_AWID                         (io_master_awid            ),
    .SRAM_AWLEN                        (io_master_awlen           ),
    .SRAM_AWSIZE                       (io_master_awsize          ),
    .SRAM_AWBURST                      (io_master_awburst         ),
    .SRAM_WDATA                        (io_master_wdata           ),
    .SRAM_WSTRB                        (io_master_wstrb           ),
    .SRAM_WVALID                       (io_master_wvalid          ),
    .SRAM_WREADY                       (io_master_wready          ),
    .SRAM_WLAST                        (io_master_wlast           ),
    .SRAM_BRESP                        (io_master_bresp           ),
    .SRAM_BVALID                       (io_master_bvalid          ),
    .SRAM_BREADY                       (io_master_bready          ),
    .SRAM_BID                          (io_master_bid             ),
    .SRAM_ARADDR                       (io_master_araddr          ),
    .SRAM_ARVALID                      (io_master_arvalid         ),
    .SRAM_ARREADY                      (io_master_arready         ),
    .SRAM_ARID                         (io_master_arid            ),
    .SRAM_ARLEN                        (io_master_arlen           ),
    .SRAM_ARSIZE                       (io_master_arsize          ),
    .SRAM_ARBURST                      (io_master_arburst         ),
    .SRAM_RDATA                        (io_master_rdata           ),
    .SRAM_RRESP                        (io_master_rresp           ),
    .SRAM_RVALID                       (io_master_rvalid          ),
    .SRAM_RREADY                       (io_master_rready          ),
    .SRAM_RLAST                        (io_master_rlast           ),
    .SRAM_RID                          (io_master_rid             ) 
);

hcpu_RegisterFile regfile1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .waddr                             (wbu_rd_addr               ),
    .wdata                             (wbu_rd_wdata              ),
    .wen                               (wbu_wen                   ),
//
    .exu_rd                            (cop_commit_active ? cop_inflight_rd : idu2exu_rd),
    .exu_wdata                         (exu_res                   ),
    .exu_wen                           (cop_commit_active ? cop_inflight_wen : idu2exu_wen),
    .exu_post_valid                   (exu2wbu_valid             ),

    .wbu_rd                            (exu2wbu_rd_addr           ),
    .wbu_wdata                         (exu2wbu_res               ),
    .wbu_wen                           (exu2wbu_commit_wen        ),
//
    .raddr1                            (idu_addr_rs1              ),
    .raddr2                            (idu_addr_rs2              ),
    .rdata1                            (rs1                       ),
    .rdata2                            (rs2                       ),
    .dbg_s0                            (dbg_s0                    ),
    .dbg_s1                            (dbg_s1                    ),
    .dbg_s2                            (dbg_s2                    ),
    .dbg_s3                            (dbg_s3                    ),
    .dbg_s4                            (dbg_s4                    )
);

CLINT clint
(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    //read data channel
    .S_AXI_RDATA                       (CLINT_AXI_RDATA           ),
    .S_AXI_RRESP                       (CLINT_AXI_RRESP           ),
    .S_AXI_RVALID                      (CLINT_AXI_RVALID          ),
    .S_AXI_RREADY                      (CLINT_AXI_RREADY          ),
    .S_AXI_RLAST                       (CLINT_AXI_RLAST           ),
    .S_AXI_RID                         (CLINT_AXI_RID             ),
    //read adress channel
    .S_AXI_ARADDR                      (CLINT_AXI_ARADDR          ),
    .S_AXI_ARVALID                     (CLINT_AXI_ARVALID         ),
    .S_AXI_ARREADY                     (CLINT_AXI_ARREADY         ),
    .S_AXI_ARID                        (CLINT_AXI_ARID            ),
    .S_AXI_ARLEN                       (CLINT_AXI_ARLEN           ),
    .S_AXI_ARSIZE                      (CLINT_AXI_ARSIZE          ),
    .S_AXI_ARBURST                     (CLINT_AXI_ARBURST         )
);


// ---- DPI-C imports (always declared for linker) ----
import "DPI-C" function void csr_cnt_dpic    ();
import "DPI-C" function void brch_cnt_dpic   ();
import "DPI-C" function void jal_cnt_dpic    ();
import "DPI-C" function void load_cnt_dpic   ();
import "DPI-C" function void store_cnt_dpic  ();
import "DPI-C" function void inst_cnt_dpic   ();
import "DPI-C" function void ifu_start       ();
import "DPI-C" function void ifu_end         ();
import "DPI-C" function void icache_end      ();
import "DPI-C" function void cache_miss      ();
import "DPI-C" function void load_start      ();
import "DPI-C" function void load_end        ();
import "DPI-C" function void store_start     ();
import "DPI-C" function void store_end       ();
import "DPI-C" function void commit_pc_dpic  (input int pc);
import "DPI-C" function void commit_trace_dpic(input int pc, input int rd, input int wdata, input int wen, input int is_store, input int store_addr, input int store_data, input int store_strb, input int is_brch, input int brch_taken, input int predict_taken, input int predict_correct, input int pc_update, input int flush);
import "DPI-C" function void mergesort_loop_dpic(input int s4, input int s1, input int s0, input int s3, input int s2);

`ifdef PERF_COUNTERS
import "DPI-C" function void brch_tkn_dpic   ();
import "DPI-C" function void load_dpic       ();
import "DPI-C" function void store_dpic      ();
import "DPI-C" function void mul_cnt_dpic    ();
import "DPI-C" function void mul_low_cnt_dpic();
import "DPI-C" function void mul_high_cnt_dpic();
import "DPI-C" function void div_cnt_dpic    ();
import "DPI-C" function void cop_cnt_dpic    ();
import "DPI-C" function void alu_cnt_dpic    ();
import "DPI-C" function void sys_cnt_dpic    ();
import "DPI-C" function void fence_cnt_dpic  ();
import "DPI-C" function void stall_cnt_dpic  ();
import "DPI-C" function void stall_front_dpic();
import "DPI-C" function void stall_ifu_held_dpic();
import "DPI-C" function void stall_ifu_held_ctrl_dpic();
import "DPI-C" function void stall_ifu_held_lsu_dpic();
import "DPI-C" function void stall_ifu_held_mul_dpic();
import "DPI-C" function void stall_ifu_held_mul_only_dpic();
import "DPI-C" function void stall_ifu_held_div_dpic();
import "DPI-C" function void stall_ifu_held_cop_dpic();
import "DPI-C" function void stall_ifu_held_other_dpic();
import "DPI-C" function void stall_lsu_dpic  ();
import "DPI-C" function void stall_lsu_start_dpic();
import "DPI-C" function void stall_lsu_start_load_dpic();
import "DPI-C" function void stall_lsu_start_store_dpic();
import "DPI-C" function void stall_lsu_hit_dpic();
import "DPI-C" function void stall_lsu_refill_dpic();
import "DPI-C" function void stall_lsu_refill_ar_dpic();
import "DPI-C" function void stall_lsu_refill_r_dpic();
import "DPI-C" function void stall_lsu_uncached_dpic();
import "DPI-C" function void stall_lsu_wb_dpic();
import "DPI-C" function void stall_mul_dpic  ();
import "DPI-C" function void stall_mul_only_dpic();
import "DPI-C" function void stall_div_dpic  ();
import "DPI-C" function void stall_cop_dpic  ();
import "DPI-C" function void stall_ctrl_dpic ();
import "DPI-C" function void stall_other_dpic();
import "DPI-C" function void stall_other_blocked_dpic();
import "DPI-C" function void stall_other_pipe_dpic();
import "DPI-C" function void stall_other_pipe_alu_dpic();
import "DPI-C" function void stall_other_pipe_brch_dpic();
import "DPI-C" function void stall_other_pipe_jal_dpic();
import "DPI-C" function void stall_other_pipe_jalr_dpic();
import "DPI-C" function void stall_other_pipe_sys_dpic();
import "DPI-C" function void backend_pipe_occ_dpic();
import "DPI-C" function void btb_hit_dpic    ();
import "DPI-C" function void btb_miss_dpic   ();
import "DPI-C" function void btb_misp_dpic   ();
import "DPI-C" function void ras_hit_dpic    ();
import "DPI-C" function void ras_miss_dpic   ();
import "DPI-C" function void jal_tgt_mismatch();
import "DPI-C" function void ras_push_dpic   ();
import "DPI-C" function void wbu_pcup_dpic   ();
import "DPI-C" function void wbu_pcup_brch_dpic();
import "DPI-C" function void wbu_pcup_jal_dpic();
import "DPI-C" function void wbu_pcup_jalr_dpic();
import "DPI-C" function void wbu_pcup_ecall_dpic();
import "DPI-C" function void wbu_pcup_mret_dpic();
import "DPI-C" function void redirect_gap_dpic(input int cycles);
import "DPI-C" function void redirect_gap_brch_dpic(input int cycles);
import "DPI-C" function void redirect_gap_jal_dpic(input int cycles);
import "DPI-C" function void redirect_gap_jalr_dpic(input int cycles);

// ===========================================================================
`ifdef PERF_INST_MIX
always @(posedge clock) begin
  if (!reset && exu_commit_visible) begin
    commit_pc_dpic(exu2wbu_pc);
    commit_trace_dpic(exu2wbu_pc, {27'b0, exu2wbu_rd_addr}, exu2wbu_res,
                      {31'b0, exu2wbu_commit_wen}, {31'b0, exu2wbu_store},
                      LSU_SRAM_AXI_AWADDR, LSU_SRAM_AXI_WDATA,
                      {28'b0, LSU_SRAM_AXI_WSTRB}, {31'b0, exu2wbu_is_brch},
                      {31'b0, exu2wbu_brch}, {31'b0, exu2wbu_predict_taken},
                      {31'b0, exu2wbu_predict_correct}, {31'b0, pc_update_en},
                      {31'b0, exu_mispredict_flush_r});
    if (exu2wbu_pc == 32'h30001880) mergesort_loop_dpic(dbg_s4, dbg_s1, dbg_s0, dbg_s3, dbg_s2);
    inst_cnt_dpic();
    if (idu2exu_brch_d) begin
      brch_cnt_dpic();
      if (exu2wbu_brch) brch_tkn_dpic();
    end
    if (exu2wbu_jal || exu2wbu_jalr)  jal_cnt_dpic();
    if (exu2wbu_commit_csr_wen)        csr_cnt_dpic();
    if (idu2exu_load_d)                load_dpic();
    if (idu2exu_store_d)               store_dpic();
    if (idu2exu_muldiv_d) begin
      if (idu2exu_is_div_d) begin
        div_cnt_dpic();
      end else begin
        mul_cnt_dpic();
        if (idu2exu_is_mul_low_d) mul_low_cnt_dpic();
        else                      mul_high_cnt_dpic();
      end
    end
    if (idu2exu_cop_d)                   cop_cnt_dpic();
    if (!idu2exu_load_d && !idu2exu_store_d && !idu2exu_muldiv_d && !idu2exu_cop_d &&
        !exu2wbu_jal && !exu2wbu_jalr && !idu2exu_brch_d &&
        !exu2wbu_mret && !exu2wbu_ecall && !exu2wbu_ebreak &&
        !exu2wbu_commit_csr_wen && !idu2exu_fence_i_d)
      alu_cnt_dpic();
    if (exu2wbu_ecall || exu2wbu_mret || exu2wbu_ebreak) sys_cnt_dpic();
    if (idu2exu_fence_i_d)  fence_cnt_dpic();
  end
end
`endif // PERF_INST_MIX

// ===========================================================================
`ifdef PERF_STALL
always @(posedge clock) begin
  if (!reset && !exu2wbu_valid) begin
    if (ifu2idu_valid && !idu2ifu_ready) begin
      stall_ifu_held_dpic();
      if (exu_mispredict_flush_r || pc_update_en) begin
        stall_ifu_held_ctrl_dpic();
      end else if (idu2exu_valid && !exu2idu_ready) begin
        if (idu2exu_load || idu2exu_store) begin
          stall_ifu_held_lsu_dpic();
        end else if (idu2exu_muldiv) begin
          stall_ifu_held_mul_dpic();
          if (idu2exu_exu_opt[2]) begin
            stall_ifu_held_div_dpic();
          end else begin
            stall_ifu_held_mul_only_dpic();
          end
        end else if (idu2exu_is_cop_insn) begin
          stall_ifu_held_cop_dpic();
        end else begin
          stall_ifu_held_other_dpic();
        end
      end else begin
        stall_ifu_held_other_dpic();
      end
    end
  end

  if (!reset && !exu2wbu_valid) begin
    if (exu_mispredict_flush_r || pc_update_en) begin
      stall_cnt_dpic();
      stall_ctrl_dpic();
    end else if (idu2exu_valid && !exu2idu_ready) begin
      stall_cnt_dpic();
      if (idu2exu_load || idu2exu_store) begin
        stall_lsu_dpic();
        if (exu_lsu_dbg_wait_start) begin
          stall_lsu_start_dpic();
          if (idu2exu_load) begin
            stall_lsu_start_load_dpic();
          end else if (idu2exu_store) begin
            stall_lsu_start_store_dpic();
          end
        end else if (exu_lsu_dbg_wait_hit) begin
          stall_lsu_hit_dpic();
        end else if (exu_lsu_dbg_wait_refill) begin
          stall_lsu_refill_dpic();
          if (exu_lsu_dbg_wait_refill_ar) begin
            stall_lsu_refill_ar_dpic();
          end else if (exu_lsu_dbg_wait_refill_r) begin
            stall_lsu_refill_r_dpic();
          end
        end else if (exu_lsu_dbg_wait_uncached) begin
          stall_lsu_uncached_dpic();
        end else if (exu_lsu_dbg_wait_wb) begin
          stall_lsu_wb_dpic();
        end
      end else if (idu2exu_muldiv) begin
        stall_mul_dpic();
        if (idu2exu_exu_opt[2]) begin
          stall_div_dpic();
        end else begin
          stall_mul_only_dpic();
        end
      end else if (idu2exu_is_cop_insn) begin
        stall_cop_dpic();
      end else begin
        stall_other_dpic();
        stall_other_blocked_dpic();
      end
    end else if (!idu2exu_valid) begin
      stall_cnt_dpic();
      stall_front_dpic();
    end else begin
      backend_pipe_occ_dpic();
      stall_other_pipe_dpic();
      if (idu2exu_brch) begin
        stall_other_pipe_brch_dpic();
      end else if (idu2exu_jal) begin
        stall_other_pipe_jal_dpic();
      end else if (idu2exu_jalr) begin
        stall_other_pipe_jalr_dpic();
      end else if (idu2exu_csr_wen || idu2exu_ecall || idu2exu_mret || idu2exu_fence_i || idu2exu_ebreak) begin
        stall_other_pipe_sys_dpic();
      end else begin
        stall_other_pipe_alu_dpic();
      end
    end
  end
end
`endif // PERF_STALL

// ===========================================================================
`ifdef PERF_BUS
always @(posedge clock) begin
  if (!reset) begin
    if (LSU_SRAM_AXI_ARVALID && LSU_SRAM_AXI_ARREADY)    load_start();
    if (LSU_SRAM_AXI_RVALID && LSU_SRAM_AXI_RREADY && LSU_SRAM_AXI_RLAST) load_end();
    if (LSU_SRAM_AXI_AWVALID && LSU_SRAM_AXI_AWREADY)   store_start();
    if (LSU_SRAM_AXI_BVALID && LSU_SRAM_AXI_BREADY)      store_end();
  end
end
`endif // PERF_BUS

// ===========================================================================
`ifdef PERF_CACHE
always @(posedge clock) begin
  if (!reset) begin
    if (IFU_SRAM_AXI_ARVALID && IFU_SRAM_AXI_ARREADY) begin
      ifu_start(); cache_miss();
    end
    if (IFU_SRAM_AXI_RVALID && IFU_SRAM_AXI_RREADY && IFU_SRAM_AXI_RLAST) ifu_end();
    if (icache_hit) icache_end();
  end
end
`endif // PERF_CACHE

// ===========================================================================
`ifdef PERF_BRANCH_PRED
reg btb_hit_d, btb_is_brch_d, btb_valid_d;
reg ras_hit_d, ras_is_ret_d, ras_valid_d;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        btb_valid_d   <= 1'b0;
        btb_is_brch_d <= 1'b0;
        btb_hit_d     <= 1'b0;
        ras_valid_d   <= 1'b0;
        ras_is_ret_d  <= 1'b0;
        ras_hit_d     <= 1'b0;
    end else begin
        btb_valid_d   <= icache_hit && ifu_fetch_ready && !frontend_flush;
        btb_is_brch_d <= (ins[6:0] == 7'b1100011);
        btb_hit_d     <= btb_lookup_hit;
        ras_valid_d   <= icache_hit && ifu_fetch_ready && !frontend_flush;
        ras_is_ret_d  <= (ins[6:0] == 7'b1100111) && (ins[11:7] == 5'd0);
        ras_hit_d     <= ras_predict_valid;
    end
end

always @(posedge clock) begin
    if (!reset && btb_valid_d) begin
        if (btb_is_brch_d) begin
            if (btb_hit_d) btb_hit_dpic();
            else btb_miss_dpic();
        end
    end
    if (!reset && ras_valid_d) begin
        if (ras_is_ret_d) begin
            if (ras_hit_d) ras_hit_dpic();
            else ras_miss_dpic();
        end
    end
    if (!reset && exu_mispredict_flush_r) begin
        btb_misp_dpic();
    end
end

// debug: JAL target mismatch
always @(posedge clock) begin
    if (!reset && idu2exu_jal && idu2exu_predict_taken) begin
        if (({idu2exu_predict_target, 2'b00}) != exu_pc_next)
            jal_tgt_mismatch();
    end
end

// debug: RAS push/pop
always @(posedge clock) begin
    if (!reset && exu_ras_push_en) ras_push_dpic();
end

// debug: WBU pc_update
wire wbu_pc_update_fire;

always @(posedge clock) begin
    if (!reset && wbu_pc_update_fire) begin
        wbu_pcup_dpic();
        if (exu2wbu_is_brch) wbu_pcup_brch_dpic();
        if (exu2wbu_jal) wbu_pcup_jal_dpic();
        if (exu2wbu_jalr) wbu_pcup_jalr_dpic();
        if (exu2wbu_ecall) wbu_pcup_ecall_dpic();
        if (exu2wbu_mret) wbu_pcup_mret_dpic();
    end
end

// debug: redirect recovery gap measurement
wire        redirect_fire;
wire        redirect_complete;
wire        redirect_recovery;
wire [31:0] redirect_gap_cnt;
wire        redirect_cause_brch;
wire        redirect_cause_jal;
wire        redirect_cause_jalr;

hcpu_commit_visible_ctrl commit_visible_ctrl (
    .clock                        (clock),
    .reset                        (reset),
    .i_scalar_exu_mispredict_flush(scalar_exu_mispredict_flush),
    .i_idu2exu_brch               (idu2exu_brch),
    .i_idu2exu_jal                (idu2exu_jal),
    .i_idu2exu_jalr               (idu2exu_jalr),
    .i_commit_visible             (exu_commit_visible),
    .i_exu2wbu_ecall              (exu2wbu_ecall),
    .i_exu2wbu_mret               (exu2wbu_mret),
    .i_pc_update_en               (pc_update_en),
    .i_exu_mispredict_flush_r     (exu_mispredict_flush_r),
    .o_wbu_pc_update_fire         (wbu_pc_update_fire),
    .o_redirect_fire              (redirect_fire),
    .o_redirect_complete          (redirect_complete),
    .o_redirect_recovery          (redirect_recovery),
    .o_redirect_gap_cnt           (redirect_gap_cnt),
    .o_redirect_cause_brch        (redirect_cause_brch),
    .o_redirect_cause_jal         (redirect_cause_jal),
    .o_redirect_cause_jalr        (redirect_cause_jalr)
);

always @(posedge clock) begin
    if (!reset && redirect_complete) begin
        redirect_gap_dpic(redirect_gap_cnt);
        if (redirect_cause_brch) redirect_gap_brch_dpic(redirect_gap_cnt);
        if (redirect_cause_jal)  redirect_gap_jal_dpic(redirect_gap_cnt);
        if (redirect_cause_jalr) redirect_gap_jalr_dpic(redirect_gap_cnt);
    end
end
`endif // PERF_BRANCH_PRED

`endif // PERF_COUNTERS

endmodule
