module hcpu_idu_exu_regs (
    input              [  31:0]         i_pc                       ,
    input              [  31:0]         i_ins                      ,
    input                               clock                      ,
    input                               reset                      ,
    input                               flush                      ,
    // handshake signals
    input                               i_pre_valid                ,
    input                               i_post_ready               ,
    output                              o_pre_ready                ,
    output                              o_post_valid               ,

    input              [  31:0]         i_imm                      ,
    input              [  11:0]         i_csr_addr                 ,
    input              [  31:0]         i_src1                     ,
    input              [  31:0]         i_src2                     ,
    input              [   4:0]         i_rd                       ,
    input              [  31:0]         i_csr_rs2                  ,
    input                               i_csr_src_sel              ,
    input              [   2:0]         i_exu_opt                  ,
    input              [   9:0]         i_alu_opt                  ,
    input                               i_wen                      ,
    input                               i_csr_wen                  ,
    input              [   1:0]         i_src_sel1                 ,
    input              [   2:0]         i_src_sel2                 ,
    input                               i_mret                     ,
    input                               i_ecall                    ,
    input                               i_load                     ,
    input                               i_store                    ,
    input                               i_brch                     ,
    input                               i_jal                      ,
    input                               i_jalr                     ,
    input                               i_fence_i                  ,
    input                               i_muldiv                   ,
    input                               i_ebreak                   ,
    input                               i_is_cop_insn              ,
    
    input              [  31:0]         i_mepc                     ,
    input              [  31:0]         i_mtvec                    ,

    // branch prediction fields
    input                               i_predict_taken            ,
    input              [  31:2]         i_predict_target           ,
    input                               i_predict_btb_hit          ,

    // register addresses for RAS
    input              [   4:0]         i_rs1_addr                 ,

    output reg         [  31:0]         o_pc                       ,
    output reg         [  31:0]         o_ins                      ,
    output reg         [  31:0]         o_src1                     ,
    output reg         [  31:0]         o_src2                     ,
    output reg         [  31:0]         o_imm                      ,
    output reg         [   1:0]         o_src_sel1                 ,
    output reg         [   2:0]         o_src_sel2                 ,
    output reg         [   4:0]         o_rd                       ,
    output reg         [  11:0]         o_csr_addr                 ,
    output reg         [   2:0]         o_exu_opt                  ,
    output reg         [   9:0]         o_alu_opt                  ,
    output reg                          o_wen                      ,
    output reg                          o_csr_wen                  ,
    output reg                          o_mret                     ,
    output reg                          o_ecall                    ,
    
    output reg                          o_load                     ,
    output reg                          o_store                    ,
    output reg                          o_brch                     ,
    output reg                          o_jal                      ,
    output reg                          o_ebreak                   ,
    output reg                          o_fence_i,
    output reg                          o_muldiv                   ,
    output reg                          o_jalr                     ,
    output reg                          o_is_cop_insn              ,

    // branch prediction outputs
    output reg                          o_predict_taken            ,
    output reg         [  31:2]         o_predict_target           ,
    output reg                          o_predict_btb_hit          ,
    output reg         [   4:0]         o_rs1_addr                  
);

reg                                     post_valid                 ;

assign o_post_valid = post_valid;
assign o_pre_ready  = i_post_ready;
always @(posedge clock or posedge reset) begin
    if(reset) begin
        post_valid <= 1'b0;   
    end
    else if(flush) begin
        post_valid <= 1'b0;
    end
    else if(i_post_ready) begin
        post_valid <= i_pre_valid;
    end
end


wire                    [  31:0]         sel_src1                   ;
wire                    [  31:0]         sel_src2                   ;

assign sel_src1 =   ({32{i_ecall}}& i_mtvec )|
                    ({32{i_mret}} & i_mepc  )|
                    i_src1;

assign sel_src2 =   ({32{i_csr_src_sel}} & i_csr_rs2) | i_src2;

always @(posedge clock or posedge reset) begin
    if(reset) begin
        o_pc            <= 32'b0;
        o_ins           <= 32'b0;
        o_src1          <= 32'b0;
        o_src2          <= 32'b0;
        o_imm           <= 32'b0;
        o_src_sel1      <= 2'b0;
        o_src_sel2      <= 3'b0;
        o_rd            <= 5'b0;
        o_exu_opt       <= 3'b0;
        o_alu_opt       <= 10'b0;
        o_wen           <= 1'b0;
        o_csr_wen       <= 1'b0;
        o_mret          <= 1'b0;
        o_ecall         <= 1'b0;
        o_load          <= 1'b0;
        o_store         <= 1'b0;
        o_brch          <= 1'b0;
        o_jal           <= 1'b0;
        o_jalr          <= 1'b0;
        o_ebreak        <= 1'b0;
        o_fence_i       <= 1'b0;    
        o_muldiv        <= 1'b0;
        o_is_cop_insn   <= 1'b0;
        o_csr_addr      <= 12'b0;
        o_predict_taken <= 1'b0;
        o_predict_target <= 30'b0;
        o_predict_btb_hit <= 1'b0;
        o_rs1_addr      <= 5'b0;

    end
    else if(flush) begin
        o_pc            <= 32'b0;
        o_ins           <= 32'b0;
        o_src1          <= 32'b0;
        o_src2          <= 32'b0;
        o_imm           <= 32'b0;
        o_src_sel1      <= 2'b0;
        o_src_sel2      <= 3'b0;
        o_rd            <= 5'b0;
        o_exu_opt       <= 3'b0;
        o_alu_opt       <= 10'b0;
        o_wen           <= 1'b0;
        o_csr_wen       <= 1'b0;
        o_mret          <= 1'b0;
        o_ecall         <= 1'b0;
        o_load          <= 1'b0;
        o_store         <= 1'b0;
        o_brch          <= 1'b0;
        o_jal           <= 1'b0;
        o_jalr          <= 1'b0;
        o_ebreak        <= 1'b0;
        o_fence_i       <= 1'b0;
        o_muldiv        <= 1'b0;
        o_is_cop_insn   <= 1'b0;
        o_csr_addr      <= 12'b0;
        o_predict_taken <= 1'b0;
        o_predict_target <= 30'b0;
        o_predict_btb_hit <= 1'b0;
        o_rs1_addr      <= 5'b0;
    end
    else if(i_post_ready && i_pre_valid) begin
        o_pc            <= i_pc;
        o_ins           <= i_ins;
        o_src1          <= sel_src1;
        o_src2          <= sel_src2;
        o_imm           <= i_imm;
        o_src_sel1      <= i_src_sel1;
        o_src_sel2      <= i_src_sel2;

        o_rd            <= i_rd;
        o_exu_opt       <= i_exu_opt;
        o_alu_opt       <= i_alu_opt;
        o_wen           <= i_wen;
        o_csr_wen       <= i_csr_wen;
        o_mret          <= i_mret;
        o_ecall         <= i_ecall;
        o_load          <= i_load;
        o_store         <= i_store;
        o_brch          <= i_brch;
        o_jal           <= i_jal;
        o_jalr          <= i_jalr;
        o_ebreak        <= i_ebreak;
        o_fence_i       <= i_fence_i;
        o_muldiv        <= i_muldiv;
        o_is_cop_insn   <= i_is_cop_insn;
        o_csr_addr      <= i_csr_addr;
        o_predict_taken <= i_predict_taken;
        o_predict_target <= i_predict_target;
        o_predict_btb_hit <= i_predict_btb_hit;
        o_rs1_addr      <= i_rs1_addr;

    end
    else if(i_post_ready && ~i_pre_valid) begin
        o_pc            <= 32'b0;
        o_ins           <= 32'b0;
        o_src1          <= 32'b0;
        o_src2          <= 32'b0;
        o_imm           <= 32'b0;
        o_src_sel1      <= 2'b0;
        o_src_sel2      <= 3'b0;
        o_rd            <= 5'b0;
        o_exu_opt       <= 3'b0;
        o_alu_opt       <= 10'b0;
        o_wen           <= 1'b0;
        o_csr_wen       <= 1'b0;
        o_mret          <= 1'b0;
        o_ecall         <= 1'b0;
        o_load          <= 1'b0;
        o_store         <= 1'b0;
        o_brch          <= 1'b0;
        o_jal           <= 1'b0;
        o_jalr          <= 1'b0;
        o_ebreak        <= 1'b0;
        o_fence_i       <= 1'b0;    
        o_muldiv        <= 1'b0;
        o_is_cop_insn   <= 1'b0;
        o_csr_addr      <= 12'b0;
        o_predict_taken <= 1'b0;
        o_predict_target <= 30'b0;
        o_predict_btb_hit <= 1'b0;
        o_rs1_addr      <= 5'b0;
    end
end

`ifdef PROTOCOL_ASSERT
wire [244:0] protocol_bundle = {
    o_pc,
    o_ins,
    o_src1,
    o_src2,
    o_imm,
    o_src_sel1,
    o_src_sel2,
    o_rd,
    o_csr_addr,
    o_exu_opt,
    o_alu_opt,
    o_wen,
    o_csr_wen,
    o_mret,
    o_ecall,
    o_load,
    o_store,
    o_brch,
    o_jal,
    o_ebreak,
    o_fence_i,
    o_muldiv,
    o_jalr,
    o_is_cop_insn,
    o_predict_taken,
    o_predict_target,
    o_predict_btb_hit,
    o_rs1_addr
};

reg         prev_post_stall;
reg [244:0] prev_protocol_bundle;

always @(*) begin
    if (o_pre_ready != i_post_ready)
        $fatal(1, "hcpu_idu_exu_regs o_pre_ready must follow i_post_ready");
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
        prev_post_stall <= 1'b0;
        prev_protocol_bundle <= 245'b0;
    end else begin
        if (prev_post_stall && !flush && !i_post_ready) begin
            if (!o_post_valid)
                $fatal(1, "hcpu_idu_exu_regs valid dropped while downstream remained stalled");
            if (protocol_bundle != prev_protocol_bundle)
                $fatal(1, "hcpu_idu_exu_regs payload changed while downstream remained stalled");
        end
        prev_post_stall <= o_post_valid && !i_post_ready;
        prev_protocol_bundle <= protocol_bundle;
    end
end
`endif

endmodule
