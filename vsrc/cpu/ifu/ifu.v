module hcpu_IFU
(
    input              [  31:0]         i_pc_next                  ,
    input                               clock                      ,
    input                               rst_n_sync                 ,
    input                               i_pc_update                ,
    input                               i_post_ready               ,
    output             [  31:0]         ins                        ,
    output reg         [  31:0]         pc_next                    ,

    // Branch predictor interface
    input                               btb_predict_taken          ,
    input              [  31:2]         btb_predict_target         ,
    input                               btb_lookup_hit             ,
    input                               ras_predict_valid          ,
    input              [  31:2]         ras_predict_target         ,

    // Mispredict recovery from EXU
    input                               exu_mispredict_flush       ,
    input              [  31:0]         exu_redirect_pc            ,

    // Prediction outputs (to pipeline registers)
    output                              o_predict_taken            ,
    output             [  31:2]         o_predict_target           ,
    output                              o_predict_btb_hit          ,

    // ICache interface
    output             [  31:0]         req_addr                   ,
    input              [  31:0]         icache_ins                 ,
    input                               hit                        
);

localparam                              RESET_PC = 32'h3000_0000   ;

assign req_addr = pc_next;

wire is_brch = (icache_ins[6:0] == 7'b1100011);
wire is_jal  = (icache_ins[6:0] == 7'b1101111);
wire is_jalr = (icache_ins[6:0] == 7'b1100111);
wire is_ret  = is_jalr && (icache_ins[11:7] == 5'd0);

`ifdef DISABLE_BTB_PRED
wire pred_taken_btb = 1'b0;
`else
wire pred_taken_btb = is_brch && btb_predict_taken;
`endif
wire pred_taken_jal = is_jal;
wire pred_taken_ras = is_ret && ras_predict_valid;

wire [31:0] brch_imm = {{20{icache_ins[31]}}, icache_ins[7], icache_ins[30:25], icache_ins[11:8], 1'b0};
wire [31:0] brch_target = pc_next + brch_imm;
wire [31:0] jal_imm = {{12{icache_ins[31]}}, icache_ins[19:12], icache_ins[20], icache_ins[30:21], 1'b0};
wire [31:0] jal_target = pc_next + jal_imm;

wire [31:2] pred_target = is_jal          ? jal_target[31:2] :
                           pred_taken_ras ? ras_predict_target :
                           (pred_taken_btb && !btb_lookup_hit) ? brch_target[31:2] :
                           btb_predict_target;

wire pred_taken_comb = pred_taken_btb || pred_taken_jal || pred_taken_ras;

assign o_predict_taken  = hit && pred_taken_comb;
assign o_predict_target = pred_target;
assign o_predict_btb_hit = hit && is_brch && btb_lookup_hit;

wire [31:0] next_seq_pc = pc_next + 32'd4;
wire [31:0] next_pred_pc = {pred_target, 2'b00};
wire fetch_fire = hit && i_post_ready;

always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync)
        pc_next <= RESET_PC;
    else if (exu_mispredict_flush)
        pc_next <= exu_redirect_pc;
    else if (i_pc_update)
        pc_next <= i_pc_next;
    else if (fetch_fire)
        pc_next <= pred_taken_comb ? next_pred_pc : next_seq_pc;
    else
        pc_next <= pc_next;
end

assign ins = icache_ins;

endmodule
