module hcpu_CSR_RegisterFile (
    input                               clock                      ,
    input                               reset                        ,
    input                               i_csr_wen                  ,
    input                               i_ecall                    ,
    input                               i_mret                     ,
    input              [  31:0]         i_pc                       ,

    input              [  11:0]         i_csr_raddr                ,
    output             [  31:0]         o_csr_rdata                ,
    input              [  11:0]         i_csr_raddr2               ,
    output             [  31:0]         o_csr_rdata2               ,

    input              [  11:0]         i_csr_waddr                ,
    input              [  31:0]         i_csr_wdata                ,

    output             [  31:0]         o_mepc                     ,
    output             [  31:0]         o_mtvec
);
// hcpu
wire [31:0] mvendorid , marchid;
wire [31:0] mcause;
assign mvendorid    = 32'h79737978;
assign marchid      = 32'h00000001;
assign mcause       = 32'd11;

reg [12:0] mstatus;
reg [31:0] mepc;
reg [31:0] mtvec;
reg [31:0] mcycle;

always @(posedge  clock or posedge reset) begin
    if(reset) begin
        mstatus <= 13'b0;
        mepc <= 32'b0;
        mtvec <= 32'b0;
        mcycle <= 32'b0;
    end
    else if(i_ecall)begin
        mepc    <= i_pc;
        mstatus[7] <= mstatus[3];
        mstatus[12:11] <= 2'b11;
        mstatus[3] <= 1'b0;
    end
    else if(i_mret)begin
        mepc <= mepc;
        mstatus[3] <= mstatus[7];
        mstatus[7] <= 1'b1;
        mstatus[12:11] <= 2'b0;
    end
    else if (i_csr_wen) begin
        case (i_csr_waddr)
            12'h341: mepc       <= i_csr_wdata;
            12'h305: mtvec      <= i_csr_wdata;
            default: begin
            end
        endcase
    end
    else begin
        mtvec <= mtvec;
        mepc <= mepc;
        mstatus <= mstatus;
    end
    mcycle <= mcycle + 1;
end
// always @(*) begin
//     case(i_csr_raddr)
//         12'hf11: o_csr_rdata = mvendorid;
//         12'hf12: o_csr_rdata = marchid;
//         12'h300: o_csr_rdata = mstatus;
//         12'h341: o_csr_rdata = mepc;
//         12'h342: o_csr_rdata = mcause;
//         12'h305: o_csr_rdata = mtvec;
//         default: o_csr_rdata = 32'b0;
//     endcase
// end

assign o_csr_rdata  = i_csr_raddr == 12'hf11 ? mvendorid :
                      i_csr_raddr == 12'hf12 ? marchid :
                      i_csr_raddr == 12'h300 ? {19'b0, mstatus} :
                      i_csr_raddr == 12'h341 ? mepc :
                      i_csr_raddr == 12'h342 ? mcause :
                      i_csr_raddr == 12'h305 ? mtvec :
                      i_csr_raddr == 12'hb00 ? mcycle :
                      32'b0;

assign o_csr_rdata2 = i_csr_raddr2 == 12'hf11 ? mvendorid :
                      i_csr_raddr2 == 12'hf12 ? marchid :
                      i_csr_raddr2 == 12'h300 ? {19'b0, mstatus} :
                      i_csr_raddr2 == 12'h341 ? mepc :
                      i_csr_raddr2 == 12'h342 ? mcause :
                      i_csr_raddr2 == 12'h305 ? mtvec :
                      i_csr_raddr2 == 12'hb00 ? mcycle :
                      32'b0;

assign o_mepc       = i_mret    ? mepc  : 32'b0;
assign o_mtvec      = i_ecall   ? mtvec : 32'b0;

endmodule
