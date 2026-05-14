module scalar_mem_pending_kill_top(
    input         clock,
    input         reset,
    input         tb_scalar_flush,
    input         tb_hold_read_resp,
    output        tb_scalar_mem_req_valid,
    output        tb_scalar_mem_resp_valid,
    output        tb_scalar_mem_service_req_valid,
    output        tb_scalar_mem_kill_pending,
    output        tb_mem_owner_scalar_active,
    output        tb_mem_service_req_valid,
    output        tb_mem_service_resp_valid,
    output        tb_scalar_mem_ar_fire,
    output        tb_scalar_mem_r_fire,
    output [31:0] tb_scalar_mem_addr,
    output [31:0] tb_mem_service_addr,
    output [31:0] tb_araddr
);

    wire        m_awready, m_awvalid;
    wire        m_wready, m_wvalid;
    wire        m_bready, m_bvalid;
    wire [31:0] m_awaddr;
    wire [ 3:0] m_awid;
    wire [ 7:0] m_awlen;
    wire [ 2:0] m_awsize;
    wire [ 1:0] m_awburst;
    wire [31:0] m_wdata;
    wire [ 3:0] m_wstrb;
    wire        m_wlast;
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
    wire        ram_rready, ram_rvalid;
    wire [ 1:0] ram_rresp;
    wire [31:0] ram_rdata;
    wire        ram_rlast;
    wire [ 3:0] ram_rid;

    hcpu cpu (
        .clock              (clock),
        .reset              (reset),
        .io_interrupt       (1'b0),
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
        .io_slave_rid       (),
        .tb_scalar_flush    (tb_scalar_flush),
        .tb_scalar_mem_req_valid(tb_scalar_mem_req_valid),
        .tb_scalar_mem_resp_valid(tb_scalar_mem_resp_valid),
        .tb_scalar_mem_service_req_valid(tb_scalar_mem_service_req_valid),
        .tb_scalar_mem_kill_pending(tb_scalar_mem_kill_pending),
        .tb_mem_owner_scalar_active(tb_mem_owner_scalar_active),
        .tb_mem_service_req_valid(tb_mem_service_req_valid),
        .tb_mem_service_resp_valid(tb_mem_service_resp_valid),
        .tb_scalar_mem_ar_fire(tb_scalar_mem_ar_fire),
        .tb_scalar_mem_r_fire(tb_scalar_mem_r_fire),
        .tb_scalar_mem_addr (tb_scalar_mem_addr),
        .tb_mem_service_addr(tb_mem_service_addr)
    );

    assign m_rvalid = tb_hold_read_resp ? 1'b0 : ram_rvalid;
    assign m_rresp = ram_rresp;
    assign m_rdata = ram_rdata;
    assign m_rlast = tb_hold_read_resp ? 1'b0 : ram_rlast;
    assign m_rid = ram_rid;
    assign ram_rready = tb_hold_read_resp ? 1'b0 : m_rready;
    assign tb_araddr = m_araddr;

    axi_ram ram (
        .clock   (clock),
        .resetn  (~reset),
        .awready (m_awready),
        .awvalid (m_awvalid),
        .awaddr  (m_awaddr),
        .awid    (m_awid),
        .awlen   (m_awlen),
        .awsize  (m_awsize),
        .awburst (m_awburst),
        .wready  (m_wready),
        .wvalid  (m_wvalid),
        .wdata   (m_wdata),
        .wstrb   (m_wstrb),
        .wlast   (m_wlast),
        .bready  (m_bready),
        .bvalid  (m_bvalid),
        .bresp   (m_bresp),
        .bid     (m_bid),
        .arready (m_arready),
        .arvalid (m_arvalid),
        .araddr  (m_araddr),
        .arid    (m_arid),
        .arlen   (m_arlen),
        .arsize  (m_arsize),
        .arburst (m_arburst),
        .rready  (ram_rready),
        .rvalid  (ram_rvalid),
        .rresp   (ram_rresp),
        .rdata   (ram_rdata),
        .rlast   (ram_rlast),
        .rid     (ram_rid)
    );

endmodule
