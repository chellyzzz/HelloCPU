module hcpu_Xbar(
    input                               clock                      ,
    input                               RESETN                      ,
    // IFU AXI-FULL Interface
    output             [  31:0]         IFU_RDATA                  ,
    output             [   1:0]         IFU_RRESP                  ,
    output                              IFU_RVALID                 ,
    input                               IFU_RREADY                 ,
    output                              IFU_RLAST                  ,
    output             [   3:0]         IFU_RID                    ,

    input              [  31:0]         IFU_ARADDR                 ,
    input                               IFU_ARVALID                ,
    output                              IFU_ARREADY                ,
    input              [   3:0]         IFU_ARID                   ,
    input              [   7:0]         IFU_ARLEN                  ,
    input              [   2:0]         IFU_ARSIZE                 ,
    input              [   1:0]         IFU_ARBURST                ,

    // LSU AXI-FULL Interface
    output             [  31:0]         LSU_RDATA                  ,
    output             [   1:0]         LSU_RRESP                  ,
    output                              LSU_RVALID                 ,
    input                               LSU_RREADY                 ,
    output                              LSU_RLAST                  ,
    output             [   3:0]         LSU_RID                    ,

    input              [  31:0]         LSU_ARADDR                 ,
    input                               LSU_ARVALID                ,
    output                              LSU_ARREADY                ,
    input              [   3:0]         LSU_ARID                   ,
    input              [   7:0]         LSU_ARLEN                  ,
    input              [   2:0]         LSU_ARSIZE                 ,
    input              [   1:0]         LSU_ARBURST                ,

    output             [   1:0]         LSU_BRESP                  ,
    output                              LSU_BVALID                 ,
    input                               LSU_BREADY                 ,
    output             [   3:0]         LSU_BID                    ,

    input              [  31:0]         LSU_AWADDR                 ,
    input                               LSU_AWVALID                ,
    output                              LSU_AWREADY                ,
    input              [   3:0]         LSU_AWID                   ,
    input              [   7:0]         LSU_AWLEN                  ,
    input              [   2:0]         LSU_AWSIZE                 ,
    input              [   1:0]         LSU_AWBURST                ,

    input              [  31:0]         LSU_WDATA                  ,
    input              [   3:0]         LSU_WSTRB                  ,
    input                               LSU_WVALID                 ,
    input                               LSU_WLAST                  ,
    output                              LSU_WREADY                 ,

    output                              CLINT_ARADDR               ,
    output             [   3:0]         CLINT_ARID                 ,
    output                              CLINT_ARVALID              ,
    input                               CLINT_ARREADY              ,
    output             [   7:0]         CLINT_ARLEN                ,
    output             [   2:0]         CLINT_ARSIZE               ,
    output             [   1:0]         CLINT_ARBURST              ,

    input              [  31:0]         CLINT_RDATA                ,
    input              [   1:0]         CLINT_RRESP                ,
    input                               CLINT_RVALID               ,
    output                              CLINT_RREADY               ,
    input              [   3:0]         CLINT_RID                  ,
    input                               CLINT_RLAST                ,

    // SRAM AXI-Lite Interface
    output             [  31:0]         SRAM_AWADDR                ,
    output                              SRAM_AWVALID               ,
    input                               SRAM_AWREADY               ,
    output             [   3:0]         SRAM_AWID                  ,
    output             [   7:0]         SRAM_AWLEN                 ,
    output             [   2:0]         SRAM_AWSIZE                ,
    output             [   1:0]         SRAM_AWBURST               ,
    output             [  31:0]         SRAM_WDATA                 ,
    output             [   3:0]         SRAM_WSTRB                 ,
    output                              SRAM_WVALID                ,
    input                               SRAM_WREADY                ,
    output                              SRAM_WLAST                 ,
    input              [   1:0]         SRAM_BRESP                 ,
    input                               SRAM_BVALID                ,
    output                              SRAM_BREADY                ,
    input              [   3:0]         SRAM_BID                   ,
    output             [  31:0]         SRAM_ARADDR                ,
    output             [   3:0]         SRAM_ARID                  ,
    output                              SRAM_ARVALID               ,
    input                               SRAM_ARREADY               ,
    output             [   7:0]         SRAM_ARLEN                 ,
    output             [   2:0]         SRAM_ARSIZE                ,
    output             [   1:0]         SRAM_ARBURST               ,
    input              [  31:0]         SRAM_RDATA                 ,
    input              [   1:0]         SRAM_RRESP                 ,
    input                               SRAM_RVALID                ,
    output                              SRAM_RREADY                ,
    input              [   3:0]         SRAM_RID                   ,
    input                               SRAM_RLAST

);

wire ifu_req;
wire lsu_req;
wire ifu_ram_finish;
wire lsu_ram_finish;
assign ifu_req = IFU_ARVALID;
assign lsu_req = LSU_AWVALID || LSU_ARVALID;
assign ifu_ram_finish = (SRAM_RVALID && SRAM_RLAST && IFU_RREADY);
assign lsu_ram_finish = (SRAM_BVALID && LSU_BREADY) || (SRAM_RVALID && SRAM_RLAST && LSU_RREADY);

reg [2:0] state;
localparam IDLE         = 3'b000;
localparam LSU_CLINT    = 3'b001;
localparam IFU_RAM      = 3'b010;
localparam LSU_RAM      = 3'b100;

    always @(posedge clock or negedge RESETN) begin
        if (RESETN == 1'b0) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if(lsu_req) begin
                        state <= LSU_ARADDR[31:31-7] == 8'h02 ? LSU_CLINT : LSU_RAM;
                    end
                    else if (ifu_req) begin
                        state <= IFU_RAM;
                    end
                    else state <= IDLE;
                end
                LSU_CLINT: begin
                    if(LSU_RREADY)     state <= IDLE;
                end
                IFU_RAM: begin
                    if(ifu_ram_finish) state <= IDLE;
                end
                LSU_RAM: begin
                    if(lsu_ram_finish) state <= IDLE;
                end
            default: state <= IDLE;
            endcase
        end
    end

assign IFU_ARREADY = state[1] ? SRAM_ARREADY : 'b0;
assign IFU_RVALID  = state[1] ? SRAM_RVALID  : 'b0;
assign IFU_RDATA   = state[1] ? SRAM_RDATA   : 'b0;
assign IFU_RRESP   = state[1] ? SRAM_RRESP   : 'b0;
assign IFU_RLAST   = state[1] ? SRAM_RLAST   : 'b0;
assign IFU_RID     = state[1] ? SRAM_RID     : 'b0;

// LSU signals
assign LSU_AWREADY = state[2] ? SRAM_AWREADY : 'b0;
assign LSU_WREADY  = state[2] ? SRAM_WREADY  : 'b0;
assign LSU_BVALID  = state[2] ? SRAM_BVALID  : 'b0;
assign LSU_BRESP   = state[2] ? SRAM_BRESP   : 'b0;
assign LSU_BID     = state[2] ? SRAM_BID     : 'b0;
assign LSU_ARREADY = state[2] ? SRAM_ARREADY : (state[0] ? CLINT_ARREADY: 'b0);
assign LSU_RVALID  = state[2] ? SRAM_RVALID  : (state[0] ? CLINT_RVALID : 'b0);
assign LSU_RDATA   = state[2] ? SRAM_RDATA   : (state[0] ? CLINT_RDATA  : 'b0);
assign LSU_RRESP   = state[2] ? SRAM_RRESP   : (state[0] ? CLINT_RRESP  : 'b0);
assign LSU_RLAST   = state[2] ? SRAM_RLAST   : (state[0] ? CLINT_RLAST  : 'b0);
assign LSU_RID     = state[2] ? SRAM_RID     : (state[0] ? CLINT_RID    : 'b0);

// SRAM signals
// assign SRAM_AWADDR  = state[2] ? LSU_AWADDR  : 'b0;
assign SRAM_AWADDR  = LSU_AWADDR;
assign SRAM_AWVALID = state[2] ? LSU_AWVALID : 'b0;
assign SRAM_AWID    = state[2] ? LSU_AWID    : 'b0;
assign SRAM_WDATA   = state[2] ? LSU_WDATA   : 'b0;
assign SRAM_WVALID  = state[2] ? LSU_WVALID  : 'b0;
assign SRAM_WSTRB   = state[2] ? LSU_WSTRB   : 'b0;
assign SRAM_WLAST   = state[2] ? LSU_WLAST   : 'b0;
assign SRAM_BREADY  = state[2] ? LSU_BREADY  : 'b0;

assign SRAM_ARADDR  = state[2] ? LSU_ARADDR  :  IFU_ARADDR;
assign SRAM_ARID    = state[2] ? LSU_ARID    : (state[1] ? IFU_ARID    : 'b0);
assign SRAM_ARVALID = state[2] ? LSU_ARVALID : (state[1] ? IFU_ARVALID : 'b0);
assign SRAM_RREADY  = state[2] ? LSU_RREADY  : (state[1] ? IFU_RREADY  : 'b0);
assign SRAM_ARLEN   = state[2] ? LSU_ARLEN   : (state[1] ? IFU_ARLEN   : 'b0);
assign SRAM_ARSIZE  = state[2] ? LSU_ARSIZE  : (state[1] ? IFU_ARSIZE  : 'b0);
assign SRAM_ARBURST = state[2] ? LSU_ARBURST : (state[1] ? IFU_ARBURST : 'b0);

assign SRAM_AWLEN   = state[2] ? LSU_AWLEN   : 'b0;
assign SRAM_AWSIZE  = state[2] ? LSU_AWSIZE  : 'b0;
assign SRAM_AWBURST = state[2] ? LSU_AWBURST : 'b0;

// CLINT signals
assign CLINT_ARADDR  = LSU_ARADDR[2];
assign CLINT_ARVALID = (state[0]) ? LSU_ARVALID     : 0;
assign CLINT_ARID    = (state[0]) ? LSU_ARID        : 0;
assign CLINT_RREADY  = (state[0]) ? LSU_RREADY      : 0;
assign CLINT_ARLEN   = (state[0]) ? LSU_ARLEN       : 0;
assign CLINT_ARSIZE  = (state[0]) ? LSU_ARSIZE      : 0;
assign CLINT_ARBURST = (state[0]) ? LSU_ARBURST     : 0;

endmodule
