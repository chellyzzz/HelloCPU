module hcpu_LSU #(
    parameter ADDR_WIDTH      = 32,
    parameter DATA_WIDTH      = 32,
    parameter SET_NUMS        = 64,
    parameter WAY_NUMS        = 4,
    parameter WORDS_PER_BLOCK = 4,
    parameter CACHE_START     = 32'h30000000,
    parameter CACHE_END       = 32'h40000000
)(
    input                               clock                      ,
    input                               reset                      ,
    input              [  31:0]         store_src                  ,
    input              [  31:0]         alu_res                    ,
    input              [   2:0]         exu_opt                    ,
    output             [  31:0]         load_res                   ,
    input                               i_load                     ,
    input                               i_store                    ,

    // AXI Write Address Channel
    output             [  31:0]         M_AXI_AWADDR               ,
    output                              M_AXI_AWVALID              ,
    input                               M_AXI_AWREADY              ,
    output             [   7:0]         M_AXI_AWLEN                ,
    output             [   2:0]         M_AXI_AWSIZE               ,
    output             [   1:0]         M_AXI_AWBURST              ,
    output             [   3:0]         M_AXI_AWID                 ,

    // AXI Write Data Channel
    output                              M_AXI_WVALID               ,
    input                               M_AXI_WREADY               ,
    output             [  31:0]         M_AXI_WDATA                ,
    output             [   3:0]         M_AXI_WSTRB                ,
    output                              M_AXI_WLAST                ,

    // AXI Read Data Channel
    input              [  31:0]         M_AXI_RDATA                ,
    input              [   1:0]         M_AXI_RRESP                ,
    input                               M_AXI_RVALID               ,
    output                              M_AXI_RREADY               ,
    input              [   3:0]         M_AXI_RID                  ,
    input                               M_AXI_RLAST                ,

    // AXI Read Address Channel
    output             [  31:0]         M_AXI_ARADDR               ,
    output                              M_AXI_ARVALID              ,
    input                               M_AXI_ARREADY              ,
    output             [   3:0]         M_AXI_ARID                 ,
    output             [   7:0]         M_AXI_ARLEN                ,
    output             [   2:0]         M_AXI_ARSIZE               ,
    output             [   1:0]         M_AXI_ARBURST              ,

    // AXI Write Response Channel
    input              [   1:0]         M_AXI_BRESP                ,
    input                               M_AXI_BVALID               ,
    output                              M_AXI_BREADY               ,
    input              [   3:0]         M_AXI_BID                  ,

    // Pipeline handshake
    input                               o_pre_ready                ,
    output                              lsu_done                   ,

    // debug / perf classification
    output                              o_dbg_wait_start           ,
    output                              o_dbg_wait_hit             ,
    output                              o_dbg_wait_refill          ,
    output                              o_dbg_wait_refill_ar       ,
    output                              o_dbg_wait_refill_r        ,
    output                              o_dbg_wait_uncached        ,
    output                              o_dbg_wait_wb
);
`include "debug_macros.vh"
// `define DCACHE_DEBUG 1

// ============================================================
// Load/Store Opcodes
// ============================================================
parameter LB  = 3'b000, LH  = 3'b001, LW = 3'b010;
parameter LBU = 3'b100, LHU = 3'b101;
parameter SB  = 3'b000, SH  = 3'b001, SW = 3'b010;

// ============================================================
// Cache Derived Parameters
// ============================================================
localparam BLOCK_SIZE     = 4 * WORDS_PER_BLOCK;
localparam WORD_IDX_BITS  = $clog2(WORDS_PER_BLOCK);
localparam INDEX_BITS     = $clog2(SET_NUMS);
localparam OFFSET_BITS    = $clog2(BLOCK_SIZE);
localparam TAG_BITS       = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
localparam PLRU_BITS      = WAY_NUMS - 1;
localparam REFILL_ARLEN   = WORDS_PER_BLOCK - 1;

// ============================================================
// Cache Storage (+ dirty bit for write-back)
// ============================================================
reg [DATA_WIDTH-1:0] cache_data  [SET_NUMS-1:0][WAY_NUMS-1:0][WORDS_PER_BLOCK-1:0];
reg [TAG_BITS-1:0]   cache_tag   [SET_NUMS-1:0][WAY_NUMS-1:0];
reg                  cache_valid [SET_NUMS-1:0][WAY_NUMS-1:0];
reg                  cache_dirty [SET_NUMS-1:0][WAY_NUMS-1:0];
reg [PLRU_BITS-1:0]  plru        [SET_NUMS-1:0];

// ============================================================
// State Machine
// ============================================================
localparam S_IDLE       = 4'd0;
localparam S_CHECK      = 4'd1;   // 1-cycle: latch addr, check cache
localparam S_CACHE_HIT  = 4'd2;   // 1-cycle: return cached data (load hit)
localparam S_REFILL_AR  = 4'd3;   // wait AR handshake (burst)
localparam S_REFILL_R   = 4'd4;   // receive burst data
localparam S_UNCACHE_AR = 4'd5;   // wait AR handshake (single)
localparam S_UNCACHE_R  = 4'd6;   // receive single-beat data
localparam S_UNCACHE_AW = 4'd7;   // uncacheable store: AW + W handshake
localparam S_UNCACHE_B  = 4'd8;   // uncacheable store: wait B response
localparam S_WB_AW      = 4'd9;   // writeback dirty word: AW + W handshake
localparam S_WB_B       = 4'd10;  // writeback dirty word: wait B, loop or refill
localparam S_STORE_HIT  = 4'd12;  // 1-cycle: store hit, write cache + mark dirty
localparam S_STORE_FILL = 4'd13;  // 1-cycle: store miss post-refill, write store data into cache

reg [3:0] state;

// ============================================================
// Trigger Mechanism (preserved from original LSU)
// ============================================================
reg                    init_txn_ff, o_pre_ready_d1;
wire                   is_ls           = i_load || i_store;
wire                   INIT_AXI_TXN   = reset ? 1'b0 : (o_pre_ready_d1 && is_ls);
wire                   init_txn_pulse = INIT_AXI_TXN && !init_txn_ff;
wire                   txn_pulse_load  = i_load  && init_txn_pulse;
wire                   txn_pulse_store = i_store && init_txn_pulse;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        init_txn_ff    <= 1'b0;
        o_pre_ready_d1 <= 1'b0;
    end else begin
        o_pre_ready_d1 <= o_pre_ready;
        if (fast_idle_hit_done)
            init_txn_ff <= 1'b0;
        else
            init_txn_ff <= INIT_AXI_TXN;
    end
end

// ============================================================
// Latched Request (stable for entire operation)
// ============================================================
reg [31:0] lat_addr;
reg [1:0]  lat_shift;
reg [2:0]  lat_exu_opt;
reg [31:0] lat_store_src;
reg        lat_is_load;
reg        lat_cacheable;

wire [4:0] lat_shift8 = {lat_shift, 3'b0};

// ============================================================
// Address Decomposition (from latched address)
// ============================================================
wire [TAG_BITS-1:0]      addr_tag   = lat_addr[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];
wire [INDEX_BITS-1:0]    addr_index = lat_addr[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
wire [WORD_IDX_BITS-1:0] addr_word  = lat_addr[OFFSET_BITS-1 : 2];

// ============================================================
// Cache Hit Detection (combinational, from latched addr)
// ============================================================
wire w0_hit = cache_valid[addr_index][0] && (cache_tag[addr_index][0] == addr_tag);
wire w1_hit = cache_valid[addr_index][1] && (cache_tag[addr_index][1] == addr_tag);
wire w2_hit = cache_valid[addr_index][2] && (cache_tag[addr_index][2] == addr_tag);
wire w3_hit = cache_valid[addr_index][3] && (cache_tag[addr_index][3] == addr_tag);
wire cache_hit = w0_hit | w1_hit | w2_hit | w3_hit;

wire [1:0] hit_way = w0_hit ? 2'd0 : w1_hit ? 2'd1 : w2_hit ? 2'd2 : 2'd3;

wire [31:0] hit_word = w0_hit ? cache_data[addr_index][0][addr_word] :
                       w1_hit ? cache_data[addr_index][1][addr_word] :
                       w2_hit ? cache_data[addr_index][2][addr_word] :
                                cache_data[addr_index][3][addr_word] ;

// ============================================================
// Same-Cycle Hit Detection (combinational, from alu_res)
// ============================================================
wire [TAG_BITS-1:0]      alu_addr_tag   = alu_res[ADDR_WIDTH-1 : INDEX_BITS+OFFSET_BITS];
wire [INDEX_BITS-1:0]    alu_addr_index = alu_res[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
wire [WORD_IDX_BITS-1:0] alu_addr_word  = alu_res[OFFSET_BITS-1 : 2];
wire                     alu_cacheable  = (alu_res >= CACHE_START && alu_res < CACHE_END);

wire alu_w0_hit = cache_valid[alu_addr_index][0] && (cache_tag[alu_addr_index][0] == alu_addr_tag);
wire alu_w1_hit = cache_valid[alu_addr_index][1] && (cache_tag[alu_addr_index][1] == alu_addr_tag);
wire alu_w2_hit = cache_valid[alu_addr_index][2] && (cache_tag[alu_addr_index][2] == alu_addr_tag);
wire alu_w3_hit = cache_valid[alu_addr_index][3] && (cache_tag[alu_addr_index][3] == alu_addr_tag);
wire alu_cache_hit = alu_w0_hit | alu_w1_hit | alu_w2_hit | alu_w3_hit;

wire [1:0] alu_hit_way = alu_w0_hit ? 2'd0 : alu_w1_hit ? 2'd1 : alu_w2_hit ? 2'd2 : 2'd3;

wire [31:0] alu_hit_word = alu_w0_hit ? cache_data[alu_addr_index][0][alu_addr_word] :
                           alu_w1_hit ? cache_data[alu_addr_index][1][alu_addr_word] :
                           alu_w2_hit ? cache_data[alu_addr_index][2][alu_addr_word] :
                                        cache_data[alu_addr_index][3][alu_addr_word] ;

wire fast_idle_load_hit_done  = (state == S_IDLE) && i_load  && alu_cacheable && alu_cache_hit;
wire fast_idle_store_hit_done = (state == S_IDLE) && i_store && alu_cacheable && alu_cache_hit;
wire fast_idle_hit_done = fast_idle_load_hit_done || fast_idle_store_hit_done;
wire [1:0] idle_hit_way = fast_idle_hit_done ? alu_hit_way : hit_way;
wire [31:0] idle_hit_word = fast_idle_hit_done ? alu_hit_word : hit_word;
wire [INDEX_BITS-1:0] idle_addr_index = fast_idle_hit_done ? alu_addr_index : addr_index;

wire [4:0]  idle_shift8     = {alu_res[1:0], 3'b0};
wire [3:0]  idle_wstrb_base = (exu_opt == SB) ? 4'b0001 :
                              (exu_opt == SH) ? 4'b0011 :
                              (exu_opt == SW) ? 4'b1111 : 4'b0000;
wire [3:0]  idle_wstrb = idle_wstrb_base << alu_res[1:0];
wire [31:0] idle_wdata = store_src << idle_shift8;

// ============================================================
// PLRU Victim Selection
// ============================================================
wire [1:0] victim_way = {plru[addr_index][0],
                         plru[addr_index][0] ? plru[addr_index][2] : plru[addr_index][1]};
reg [1:0] victim_way_lat;

// ============================================================
// Victim Dirty Detection (for writeback decision)
// ============================================================
wire victim_is_dirty = cache_valid[addr_index][victim_way] && cache_dirty[addr_index][victim_way];
wire [TAG_BITS-1:0] victim_tag = cache_tag[addr_index][victim_way];

// Writeback address = {victim_tag, addr_index, zero_offset}
wire [31:0] wb_addr = {victim_tag, addr_index, {OFFSET_BITS{1'b0}}};

// ============================================================
// Refill Control
// ============================================================
reg [WORD_IDX_BITS-1:0] refill_cnt;
reg                     refill_rready;

// ============================================================
// Writeback Control (single-beat per word)
// ============================================================
reg [WORD_IDX_BITS-1:0] wb_cnt;
reg                     wb_wvalid;
reg [31:0]              wb_addr_lat;    // latched writeback base address
reg [1:0]               wb_way_lat;     // latched victim way for WB data read

// ============================================================
// Store Byte Strobe & Shifted Data
// ============================================================
wire [3:0] wstrb_base = (lat_exu_opt == SB) ? 4'b0001 :
                       (lat_exu_opt == SH) ? 4'b0011 :
                       (lat_exu_opt == SW) ? 4'b1111 : 4'b0000;
wire [3:0] wstrb_shifted = wstrb_base << lat_shift;
wire [31:0] wdata_shifted = lat_store_src << lat_shift8;
wire [3:0] eff_wstrb = lat_cacheable ? wstrb_shifted : wstrb_base;
wire [31:0] eff_wdata = lat_cacheable ? wdata_shifted : lat_store_src;

// ============================================================
// AXI Control Registers
// ============================================================
reg axi_arvalid, axi_awvalid, axi_bready, axi_rready;

// ============================================================
// Done Signal
// ============================================================
reg done_reg;
wire fast_load_hit_done   = (state == S_CHECK) && lat_is_load && lat_cacheable && cache_hit;
wire fast_store_hit_done  = (state == S_CHECK) && !lat_is_load && lat_cacheable && cache_hit;
wire fast_refill_done     = (state == S_REFILL_R) && refill_rready && M_AXI_RLAST && lat_is_load;
wire fast_uncache_r_done  = (state == S_UNCACHE_R) && axi_rready;
wire fast_uncache_b_done  = (state == S_UNCACHE_B) && axi_bready;
assign lsu_done = done_reg || fast_idle_hit_done || fast_load_hit_done || fast_store_hit_done || fast_refill_done || fast_uncache_r_done || fast_uncache_b_done;

assign o_dbg_wait_start = (state == S_IDLE) && is_ls;

assign o_dbg_wait_hit =
    (state == S_CHECK && lat_cacheable && cache_hit) ||
    (state == S_CACHE_HIT) ||
    (state == S_STORE_HIT);

assign o_dbg_wait_refill =
    (state == S_CHECK && lat_cacheable && !cache_hit && !victim_is_dirty) ||
    (state == S_REFILL_AR) ||
    (state == S_REFILL_R) ||
    (state == S_STORE_FILL);

assign o_dbg_wait_refill_ar = (state == S_REFILL_AR);
assign o_dbg_wait_refill_r  = (state == S_REFILL_R);

assign o_dbg_wait_uncached =
    (state == S_CHECK && !lat_cacheable) ||
    (state == S_UNCACHE_AR) ||
    (state == S_UNCACHE_R) ||
    (state == S_UNCACHE_AW) ||
    (state == S_UNCACHE_B);

assign o_dbg_wait_wb =
    (state == S_CHECK && lat_cacheable && !cache_hit && victim_is_dirty) ||
    (state == S_WB_AW) ||
    (state == S_WB_B);

// ============================================================
// AXI Output Assignments
// ============================================================
// AR channel
assign M_AXI_ARADDR  = (state == S_REFILL_AR) ? {lat_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}} :
                        lat_addr;  // uncached: full addr
assign M_AXI_ARVALID = axi_arvalid;
assign M_AXI_ARLEN   = (state == S_REFILL_AR) ? REFILL_ARLEN[7:0] : 8'd0;
assign M_AXI_ARSIZE  = (state == S_REFILL_AR) ? 3'b010 :
                        (lat_exu_opt[1:0] == 2'b10) ? 3'b010 :
                        (lat_exu_opt[1:0] == 2'b01) ? 3'b001 : 3'b000;
assign M_AXI_ARBURST = (state == S_REFILL_AR) ? 2'b01 : 2'b00;
assign M_AXI_ARID    = 4'd0;

// AW channel (writeback single-beat OR uncacheable single store)
// Writeback addr = base + word offset
wire [31:0] wb_word_addr = {wb_addr_lat[31:OFFSET_BITS], wb_cnt, 2'b00};
assign M_AXI_AWADDR  = (state == S_WB_AW) ? wb_word_addr : lat_addr;
assign M_AXI_AWVALID = axi_awvalid;
assign M_AXI_AWLEN   = 8'd0;   // always single beat
assign M_AXI_AWSIZE  = (state == S_WB_AW) ? 3'b010 :
                       (lat_exu_opt == SW) ? 3'b010 :
                       (lat_exu_opt == SH) ? 3'b001 : 3'b000;
assign M_AXI_AWBURST = 2'b00;  // FIXED (single beat)
assign M_AXI_AWID    = 4'd0;

// W channel (writeback word data OR uncacheable single store data)
wire in_wb_write = (state == S_WB_AW);
assign M_AXI_WVALID  = in_wb_write ? wb_wvalid : (state == S_UNCACHE_AW ? axi_awvalid : 1'b0);
assign M_AXI_WDATA   = in_wb_write ? cache_data[addr_index][wb_way_lat][wb_cnt] : eff_wdata;
assign M_AXI_WSTRB   = in_wb_write ? 4'b1111 : eff_wstrb;
assign M_AXI_WLAST   = 1'b1;  // always single beat

// R channel
assign M_AXI_RREADY  = (state == S_REFILL_R) ? refill_rready : axi_rready;

// B channel
assign M_AXI_BREADY  = axi_bready;

// ============================================================
// Main State Machine
// ============================================================
always @(posedge clock or posedge reset) begin
    if (reset) begin
        state          <= S_IDLE;
        lat_addr       <= 32'd0;
        lat_shift      <= 2'd0;
        lat_exu_opt    <= 3'd0;
        lat_store_src  <= 32'd0;
        lat_is_load    <= 1'b0;
        lat_cacheable  <= 1'b0;
        done_reg       <= 1'b0;
        axi_arvalid    <= 1'b0;
        axi_awvalid    <= 1'b0;
        axi_bready     <= 1'b0;
        axi_rready     <= 1'b0;
        victim_way_lat <= 2'd0;
        refill_cnt     <= {WORD_IDX_BITS{1'b0}};
        refill_rready  <= 1'b0;
        wb_cnt         <= {WORD_IDX_BITS{1'b0}};
        wb_wvalid      <= 1'b0;
        wb_addr_lat    <= 32'd0;
        wb_way_lat     <= 2'd0;
    end
    else begin
        done_reg <= 1'b0;  // default: clear done pulse

        case (state)
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_IDLE: begin
            if (fast_idle_hit_done) begin
                // Same-cycle cache hit: no FSM transition needed
            end
            else if (txn_pulse_load || txn_pulse_store) begin
                // Latch request
                lat_addr      <= alu_res;
                lat_shift     <= alu_res[1:0];
                lat_exu_opt   <= exu_opt;
                lat_store_src <= store_src;
                lat_is_load   <= i_load;
                lat_cacheable <= (alu_res >= CACHE_START && alu_res < CACHE_END);
                state         <= S_CHECK;
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // S_CHECK: address latched last cycle, hit/miss detection now valid
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_CHECK: begin
            if (lat_is_load) begin
                // 鈹€鈹€ Load path 鈹€鈹€
                if (lat_cacheable && cache_hit) begin
                    // Load hit returns in the current cycle; load_res is combinational for this path.
                    state <= S_IDLE;
                    `ifdef DCACHE_DEBUG
                    $display("[DCACHE] LOAD HIT : set=%0d way=%0d addr=0x%0h", addr_index, hit_way, lat_addr);
                    `endif
                end
                else if (lat_cacheable) begin
                    // Load miss 鈫?check if victim is dirty
                    if (victim_is_dirty) begin
                        // Dirty victim 鈫?writeback first
                        axi_awvalid <= 1'b1;
                        wb_addr_lat <= wb_addr;
                        wb_way_lat  <= victim_way;
                        wb_cnt      <= {WORD_IDX_BITS{1'b0}};
                        wb_wvalid   <= 1'b1;
                        state       <= S_WB_AW;
                        `ifdef DCACHE_DEBUG
                        $display("[DCACHE] LOAD MISS (dirty WB): set=%0d victim=%0d addr=0x%0h wb_addr=0x%0h",
                                 addr_index, victim_way, lat_addr, wb_addr);
                        `endif
                    end
                    else begin
                        // Clean victim 鈫?refill directly
                        axi_arvalid <= 1'b1;
                        state       <= S_REFILL_AR;
                        `ifdef DCACHE_DEBUG
                        $display("[DCACHE] LOAD MISS (clean): set=%0d victim=%0d addr=0x%0h",
                                 addr_index, victim_way, lat_addr);
                        `endif
                    end
                end
                else begin
                    // Uncacheable load 鈫?single-beat AXI read
                    axi_arvalid <= 1'b1;
                    state       <= S_UNCACHE_AR;
                end
            end
            else begin
                // 鈹€鈹€ Store path 鈹€鈹€
                if (lat_cacheable && cache_hit) begin
                    state <= S_IDLE;
                    `ifdef DCACHE_DEBUG
                    $display("[DCACHE] STORE HIT: set=%0d way=%0d addr=0x%0h", addr_index, hit_way, lat_addr);
                    `endif
                end
                else if (lat_cacheable) begin
                    // Store miss 鈫?write-allocate: evict victim (if dirty), refill, then write
                    if (victim_is_dirty) begin
                        axi_awvalid <= 1'b1;
                        wb_addr_lat <= wb_addr;
                        wb_way_lat  <= victim_way;
                        wb_cnt      <= {WORD_IDX_BITS{1'b0}};
                        wb_wvalid   <= 1'b1;
                        state       <= S_WB_AW;
                        `ifdef DCACHE_DEBUG
                        $display("[DCACHE] STORE MISS (dirty WB): set=%0d victim=%0d addr=0x%0h wb_addr=0x%0h",
                                 addr_index, victim_way, lat_addr, wb_addr);
                        `endif
                    end
                    else begin
                        axi_arvalid <= 1'b1;
                        state       <= S_REFILL_AR;
                        `ifdef DCACHE_DEBUG
                        $display("[DCACHE] STORE MISS (clean): set=%0d victim=%0d addr=0x%0h",
                                 addr_index, victim_way, lat_addr);
                        `endif
                    end
                end
                else begin
                    // Uncacheable store 鈫?single-beat AXI write
                    axi_awvalid <= 1'b1;
                    state       <= S_UNCACHE_AW;
                end
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // S_CACHE_HIT: load hit 鈫?output data, done
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_CACHE_HIT: begin
            done_reg <= 1'b1;
            state    <= S_IDLE;
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // S_STORE_HIT: store hit 鈫?cache updated in separate block, done
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_STORE_HIT: begin
            done_reg <= 1'b1;
            state    <= S_IDLE;
            `ifdef DCACHE_DEBUG
            $display("[DCACHE_STORE] addr=%08x set=%0d way=%0d word=%0d wstrb=%04b wdata=%08x",
                     lat_addr, addr_index, hit_way, addr_word, wstrb_shifted, wdata_shifted);
            `endif
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // Writeback dirty victim: AW + W handshake (single beat per word)
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_WB_AW: begin
            // Deassert each channel independently on handshake
            if (M_AXI_AWREADY && axi_awvalid) begin
                axi_awvalid <= 1'b0;
                `ifdef DCACHE_DEBUG
                $display("[DCACHE_WB] wb_addr=%08x set=%0d way=%0d word=%0d data=%08x",
                         wb_word_addr, addr_index, wb_way_lat, wb_cnt,
                         cache_data[addr_index][wb_way_lat][wb_cnt]);
                `endif
            end
            if (M_AXI_WREADY && wb_wvalid)
                wb_wvalid <= 1'b0;
            // Both AW and W handshakes complete 鈫?wait B
            if ((M_AXI_AWREADY || !axi_awvalid) && (M_AXI_WREADY || !wb_wvalid)) begin
                axi_awvalid    <= 1'b0;
                wb_wvalid      <= 1'b0;
                victim_way_lat <= wb_way_lat;  // latch for refill
                state          <= S_WB_B;
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // Writeback dirty victim: wait B response, loop or refill
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_WB_B: begin
            if (M_AXI_BVALID && ~axi_bready) begin
                axi_bready <= 1'b1;
            end
            else if (axi_bready) begin
                axi_bready <= 1'b0;
                if (wb_cnt == REFILL_ARLEN[WORD_IDX_BITS-1:0]) begin
                    // All words written back 鈫?start refill
                    axi_arvalid <= 1'b1;
                    state       <= S_REFILL_AR;
                    `ifdef DCACHE_DEBUG
                    $display("[DCACHE] WB DONE  : set=%0d way=%0d, starting refill",
                             addr_index, wb_way_lat);
                    `endif
                end
                else begin
                    // More words to write 鈫?next word
                    wb_cnt      <= wb_cnt + 1;
                    axi_awvalid <= 1'b1;
                    wb_wvalid   <= 1'b1;
                    state       <= S_WB_AW;
                end
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_REFILL_AR: begin
            if (M_AXI_ARREADY && axi_arvalid) begin
                axi_arvalid    <= 1'b0;
                victim_way_lat <= victim_way;
                refill_cnt     <= {WORD_IDX_BITS{1'b0}};
                refill_rready  <= 1'b0;
                state          <= S_REFILL_R;
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_REFILL_R: begin
            if (M_AXI_RVALID && ~refill_rready) begin
                refill_rready <= 1'b1;
            end
else if (refill_rready) begin
                refill_rready <= 1'b0;
                refill_cnt    <= refill_cnt + 1;
                if (M_AXI_RLAST) begin
                    if (lat_is_load) begin
                        state <= S_IDLE;
                    end
                    else begin
                        state <= S_STORE_FILL;
                    end
                end
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_UNCACHE_AR: begin
            if (M_AXI_ARREADY && axi_arvalid) begin
                axi_arvalid <= 1'b0;
                axi_rready  <= 1'b0;
                state       <= S_UNCACHE_R;
                `ifdef DCACHE_DEBUG
                $display("[LSU_RD] araddr=%08x opt=%0d", lat_addr, lat_exu_opt);
                `endif
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_UNCACHE_R: begin
            if (M_AXI_RVALID && ~axi_rready) begin
                axi_rready <= 1'b1;
            end
            else if (axi_rready) begin
                axi_rready <= 1'b0;
                state      <= S_IDLE;
                `ifdef DCACHE_DEBUG
                $display("[LSU_RD_DATA] addr=%08x rdata=%08x shift=%0d opt=%0d",
                         lat_addr, M_AXI_RDATA, lat_shift, lat_exu_opt);
                `endif
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // Uncacheable store: AW + W handshake (single beat)
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_UNCACHE_AW: begin
            // WVALID is driven combinationally from axi_awvalid in this state
            if (M_AXI_AWREADY && axi_awvalid)
                axi_awvalid <= 1'b0;
            // Both AW and W done 鈫?wait B
            if ((M_AXI_AWREADY || !axi_awvalid) && (M_AXI_WREADY || !axi_awvalid)) begin
                axi_awvalid <= 1'b0;
                state       <= S_UNCACHE_B;
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // Uncacheable store: wait B response
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_UNCACHE_B: begin
            if (M_AXI_BVALID && ~axi_bready) begin
                axi_bready <= 1'b1;
            end
            else if (axi_bready) begin
                axi_bready <= 1'b0;
                state      <= S_IDLE;
            end
        end

        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        // S_STORE_FILL: store miss post-refill, write store data into cache
        // 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        S_STORE_FILL: begin
            // Cache data write happens in the cache data write block below
            done_reg <= 1'b1;
            state    <= S_IDLE;
            `ifdef DCACHE_DEBUG
            $display("[DCACHE_STORE_FILL] addr=%08x set=%0d way=%0d word=%0d wstrb=%04b wdata=%08x",
                     lat_addr, addr_index, victim_way_lat, addr_word, wstrb_shifted, wdata_shifted);
            `endif
        end

        default: state <= S_IDLE;
        endcase
    end
end


// ============================================================
// Cache Data Write (refill + store hit/miss update)
// ============================================================
integer di, dj, dw;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (di = 0; di < SET_NUMS; di = di + 1)
            for (dj = 0; dj < WAY_NUMS; dj = dj + 1)
                for (dw = 0; dw < WORDS_PER_BLOCK; dw = dw + 1)
                    cache_data[di][dj][dw] <= {DATA_WIDTH{1'b0}};
    end
    else if (state == S_REFILL_R && M_AXI_RVALID && refill_rready) begin
        // Refill: write incoming word into cache
        cache_data[addr_index][victim_way_lat][refill_cnt] <= M_AXI_RDATA;
    end
    else if (fast_idle_store_hit_done) begin
        if (idle_wstrb[0]) cache_data[alu_addr_index][alu_hit_way][alu_addr_word][ 7: 0] <= idle_wdata[ 7: 0];
        if (idle_wstrb[1]) cache_data[alu_addr_index][alu_hit_way][alu_addr_word][15: 8] <= idle_wdata[15: 8];
        if (idle_wstrb[2]) cache_data[alu_addr_index][alu_hit_way][alu_addr_word][23:16] <= idle_wdata[23:16];
        if (idle_wstrb[3]) cache_data[alu_addr_index][alu_hit_way][alu_addr_word][31:24] <= idle_wdata[31:24];
    end
    else if (state == S_STORE_HIT || fast_store_hit_done) begin
        // Store hit (write-back): update cache line (byte-level merge)
        if (wstrb_shifted[0]) cache_data[addr_index][hit_way][addr_word][ 7: 0] <= wdata_shifted[ 7: 0];
        if (wstrb_shifted[1]) cache_data[addr_index][hit_way][addr_word][15: 8] <= wdata_shifted[15: 8];
        if (wstrb_shifted[2]) cache_data[addr_index][hit_way][addr_word][23:16] <= wdata_shifted[23:16];
        if (wstrb_shifted[3]) cache_data[addr_index][hit_way][addr_word][31:24] <= wdata_shifted[31:24];
    end
    else if (state == S_STORE_FILL) begin
        // Store miss post-refill: write store data into the just-refilled line
        if (wstrb_shifted[0]) cache_data[addr_index][victim_way_lat][addr_word][ 7: 0] <= wdata_shifted[ 7: 0];
        if (wstrb_shifted[1]) cache_data[addr_index][victim_way_lat][addr_word][15: 8] <= wdata_shifted[15: 8];
        if (wstrb_shifted[2]) cache_data[addr_index][victim_way_lat][addr_word][23:16] <= wdata_shifted[23:16];
        if (wstrb_shifted[3]) cache_data[addr_index][victim_way_lat][addr_word][31:24] <= wdata_shifted[31:24];
    end
end

// ============================================================
// Cache Tag, Valid, & Dirty Control
// ============================================================
integer si, wi;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (si = 0; si < SET_NUMS; si = si + 1)
            for (wi = 0; wi < WAY_NUMS; wi = wi + 1) begin
                cache_valid[si][wi] <= 1'b0;
                cache_dirty[si][wi] <= 1'b0;
            end
    end
    else if (state == S_REFILL_AR && M_AXI_ARREADY && axi_arvalid) begin
        // AR handshake: write tag, invalidate during fill, clear dirty
        cache_tag[addr_index][victim_way]   <= addr_tag;
        cache_valid[addr_index][victim_way] <= 1'b0;
        cache_dirty[addr_index][victim_way] <= 1'b0;
    end
    else if (state == S_REFILL_R && M_AXI_RVALID && refill_rready && M_AXI_RLAST) begin
        // Refill done: validate line
        cache_valid[addr_index][victim_way_lat] <= 1'b1;
        // Don't mark dirty here for store miss 鈥?that's done in S_STORE_FILL
        `ifdef DCACHE_DEBUG
        $display("[DCACHE] FILL OK : set=%0d way=%0d tag=0x%0h dirty=%0d",
                 addr_index, victim_way_lat, addr_tag, !lat_is_load);
        `endif
    end
    else if (fast_idle_store_hit_done) begin
        cache_dirty[alu_addr_index][alu_hit_way] <= 1'b1;
    end
    else if (state == S_STORE_HIT || fast_store_hit_done) begin
        // Store hit → mark dirty
        cache_dirty[addr_index][hit_way] <= 1'b1;
    end
    else if (state == S_STORE_FILL) begin
        // Store miss post-refill 鈫?mark dirty
        cache_dirty[addr_index][victim_way_lat] <= 1'b1;
    end
end

// ============================================================
// PLRU Update
// ============================================================
always @(posedge clock or posedge reset) begin
    integer s;
    if (reset) begin
        for (s = 0; s < SET_NUMS; s = s + 1)
            plru[s] <= {PLRU_BITS{1'b0}};
    end
    else if (state == S_REFILL_R && M_AXI_RVALID && refill_rready && M_AXI_RLAST) begin
        case (victim_way_lat)
            2'd0: plru[addr_index] <= {plru[addr_index][2], 1'b1, 1'b1};
            2'd1: plru[addr_index] <= {plru[addr_index][2], 1'b0, 1'b1};
            2'd2: plru[addr_index] <= {1'b1, plru[addr_index][1], 1'b0};
            2'd3: plru[addr_index] <= {1'b0, plru[addr_index][1], 1'b0};
        endcase
    end
    else if (state == S_CACHE_HIT || state == S_STORE_HIT || fast_store_hit_done) begin
        case (hit_way)
            2'd0: plru[addr_index] <= {plru[addr_index][2], 1'b1, 1'b1};
            2'd1: plru[addr_index] <= {plru[addr_index][2], 1'b0, 1'b1};
            2'd2: plru[addr_index] <= {1'b1, plru[addr_index][1], 1'b0};
            2'd3: plru[addr_index] <= {1'b0, plru[addr_index][1], 1'b0};
        endcase
    end
    else if (fast_idle_hit_done) begin
        case (alu_hit_way)
            2'd0: plru[alu_addr_index] <= {plru[alu_addr_index][2], 1'b1, 1'b1};
            2'd1: plru[alu_addr_index] <= {plru[alu_addr_index][2], 1'b0, 1'b1};
            2'd2: plru[alu_addr_index] <= {1'b1, plru[alu_addr_index][1], 1'b0};
            2'd3: plru[alu_addr_index] <= {1'b0, plru[alu_addr_index][1], 1'b0};
        endcase
    end
end

// ============================================================
// Load Result Mux (byte extract + sign extend)
// ============================================================
wire refill_hit_word = (state == S_REFILL_R) && M_AXI_RVALID && refill_rready && (refill_cnt == addr_word);
wire [31:0] idle_shifted_data = alu_hit_word >> idle_shift8;
wire [31:0] idle_load_src = idle_shifted_data;
wire [31:0] idle_load_res_next =
    (exu_opt == LB)  ? {{24{idle_load_src[7]}},  idle_load_src[7:0]}  :
    (exu_opt == LH)  ? {{16{idle_load_src[15]}}, idle_load_src[15:0]} :
    (exu_opt == LW)  ? idle_load_src                              :
    (exu_opt == LBU) ? {24'b0, idle_load_src[7:0]}                :
    (exu_opt == LHU) ? {16'b0, idle_load_src[15:0]}               :
                       32'b0;
wire [31:0] raw_word = fast_idle_load_hit_done ? alu_hit_word :
                       fast_load_hit_done      ? hit_word :
                       (state == S_CACHE_HIT)  ? hit_word :
                       refill_hit_word          ? M_AXI_RDATA :
                       (state == S_REFILL_R)    ? cache_data[addr_index][victim_way_lat][addr_word] :
                       (state == S_UNCACHE_R)   ? M_AXI_RDATA :
                       32'b0;
wire [31:0] shifted_data = raw_word >> lat_shift8;
wire [31:0] load_src     = lat_cacheable ? shifted_data : raw_word;
wire [31:0] load_res_next =
    (lat_exu_opt == LB)  ? {{24{load_src[7]}},  load_src[7:0]}  :
    (lat_exu_opt == LH)  ? {{16{load_src[15]}}, load_src[15:0]} :
    (lat_exu_opt == LW)  ? load_src                              :
    (lat_exu_opt == LBU) ? {24'b0, load_src[7:0]}                :
    (lat_exu_opt == LHU) ? {16'b0, load_src[15:0]}               :
                           32'b0;

reg [31:0] load_res_reg;
assign load_res = fast_idle_load_hit_done ? idle_load_res_next :
                  (fast_load_hit_done || fast_refill_done || fast_uncache_r_done) ? load_res_next : load_res_reg;

always @(posedge clock or posedge reset) begin
  if (reset) begin
    load_res_reg <= 32'b0;
  end
  else begin
    if (fast_idle_load_hit_done || state == S_CACHE_HIT || refill_hit_word || (state == S_UNCACHE_R && M_AXI_RVALID)) begin
      load_res_reg <= load_res_next;
    end
  end
end

// ============================================================
// Debug
// ============================================================
`ifdef DCACHE_DEBUG
reg [15:0] dbg_stall_cnt;
always @(posedge clock or posedge reset) begin
    if (reset)
        dbg_stall_cnt <= 0;
    else if (state != S_IDLE && state != S_CHECK) begin
        dbg_stall_cnt <= dbg_stall_cnt + 1;
        if (dbg_stall_cnt == 16'd19999) begin
            $display("[DCACHE] !! STALL: stuck in state %0d for 20000 cycles, addr=0x%0h", state, lat_addr);
            $finish;
        end
    end
    else
        dbg_stall_cnt <= 0;
end
`endif

endmodule
