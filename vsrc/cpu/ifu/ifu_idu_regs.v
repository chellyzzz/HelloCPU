module hcpu_ifu_idu_regs (
    input              [  31:0]         i_pc                       ,
    input              [  31:0]         i_ins                      ,
    output reg         [  31:0]         o_pc                       ,
    output reg         [  31:0]         o_ins                      ,
    input                               clock                      ,
    input                               reset                      ,
    // handshake signals
    input                               icache_hit              ,
    input                               i_pre_valid                ,
    input                               i_post_ready               ,
    output                              o_post_valid               ,

    // branch prediction fields
    input                               i_predict_taken            ,
    input              [  31:2]         i_predict_target           ,
    output reg                          o_predict_taken            ,
    output reg         [  31:2]         o_predict_target           

);

assign o_post_valid = icache_hit;

wire fetch_fire = icache_hit && i_post_ready;

always @(posedge clock or posedge reset) begin
    if(reset) begin
        o_pc            <= 32'h0;
        o_ins           <= 32'h0;
        o_predict_taken <= 1'b0;
        o_predict_target <= 30'b0;
    end
    else if(fetch_fire) begin
        o_pc            <= i_pc;
        o_ins           <= i_ins;
        o_predict_taken <= i_predict_taken;
        o_predict_target <= i_predict_target;
    end
    else if(~icache_hit && i_post_ready) begin
        o_pc            <= 32'h0;
        o_ins           <= 32'h0;
        o_predict_taken <= 1'b0;
        o_predict_target <= 30'b0;
    end
    else if(icache_hit && ~i_post_ready) begin
        o_pc            <= o_pc;
        o_ins           <= o_ins;
        o_predict_taken <= o_predict_taken;
        o_predict_target <= o_predict_target;
    end
end

endmodule
