// HelloCPU Simulation Top - connects CPU to AXI RAM
module sim_top (
    input clock,
    input reset
);

// AXI Master signals from CPU
wire        m_awready, m_awvalid;
wire [31:0] m_awaddr;
wire [ 3:0] m_awid;
wire [ 7:0] m_awlen;
wire [ 2:0] m_awsize;
wire [ 1:0] m_awburst;
wire        m_wready, m_wvalid;
wire [31:0] m_wdata;
wire [ 3:0] m_wstrb;
wire        m_wlast;
wire        m_bready, m_bvalid;
wire [ 1:0] m_bresp;
wire [ 3:0] m_bid;
wire        m_arready, m_arvalid;
wire [31:0] m_araddr;
wire [ 3:0] m_arid;
wire [ 7:0] m_arlen;
wire [ 2:0] m_arsize;
wire [ 1:0] m_arburst;
wire        m_rready, m_rvalid;
wire [ 1:0] m_rresp;
wire [31:0] m_rdata;
wire        m_rlast;
wire [ 3:0] m_rid;

// CPU instance
ysyx_23060124 cpu (
    .clock              (clock),
    .reset              (reset),
    .io_interrupt       (1'b0),
    // Master
    .io_master_awready  (m_awready),
    .io_master_awvalid  (m_awvalid),
    .io_master_awaddr   (m_awaddr),
    .io_master_awid     (m_awid),
    .io_master_awlen    (m_awlen),
    .io_master_awsize   (m_awsize),
    .io_master_awburst  (m_awburst),
    .io_master_wready   (m_wready),
    .io_master_wvalid   (m_wvalid),
    .io_master_wdata    (m_wdata),
    .io_master_wstrb    (m_wstrb),
    .io_master_wlast    (m_wlast),
    .io_master_bready   (m_bready),
    .io_master_bvalid   (m_bvalid),
    .io_master_bresp    (m_bresp),
    .io_master_bid      (m_bid),
    .io_master_arready  (m_arready),
    .io_master_arvalid  (m_arvalid),
    .io_master_araddr   (m_araddr),
    .io_master_arid     (m_arid),
    .io_master_arlen    (m_arlen),
    .io_master_arsize   (m_arsize),
    .io_master_arburst  (m_arburst),
    .io_master_rready   (m_rready),
    .io_master_rvalid   (m_rvalid),
    .io_master_rresp    (m_rresp),
    .io_master_rdata    (m_rdata),
    .io_master_rlast    (m_rlast),
    .io_master_rid      (m_rid),
    // Slave - tie off (unused)
    .io_slave_awready   (),
    .io_slave_awvalid   (1'b0),
    .io_slave_awaddr    (32'b0),
    .io_slave_awid      (4'b0),
    .io_slave_awlen     (8'b0),
    .io_slave_awsize    (3'b0),
    .io_slave_awburst   (2'b0),
    .io_slave_wready    (),
    .io_slave_wvalid    (1'b0),
    .io_slave_wdata     (32'b0),
    .io_slave_wstrb     (4'b0),
    .io_slave_wlast     (1'b0),
    .io_slave_bready    (1'b0),
    .io_slave_bvalid    (),
    .io_slave_bresp     (),
    .io_slave_bid       (),
    .io_slave_arready   (),
    .io_slave_arvalid   (1'b0),
    .io_slave_araddr    (32'b0),
    .io_slave_arid      (4'b0),
    .io_slave_arlen     (8'b0),
    .io_slave_arsize    (3'b0),
    .io_slave_arburst   (2'b0),
    .io_slave_rready    (1'b0),
    .io_slave_rvalid    (),
    .io_slave_rresp     (),
    .io_slave_rdata     (),
    .io_slave_rlast     (),
    .io_slave_rid       ()
);

// AXI RAM instance
axi_ram ram (
    .clock   (clock),
    .resetn  (~reset),
    // AW
    .awready (m_awready),
    .awvalid (m_awvalid),
    .awaddr  (m_awaddr),
    .awid    (m_awid),
    .awlen   (m_awlen),
    .awsize  (m_awsize),
    .awburst (m_awburst),
    // W
    .wready  (m_wready),
    .wvalid  (m_wvalid),
    .wdata   (m_wdata),
    .wstrb   (m_wstrb),
    .wlast   (m_wlast),
    // B
    .bready  (m_bready),
    .bvalid  (m_bvalid),
    .bresp   (m_bresp),
    .bid     (m_bid),
    // AR
    .arready (m_arready),
    .arvalid (m_arvalid),
    .araddr  (m_araddr),
    .arid    (m_arid),
    .arlen   (m_arlen),
    .arsize  (m_arsize),
    .arburst (m_arburst),
    // R
    .rready  (m_rready),
    .rvalid  (m_rvalid),
    .rresp   (m_rresp),
    .rdata   (m_rdata),
    .rlast   (m_rlast),
    .rid     (m_rid)
);

endmodule
