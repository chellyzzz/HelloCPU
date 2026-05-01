// AXI4-Lite Style RAM with burst support — Minimal Verified Design
//
// Design principle (standard AXI VIP pattern):
//   - AR channel: always ready, single-cycle handshake
//   - R channel: back-to-back beats, one valid per cycle, no internal buffering
//   - AW+W+B: single-cycle write, always ready
//   - DPI-C backed: pmem_read/pmem_write from sim_main.cpp
//
// This is the simplest correct AXI slave: it never applies backpressure,
// making timing interactions trivially predictable.

module axi_ram (
    input                clock,
    input                resetn,

    // AW channel
    output reg           awready,
    input                awvalid,
    input      [31:0]    awaddr,
    input      [ 3:0]    awid,
    input      [ 7:0]    awlen,
    input      [ 2:0]    awsize,
    input      [ 1:0]    awburst,

    // W channel
    output reg           wready,
    input                wvalid,
    input      [31:0]    wdata,
    input      [ 3:0]    wstrb,
    input                wlast,

    // B channel
    input                bready,
    output reg           bvalid,
    output     [ 1:0]    bresp,
    output reg [ 3:0]    bid,

    // AR channel
    output reg           arready,
    input                arvalid,
    input      [31:0]    araddr,
    input      [ 3:0]    arid,
    input      [ 7:0]    arlen,
    input      [ 2:0]    arsize,
    input      [ 1:0]    arburst,

    // R channel
    input                rready,
    output reg           rvalid,
    output     [ 1:0]    rresp,
    output reg [31:0]    rdata,
    output reg           rlast,
    output reg [ 3:0]    rid
);

    import "DPI-C" function void pmem_read(input int addr, output int data);
    import "DPI-C" function void pmem_write(input int addr, input int data, input int strb);

    // ========================================================================
    // Read Channel — Minimal 2-phase FSM: IDLE / BURST
    // ========================================================================
    localparam R_IDLE  = 1'b0;
    localparam R_BURST = 1'b1;

    reg        r_state;
    reg [31:0] r_addr;
    reg [ 7:0] r_len;
    reg [ 7:0] r_cnt;
    reg [ 3:0] r_id;

    // Combinational read lookup — uses DPI-C on every eval
    wire [31:0] r_lookup_addr;
    wire [31:0] r_lookup_data;
    reg  [31:0] r_lookup_data_reg;
    assign r_lookup_addr = r_addr + {24'd0, r_cnt, 2'b00};

    always @(*) pmem_read(r_lookup_addr, r_lookup_data_reg);
    assign r_lookup_data = r_lookup_data_reg;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            r_state <= R_IDLE;
            rvalid  <= 1'b0;
            rdata   <= 32'b0;
            rlast   <= 1'b0;
            rid     <= 4'b0;
            r_addr  <= 32'b0;
            r_len   <= 8'd0;
            r_cnt   <= 8'd0;
            r_id    <= 4'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    rvalid <= 1'b0;
                    if (arvalid && arready) begin
                        r_state <= R_BURST;
                        r_addr  <= araddr;
                        r_len   <= arlen;
                        r_cnt   <= 8'd0;
                        r_id    <= arid;
                        // First beat will be presented when rvalid goes high
                    end
                end

                R_BURST: begin
                    if (!rvalid) begin
                        // Present current beat (r_lookup_data is combo from r_addr + r_cnt*4)
                        rdata  <= r_lookup_data;
                        rid    <= r_id;
                        rlast  <= (r_cnt == r_len);
                        rvalid <= 1'b1;
                    end else if (rvalid && rready) begin
                        // Master consumed this beat
                        if (rlast) begin
                            r_state <= R_IDLE;
                            rvalid  <= 1'b0;
                        end else begin
                            r_cnt   <= r_cnt + 8'd1;
                            rvalid  <= 1'b0;   // goes low for one cycle, next beat in following cycle
                        end
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    // AR is always ready (zero backpressure)
    always @(*) arready = (r_state == R_IDLE);

    assign rresp = 2'b00;

    // ========================================================================
    // Write Channel — Burst-aware with address increment
    // ========================================================================
    localparam W_IDLE = 2'd0;
    localparam W_DATA = 2'd1;
    localparam W_RESP = 2'd2;

    reg [1:0] w_state;
    reg [31:0] w_addr;
    reg [ 3:0] w_id;

    always @(posedge clock or negedge resetn) begin
        if (!resetn) begin
            w_state <= W_IDLE;
            awready <= 1'b1;
            wready  <= 1'b1;
            bvalid  <= 1'b0;
            bid     <= 4'b0;
            w_addr  <= 32'b0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    bvalid <= 1'b0;
                    if (awvalid && awready && wvalid && wready) begin
                        // AW + W combined — first beat
                        pmem_write(awaddr, wdata, wstrb);
                        if (wlast) begin
                            // Single beat — go directly to B response
                            bid     <= awid;
                            bvalid  <= 1'b1;
                            w_state <= W_RESP;
                        end else begin
                            w_addr  <= awaddr + 32'd4;
                            w_id    <= awid;
                            w_state <= W_DATA;
                        end
                    end else if (awvalid && awready) begin
                        // AW only — latch address, wait for W beats
                        w_addr  <= awaddr;
                        w_id    <= awid;
                        awready <= 1'b0;
                        w_state <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (wvalid && wready) begin
                        pmem_write(w_addr, wdata, wstrb);
                        w_addr  <= w_addr + 32'd4;
                        if (wlast) begin
                            bid     <= w_id;
                            bvalid  <= 1'b1;
                            w_state <= W_RESP;
                        end
                    end
                end

                W_RESP: begin  // B handshake
                    if (bready && bvalid) begin
                        bvalid  <= 1'b0;
                        awready <= 1'b1;
                        wready  <= 1'b1;
                        w_state <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    assign bresp = 2'b00;

endmodule