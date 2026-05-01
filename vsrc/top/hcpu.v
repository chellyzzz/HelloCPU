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
//csr wdata rd_wdata
wire                   [ISA_WIDTH-1:0]  csr_rd_wdata               ;

wire                   [ISA_WIDTH-1:0]  exu_res                    ;
wire                                    exu_brch                   ;
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
//
wire                                    ifu2idu_valid, idu2ifu_ready;
wire                                    idu2exu_valid, exu2idu_ready;
wire                                    exu2wbu_valid, wbu2exu_ready;
//cache 
wire                   [ISA_WIDTH-1:0]  icache_ins                 ;
wire                   [ISA_WIDTH-1:0]  ifu_req_addr               ;
wire                                    icache_hit                 ;
wire                                    fence_i                    ;
wire                                    muldiv                     ;


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

hcpu_IFU ifu1
(
    .i_pc_next                         (pc_next                   ),
    .clock                             (clock                     ),
    .rst_n_sync                        (rst_n_sync                ),
    .i_pc_update                       (pc_update_en              ),
    .ins                               (ins                       ),
  //ifu -> idu handshake
    .i_post_ready                      (idu2ifu_ready             ),
    .pc_next                           (ifu_pc_next               ),
  //cache -> ifu
    .hit                               (icache_hit                ),
    .icache_ins                        (icache_ins                ),
    .req_addr                          (ifu_req_addr              ) 
);

hcpu_ifu_idu_regs ifu2idu_regs(
    .i_pc                              (ifu_pc_next               ),
    .o_pc                              (ifu2idu_pc                ),
    .i_ins                             (ins                       ),
    .o_ins                             (ifu2idu_ins               ),
    .clock                             (clock                     ),
    .reset                             (reset  || pc_update_en || idu2exu_fence_i  ),

    .icache_hit                        (icache_hit                ),
    .i_pre_valid                       (pc_update_en              ),
    .i_post_ready                      (idu2ifu_ready             ),
    .o_post_valid                      (ifu2idu_valid             ) 
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
    .o_muldiv                          (muldiv                    )
);


hcpu_idu_exu_regs idu2exu_regs(
    .clock                             (clock                     ),
    .reset                             (reset || pc_update_en || idu2exu_fence_i   ),
    .i_pre_valid                       (ifu2idu_valid             ),
    .i_post_ready                      (exu2idu_ready             ),
    .o_pre_ready                       (idu2ifu_ready             ),
    .o_post_valid                      (idu2exu_valid             ),

    .i_pc                              (ifu2idu_pc                ),
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
    
    .o_pc                              (idu2exu_pc                ),
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
    //
    .o_csr_addr                        (idu2exu_csr_addr          )
);

wire                   [  31:0]         exu_pc_next                ;
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
    .o_res                             (exu_res                   ),
    .o_brch                            (exu_brch                  ),
    .o_pc_next                         (exu_pc_next               ),
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
  //exu -> wbu handshake
    .i_pre_valid                       (idu2exu_valid             ),
    .i_post_ready                      (wbu2exu_ready             ),
    .o_post_valid                      (exu2wbu_valid             ),
    .o_pre_ready                       (exu2idu_ready             ) 
);
wire                   [  31:0]         exu2wbu_pc_next            ;
wire                   [  11:0]         exu2wbu_csr_addr           ;
wire                   [   4:0]         exu2wbu_rd_addr            ;
wire                                    exu2wbu_wen                ;
wire                                    exu2wbu_csr_wen            ;
wire                                    exu2wbu_brch               ;
wire                                    exu2wbu_jal                ;
wire                                    exu2wbu_jalr               ;
wire                                    exu2wbu_mret               ;
wire                                    exu2wbu_ecall              ;
wire                   [  31:0]         exu2wbu_res                ;
wire                                    exu2wbu_ebreak             ;
// wire                                    exu2wbu_next               ;

hcpu_exu_wbu_regs exu_wbu_regs (
    .clock                             (clock                     ),
    .reset                             (reset || pc_update_en     ),
    .i_brch                            (exu_brch                  ),
    .i_jal                             (idu2exu_jal               ),
    .i_wen                             (idu2exu_wen               ),

    .i_csr_wen                         (idu2exu_csr_wen           ),
    .i_jalr                            (idu2exu_jalr              ),
    .i_ebreak                          (idu2exu_ebreak            ),
    .i_mret                            (idu2exu_mret              ),
    .i_ecall                           (idu2exu_ecall             ),
    .i_res                             (exu_res                   ),
    .i_pc_next                         (exu_pc_next               ),
    .i_csr_addr                        (idu2exu_csr_addr          ),
    .i_rd_addr                         (idu2exu_rd                ),

    .o_pc_next                         (exu2wbu_pc_next           ),
    .o_csr_addr                        (exu2wbu_csr_addr          ),
    .o_rd_addr                         (exu2wbu_rd_addr           ),
    .o_wen                             (exu2wbu_wen               ),
    .o_csr_wen                         (exu2wbu_csr_wen           ),
    .o_brch                            (exu2wbu_brch              ),
    .o_jal                             (exu2wbu_jal               ),
    .o_jalr                            (exu2wbu_jalr              ),
    .o_mret                            (exu2wbu_mret              ),
    .o_ecall                           (exu2wbu_ecall             ),
    .o_res                             (exu2wbu_res               ),
    .o_ebreak                          (exu2wbu_ebreak            ),
    // .o_next                            (exu2wbu_next              ),
    .i_post_ready                      (wbu2exu_ready             ),
    .o_post_valid                      (exu2wbu_valid             ) 
);

hcpu_WBU wbu1(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .i_pc_next                         (exu2wbu_pc_next           ),
    .i_pre_valid                       (exu2wbu_valid             ),
    // .i_next                            (exu2wbu_next              ),

    .i_rd_addr                         (exu2wbu_rd_addr           ),
    .i_csr_addr                        (exu2wbu_csr_addr          ),
    .i_brch                            (exu2wbu_brch              ),
    .i_jal                             (exu2wbu_jal               ),
    .i_wen                             (exu2wbu_wen               ),
    .i_csr_wen                         (exu2wbu_csr_wen           ),
    .i_jalr                            (exu2wbu_jalr              ),
    .i_ebreak                          (exu2wbu_ebreak            ),
    .i_mret                            (exu2wbu_mret              ),
    .i_ecall                           (exu2wbu_ecall             ),

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
    .LSU_AWADDR                        (LSU_SRAM_AXI_AWADDR       ),
    .LSU_AWVALID                       (LSU_SRAM_AXI_AWVALID      ),
    .LSU_AWREADY                       (LSU_SRAM_AXI_AWREADY      ),
    .LSU_AWLEN                         (LSU_SRAM_AXI_AWLEN        ),
    .LSU_AWSIZE                        (LSU_SRAM_AXI_AWSIZE       ),
    .LSU_AWBURST                       (LSU_SRAM_AXI_AWBURST      ),
    .LSU_AWID                          (LSU_SRAM_AXI_AWID         ),
    .LSU_WVALID                        (LSU_SRAM_AXI_WVALID       ),
    .LSU_WREADY                        (LSU_SRAM_AXI_WREADY       ),
    .LSU_WDATA                         (LSU_SRAM_AXI_WDATA        ),
    .LSU_WSTRB                         (LSU_SRAM_AXI_WSTRB        ),
    .LSU_WLAST                         (LSU_SRAM_AXI_WLAST        ),
    .LSU_RDATA                         (LSU_SRAM_AXI_RDATA        ),
    .LSU_RRESP                         (LSU_SRAM_AXI_RRESP        ),
    .LSU_RVALID                        (LSU_SRAM_AXI_RVALID       ),
    .LSU_RREADY                        (LSU_SRAM_AXI_RREADY       ),
    .LSU_RID                           (LSU_SRAM_AXI_RID          ),
    .LSU_RLAST                         (LSU_SRAM_AXI_RLAST        ),
    .LSU_ARADDR                        (LSU_SRAM_AXI_ARADDR       ),
    .LSU_ARVALID                       (LSU_SRAM_AXI_ARVALID      ),
    .LSU_ARREADY                       (LSU_SRAM_AXI_ARREADY      ),
    .LSU_ARID                          (LSU_SRAM_AXI_ARID         ),
    .LSU_ARLEN                         (LSU_SRAM_AXI_ARLEN        ),
    .LSU_ARSIZE                        (LSU_SRAM_AXI_ARSIZE       ),
    .LSU_ARBURST                       (LSU_SRAM_AXI_ARBURST      ),
    .LSU_BRESP                         (LSU_SRAM_AXI_BRESP        ),
    .LSU_BVALID                        (LSU_SRAM_AXI_BVALID       ),
    .LSU_BREADY                        (LSU_SRAM_AXI_BREADY       ),
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
    .exu_rd                            (idu2exu_rd                ),
    .exu_wdata                         (exu_res                   ),
    .exu_wen                           (idu2exu_wen               ),
    .exu_post_valid                   (exu2wbu_valid             ),

    .wbu_rd                            (exu2wbu_rd_addr           ),
    .wbu_wdata                         (exu2wbu_res               ),
    .wbu_wen                           (exu2wbu_wen               ),
//
    .raddr1                            (idu_addr_rs1              ),
    .raddr2                            (idu_addr_rs2              ),
    .rdata1                            (rs1                       ),
    .rdata2                            (rs2                       )
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

// ===========================================================================
// Performance Counters 鈥?Instruction Mix
// Counts at WBU commit point (exu2wbu signals are valid after exu_wbu_regs)
// ===========================================================================
always @(posedge clock) begin
  if (!reset && exu2wbu_valid) begin
    inst_cnt_dpic();
    if (exu2wbu_brch) begin
      brch_cnt_dpic();
    end
    if (exu2wbu_jal || exu2wbu_jalr) begin
      jal_cnt_dpic();
    end
    if (exu2wbu_csr_wen) begin
      csr_cnt_dpic();
    end
  end
end

// ===========================================================================
// Performance Counters 鈥?Load / Store Instruction Count
// ===========================================================================
always @(posedge clock) begin
  if (!reset) begin
    if (LSU_SRAM_AXI_ARVALID && LSU_SRAM_AXI_ARREADY) begin
      load_cnt_dpic();
    end
    if (LSU_SRAM_AXI_AWVALID && LSU_SRAM_AXI_AWREADY) begin
      store_cnt_dpic();
    end
  end
end

// ===========================================================================
// Performance Counters 鈥?IFU Access Latency & ICache
// - ifu_start : AR handshake (cache miss, fetch begins)
// - ifu_end   : last read-data beat (fetch completes)
// - icache_end: cache hit   (1-cycle access)
// - cache_miss: every AR handshake is a cache miss
// ===========================================================================
always @(posedge clock) begin
  if (!reset) begin
    if (IFU_SRAM_AXI_ARVALID && IFU_SRAM_AXI_ARREADY) begin
      ifu_start();
      cache_miss();
    end
    if (IFU_SRAM_AXI_RVALID && IFU_SRAM_AXI_RREADY && IFU_SRAM_AXI_RLAST) begin
      ifu_end();
    end
    if (icache_hit) begin
      icache_end();
    end
  end
end

// ===========================================================================
// Performance Counters 鈥?LSU Access Latency
// - load_start / load_end   : AR handshake 鈫?last R beat
// - store_start / store_end : AW handshake 鈫?B response
// ===========================================================================
always @(posedge clock) begin
  if (!reset) begin
    if (LSU_SRAM_AXI_ARVALID && LSU_SRAM_AXI_ARREADY) begin
      load_start();
    end
    if (LSU_SRAM_AXI_RVALID && LSU_SRAM_AXI_RREADY && LSU_SRAM_AXI_RLAST) begin
      load_end();
    end

    if (LSU_SRAM_AXI_AWVALID && LSU_SRAM_AXI_AWREADY) begin
      store_start();
    end
    if (LSU_SRAM_AXI_BVALID && LSU_SRAM_AXI_BREADY) begin
      store_end();
    end
  end
end

endmodule
