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
    output                              o_post_valid                

);

reg post_valid;
assign o_post_valid = i_post_ready && icache_hit;

// always @(posedge clock or posedge reset) begin
//     if(reset) begin
//         post_valid <= 1'b0;   
//     end
//     else if(icache_hit) begin
//         post_valid <= 1'b1;
//     end
//     else if(~icache_hit)begin
//         post_valid <= 1'b0;
//     end
// end


always @(posedge clock or posedge reset) begin
    if(reset) begin
        o_pc <= 32'h0;
        o_ins <= 32'h0;
    end
    else if(icache_hit && i_post_ready) begin
        o_pc <= i_pc;
        o_ins <= i_ins;
    end
    else if(~icache_hit && i_post_ready) begin
        o_pc <= 32'h0;
        o_ins <= 32'h0;
    end
    else if(icache_hit && ~i_post_ready) begin
        o_pc <= o_pc;
        o_ins <= o_ins;
    end
end

endmodule   
