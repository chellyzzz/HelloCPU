module hcpu_WBU (
    input                               clock                      ,
    input                               reset                      ,
    input                               i_pre_valid                ,
    input                               i_wen                      ,
    input              [   4:0]         i_rd_addr                  ,
    input              [  11:0]         i_csr_addr                 ,
    input                               i_csr_wen                  ,
    input                               i_brch                     ,
    input                               i_jal                      ,
    input                               i_jalr                     ,
    input                               i_ebreak                   ,
    input                               i_mret                     ,
    input                               i_ecall                    ,
    input                               i_predict_taken            ,
    input              [  31:0]         i_pc_next                  ,

    input              [  31:0]         i_res                      ,

    output reg         [  31:0]         o_pc_next                  ,
    output             [  31:0]         o_rd_wdata                 ,
    output             [  31:0]         o_csr_rd_wdata             ,
    output                              o_wbu_wen                  ,
    output                              o_wbu_csr_wen              ,
    output             [   4:0]         o_rd_addr                  ,
    output             [  11:0]         o_csr_addr                 ,

    output reg                          o_pre_ready                ,
    output reg                          o_pc_update                 
);


assign o_rd_wdata       = i_res;
assign o_csr_rd_wdata   = i_res;
assign o_wbu_wen        = i_wen ;
assign o_wbu_csr_wen    = i_csr_wen ;
assign o_rd_addr        =  i_rd_addr ;
assign o_csr_addr       =  i_csr_addr;

always @(posedge clock or posedge reset) begin
  if(reset) begin
    o_pre_ready <= 1'b1;
  end
  else begin
    o_pre_ready <= o_pre_ready;
  end
end

always @(posedge clock or posedge reset) begin
  if(reset) begin
    o_pc_update <= 1'b0;
    o_pc_next <= 32'b0;
  end
  else if(~o_pc_update) begin
    o_pc_update <= i_jal || i_jalr || i_brch  || i_ecall || i_mret;
    o_pc_next <= i_pc_next;
  end
  else if(o_pc_update) begin
    o_pc_update <= 1'b0;
    o_pc_next <= 32'b0;
  end
end

endmodule
