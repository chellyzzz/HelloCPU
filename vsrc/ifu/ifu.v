module ysyx_23060124_IFU
(
    input              [  31:0]         i_pc_next                  ,
    input                               clock                      ,
    input                               rst_n_sync                 ,
    input                               i_pc_update                ,
    input                               i_post_ready               ,
    output             [  31:0]         ins                        ,
    output reg         [  31:0]         pc_next                    ,
    //ifu_to_cache
    output             [  31:0]         req_addr                   ,
    input              [  31:0]         icache_ins                 ,
    input                               hit                         
);

localparam                              RESET_PC = 32'h3000_0000   ;

assign req_addr = pc_next;

always @(posedge  clock or negedge rst_n_sync) begin
  if (~rst_n_sync) pc_next <= RESET_PC;
  else if(i_pc_update) pc_next <= i_pc_next;
  else if(hit && i_post_ready) pc_next <= pc_next + 4;
  else pc_next <= pc_next;
end

assign ins = icache_ins;

endmodule
