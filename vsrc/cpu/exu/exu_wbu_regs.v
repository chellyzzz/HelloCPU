module hcpu_exu_wbu_regs (
    input                               clock                      ,
    input                               reset                      ,
    input                               i_brch                     ,
    input                               i_jal                      ,
    input                               i_wen                      ,
    input                               i_csr_wen                  ,
    //TODO: combine addr_rd and csr_addr into one input
    //TODO: i_csr_wen adn i_wen into one input
    input                               i_jalr                     ,
    input                               i_ebreak                   ,
    input                               i_mret                     ,
    input                               i_ecall                    ,
    input                               i_predict_taken            ,
    input                               i_predict_correct          ,

    input                               i_load                     ,
    input                               i_store                    ,
    input                               i_muldiv                   ,
    input                               i_fence_i                  ,
    input                               i_is_brch                  ,
    input                               i_is_div                   ,

    input              [  31:0]         i_res                      ,
    input              [  31:0]         i_pc                       ,
    input              [  31:0]         i_pc_next                  ,
    input              [  11:0]         i_csr_addr                 ,
    input              [   4:0]         i_rd_addr                  ,

    output reg         [  31:0]         o_pc_next                  ,
    output reg         [  31:0]         o_pc                       ,
    output reg         [  11:0]         o_csr_addr                 ,
    output reg         [   4:0]         o_rd_addr                  ,
    //
    output reg                          o_wen                      ,
    output reg                          o_csr_wen                  ,
    //
    output reg                          o_brch                     ,
    output reg                          o_jal                      ,
    output reg                          o_jalr                     ,
    output reg                          o_mret                     ,
    output reg                          o_ecall                    ,
    output reg                          o_predict_taken            ,
    output reg                          o_predict_correct          ,
    output reg                          o_ebreak                   ,
    //
    output reg                          o_load                     ,
    output reg                          o_store                    ,
    output reg                          o_muldiv                   ,
    output reg                          o_fence_i                  ,
    output reg                          o_is_brch                  ,
    output reg                          o_is_div                   ,
    //
    output reg         [  31:0]         o_res                      ,
    output reg                          o_valid                    ,  // valid for data in this register
    input                               i_post_ready               ,
    input                               o_post_valid               ,  // from EXU
    input                               i_flush                      // gate latch (mispredict-related)
);

always @(posedge clock or posedge reset) begin
    if(reset) begin
        o_pc_next   <= 'b0;
        o_pc        <= 'b0;
        o_csr_addr  <= 'b0;
        o_rd_addr   <= 'b0;
        o_wen       <= 'b0;
        o_csr_wen   <= 'b0;
        o_brch      <= 'b0;
        o_jal       <= 'b0;
        o_jalr      <= 'b0;
        o_mret      <= 'b0;
        o_ecall         <= 'b0;
        o_predict_taken <= 'b0;
        o_predict_correct <= 'b0;
        o_res           <= 'b0;
        o_ebreak    <= 'b0;
        o_load      <= 'b0;
        o_store     <= 'b0;
        o_muldiv    <= 'b0;
        o_fence_i   <= 'b0;
        o_is_brch   <= 'b0;
        o_is_div    <= 'b0;
        o_valid     <= 1'b0;
    end
    else if(i_post_ready && i_flush) begin
        o_valid <= 1'b0;
    end
    else if(i_post_ready && o_post_valid) begin
        o_pc_next   <= i_pc_next;
        o_pc        <= i_pc;
        o_csr_addr  <= i_csr_addr;
        o_rd_addr   <= i_rd_addr;
        o_wen       <= i_wen;
        o_csr_wen   <= i_csr_wen;
        o_brch      <= i_brch;
        o_jal       <= i_jal;
        o_jalr      <= i_jalr;
        o_mret      <= i_mret;
        o_ecall         <= i_ecall;
        o_predict_taken <= i_predict_taken;
        o_predict_correct <= i_predict_correct;
        o_res           <= i_res;
        o_ebreak    <= i_ebreak;
        o_load      <= i_load;
        o_store     <= i_store;
        o_muldiv    <= i_muldiv;
        o_fence_i   <= i_fence_i;
        o_is_brch   <= i_is_brch;
        o_is_div    <= i_is_div;
        o_valid     <= 1'b1;
    end
    else if(i_post_ready && ~o_post_valid) begin
        o_pc_next   <= 'b0;
        o_pc        <= 'b0;
        o_csr_addr  <= 'b0;
        o_rd_addr   <= 'b0;
        o_wen       <= 'b0;
        o_csr_wen   <= 'b0;
        o_brch      <= 'b0;
        o_jal       <= 'b0;
        o_jalr      <= 'b0;
        o_mret      <= 'b0;
        o_ecall         <= 'b0;
        o_predict_taken <= 'b0;
        o_predict_correct <= 'b0;
        o_res           <= 'b0;
        o_ebreak        <= 'b0;
        o_load      <= 'b0;
        o_store     <= 'b0;
        o_muldiv    <= 'b0;
        o_fence_i   <= 'b0;
        o_is_brch   <= 'b0;
        o_is_div    <= 'b0;
        o_valid     <= 1'b0;
    end
end
endmodule
