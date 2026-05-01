module hcpu_RegisterFile (
    input                               clock                      ,
    input                               reset                      ,
    input              [  31:0]         wdata                      ,
    input              [   4:0]         waddr                      ,
  
    //
    input              [   4:0]         exu_rd                     ,
    input              [  31:0]         exu_wdata                  ,
    input                               exu_wen                    ,
    input                               exu_post_valid             ,
    input              [   4:0]         wbu_rd                     ,
    input              [  31:0]         wbu_wdata                  ,
    input                               wbu_wen                    ,
    // 
    input              [   4:0]         raddr1                     ,
    input              [   4:0]         raddr2                     ,

    output             [  31:0]         rdata1                     ,
    output             [  31:0]         rdata2                     ,
    input                               wen                         
);

reg  [31:0] regfile [31:1];
wire [31:0] rf      [31:0];

genvar i;
generate
  for(i = 1; i < 32; i = i + 1) begin
    assign rf[i] = regfile[i];
  end
endgenerate

assign rf[0] = 32'b0;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    integer j;
    for (j = 1; j < 32; j = j + 1) begin
      regfile[j] <= 32'b0;
    end
  end else if (wen && waddr != 0) begin
    regfile[waddr[4:0]] <= wdata;
  end
end

assign rdata1 = (raddr1 == exu_rd && exu_wen && exu_post_valid) ? exu_wdata:
                (raddr1 == wbu_rd && wbu_wen)  ? wbu_wdata:
                rf[raddr1[4:0]];

assign rdata2 = (raddr2 == exu_rd && exu_wen && exu_post_valid) ? exu_wdata:
                (raddr2 == wbu_rd && wbu_wen)  ? wbu_wdata:
                rf[raddr2[4:0]];


endmodule
