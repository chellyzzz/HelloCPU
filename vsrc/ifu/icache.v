module hcpu_icache #(
    parameter                           ADDR_WIDTH      = 32       ,
    parameter                           DATA_WIDTH      = 32       ,
    parameter                           SET_NUMS        = 64       ,// Number of cache sets
    parameter                           WAY_NUMS        = 4        ,// Number of ways (associativity)
    parameter                           WORDS_PER_BLOCK = 4         // Number of 32-bit words per block (16 bytes)
)
(
    //read data channel
    input              [  31:0]         M_AXI_RDATA                ,
    input              [   1:0]         M_AXI_RRESP                ,
    input                               M_AXI_RVALID               ,
    output                              M_AXI_RREADY               ,
    input              [   3:0]         M_AXI_RID                  ,
    input                               M_AXI_RLAST                ,

    //read address channel
    output             [  31:0]         M_AXI_ARADDR               ,
    output                              M_AXI_ARVALID              ,
    input                               M_AXI_ARREADY              ,
    output             [   3:0]         M_AXI_ARID                 ,
    output             [   7:0]         M_AXI_ARLEN                ,
    output             [   2:0]         M_AXI_ARSIZE               ,
    output             [   1:0]         M_AXI_ARBURST              ,

    input                               clock                      ,
    input                               rst_n_sync                 ,
    input              [ADDR_WIDTH-1:0] addr                       ,
    output             [DATA_WIDTH-1:0] data                       ,

    input                               fence_i                    ,
    output                              hit
);
`include "debug_macros.vh"
// `define ICACHE_DEBUG  1

// ============================================================
// Local Parameters
// ============================================================
localparam BLOCK_SIZE    = 4 * WORDS_PER_BLOCK;              // Block size in bytes
localparam ARLEN         = BLOCK_SIZE / 4 - 1;               // AXI burst length (transfers - 1)
localparam WORD_IDX_BITS = $clog2(WORDS_PER_BLOCK);          // Bits to index word within block
localparam INDEX_BITS    = $clog2(SET_NUMS);                 // Bits for set index
localparam OFFSET_BITS   = $clog2(BLOCK_SIZE);               // Bits for byte offset within block
localparam TAG_BITS      = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // Tag bits
// With defaults: OFFSET_BITS=4, INDEX_BITS=2, TAG_BITS=26

// ============================================================
// Cache Storage  [set][way]
// ============================================================
reg [DATA_WIDTH-1:0] cache_data  [SET_NUMS-1:0][WAY_NUMS-1:0][WORDS_PER_BLOCK-1:0];
reg [TAG_BITS-1:0]   cache_tag   [SET_NUMS-1:0][WAY_NUMS-1:0];
reg                  cache_valid [SET_NUMS-1:0][WAY_NUMS-1:0];

// ============================================================
// PLRU State  (3 bits per set, binary tree for 4 ways)
//
//        plru[0]
//       /       \
//   plru[1]   plru[2]
//   /   \     /   \
//  W0   W1   W2   W3
//
// plru[b]=0 means "left subtree is LRU (victim side)"
// plru[s][0]=b0 (top), [1]=b1 (left child), [2]=b2 (right child)
// Victim = { b0, b0 ? b2 : b1 }  鈫?b0=0 picks left half, b0=1 picks right half
// ============================================================

reg [WAY_NUMS-2:0] plru [SET_NUMS-1:0]; // 3 bits per set

// ============================================================
// AXI Control Registers
// ============================================================
reg                              axi_arvalid;
reg                              axi_rready;
reg [WORD_IDX_BITS-1:0]          read_index;  // Word counter during burst
reg [ADDR_WIDTH-1-OFFSET_BITS:0] araddr;      // Latched miss address (no offset)
reg                              idle;

// ============================================================
// Deadlock Detection (debug only)
// ============================================================
`ifdef ICACHE_DEBUG
reg [15:0] ar_stall_cnt;   // counts cycles where ARVALID=1 but ARREADY=0
reg [15:0] r_stall_cnt;    // counts cycles where idle=0 but RVALID=0
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        ar_stall_cnt <= 0;
        r_stall_cnt  <= 0;
    end else begin
        // AR channel deadlock: ARVALID asserted but slave never responds
        if (axi_arvalid && ~M_AXI_ARREADY) begin
            ar_stall_cnt <= ar_stall_cnt + 1;
            if (ar_stall_cnt == 999)
                $display("[ICACHE] !! AR DEADLOCK: ARVALID stuck for 1000 cycles, addr=0x%0h",
                         {araddr, {OFFSET_BITS{1'b0}}});
        end else begin
            ar_stall_cnt <= 0;
        end
        // R channel deadlock: refill started but data never comes
        if (~idle && ~M_AXI_RVALID && ~axi_arvalid) begin
            r_stall_cnt <= r_stall_cnt + 1;
            if (r_stall_cnt == 999)
                $display("[ICACHE] !! R DEADLOCK: waiting for RVALID for 1000 cycles, addr=0x%0h",
                         {araddr, {OFFSET_BITS{1'b0}}});
        end else begin
            r_stall_cnt <= 0;
        end
    end
end
`endif
// ============================================================
// AXI Output Assignments
// ============================================================
assign M_AXI_ARADDR  = {araddr, {OFFSET_BITS{1'b0}}};
assign M_AXI_ARVALID = axi_arvalid;
assign M_AXI_ARID    = 4'b0;
assign M_AXI_ARLEN   = ARLEN[7:0];
assign M_AXI_ARSIZE  = 3'b010;   // 4 bytes per beat
assign M_AXI_ARBURST = 2'b01;    // INCR
assign M_AXI_RREADY  = axi_rready;

// ============================================================
// Address Decomposition  (from latched araddr, offset stripped)
// ============================================================
wire [TAG_BITS-1:0]   tag   = araddr[ADDR_WIDTH-OFFSET_BITS-1 : INDEX_BITS];
wire [INDEX_BITS-1:0] index = araddr[INDEX_BITS-1 : 0];

// ============================================================
// Hit Detection  (combinational, from live addr)
// ============================================================
wire [TAG_BITS-1:0]    hit_tag    = addr[ADDR_WIDTH-1              : INDEX_BITS + OFFSET_BITS];
wire [INDEX_BITS-1:0]  hit_index  = addr[INDEX_BITS + OFFSET_BITS-1 : OFFSET_BITS];
wire [OFFSET_BITS-1:0] hit_offset = addr[OFFSET_BITS-1             : 0];

wire hit_way0 = cache_valid[hit_index][0] && (cache_tag[hit_index][0] == hit_tag);
wire hit_way1 = cache_valid[hit_index][1] && (cache_tag[hit_index][1] == hit_tag);
wire hit_way2 = cache_valid[hit_index][2] && (cache_tag[hit_index][2] == hit_tag);
wire hit_way3 = cache_valid[hit_index][3] && (cache_tag[hit_index][3] == hit_tag);

assign hit = hit_way0 | hit_way1 | hit_way2 | hit_way3;

// Which way hit? (one-hot 鈫?2-bit encoding)
wire [1:0] hit_way_sel = hit_way0 ? 2'd0 :
                         hit_way1 ? 2'd1 :
                         hit_way2 ? 2'd2 : 2'd3;

// Output data mux
assign data = hit_way0 ? cache_data[hit_index][0][hit_offset[OFFSET_BITS-1:2]] :
              hit_way1 ? cache_data[hit_index][1][hit_offset[OFFSET_BITS-1:2]] :
              hit_way2 ? cache_data[hit_index][2][hit_offset[OFFSET_BITS-1:2]] :
                         cache_data[hit_index][3][hit_offset[OFFSET_BITS-1:2]] ;

// ============================================================
// Victim Way Selection  (PLRU tree for latched index)
//   victim = { plru[0], plru[0] ? plru[2] : plru[1] }
// ============================================================
wire [1:0] victim_way = {plru[index][0],
                         plru[index][0] ? plru[index][2] : plru[index][1]};
// victim_way is COMBINATIONAL 鈥?only use it to determine the next victim.
// During a refill, always use victim_way_lat (latched at AR handshake).
reg [1:0] victim_way_lat; // latched at AR handshake, stable for entire burst

always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync)
        victim_way_lat <= 2'd0;
    else if (M_AXI_ARVALID && M_AXI_ARREADY)
        victim_way_lat <= victim_way;  // lock in BEFORE burst data arrives
end

// ============================================================
// PLRU Update Logic
//   On hit (way w): point the tree away from w
//     b[0]    <= ~w[1]          (top: point to opposite half)
//     b[~w[1]]: already correct, update the leaf pointer
//     b[w[1]+1] <= ~w[0]        (mid: point to opposite leaf)
//
//  plru stored as {b2, b1, b0} 鈫?index [2]=b2, [1]=b1, [0]=b0
//   hit W0 (00): b0<=1, b1<=1 鈫?{b2, 1, 1}
//   hit W1 (01): b0<=1, b1<=0 鈫?{b2, 0, 1}
//   hit W2 (10): b0<=0, b2<=1 鈫?{1, b1, 0}
//   hit W3 (11): b0<=0, b2<=0 鈫?{0, b1, 0}
// ============================================================
always @(posedge clock or negedge rst_n_sync) begin
    integer s;
    if (~rst_n_sync) begin
        for (s = 0; s < SET_NUMS; s = s + 1)
            plru[s] <= 3'b0;
    end
    else if (fence_i) begin
        for (s = 0; s < SET_NUMS; s = s + 1)
            plru[s] <= 3'b0;
    end
    else if (M_AXI_RLAST && M_AXI_RVALID && axi_rready) begin
        // Refill 瀹屾垚锛屾洿鏂?victim way 鐨?PLRU (浣跨敤閿佸瓨鍊?
        case (victim_way_lat)
            2'd0: plru[index] <= {plru[index][2], 1'b1, 1'b1};
            2'd1: plru[index] <= {plru[index][2], 1'b0, 1'b1};
            2'd2: plru[index] <= {1'b1, plru[index][1], 1'b0};
            2'd3: plru[index] <= {1'b0, plru[index][1], 1'b0};
        endcase
    end
    else if (hit) begin
        // Cache hit锛屾洿鏂?PLRU
        case (hit_way_sel)
            2'd0: plru[hit_index] <= {plru[hit_index][2], 1'b1, 1'b1};
            2'd1: plru[hit_index] <= {plru[hit_index][2], 1'b0, 1'b1};
            2'd2: plru[hit_index] <= {1'b1, plru[hit_index][1], 1'b0};
            2'd3: plru[hit_index] <= {1'b0, plru[hit_index][1], 1'b0};
        endcase
    end
end


// ============================================================
// Cache Tag & Valid Control
// ============================================================
integer si, wi;
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        for (si = 0; si < SET_NUMS; si = si + 1)
            for (wi = 0; wi < WAY_NUMS; wi = wi + 1)
                cache_valid[si][wi] <= 1'b0;
    end
    else if (fence_i && idle) begin
        for (si = 0; si < SET_NUMS; si = si + 1)
            for (wi = 0; wi < WAY_NUMS; wi = wi + 1)
                cache_valid[si][wi] <= 1'b0;
        `ifdef ICACHE_DEBUG
        $display("[ICACHE] FENCE.I: all valid cleared");
        `endif
    end
    else if (M_AXI_ARVALID && M_AXI_ARREADY) begin
        // AR 鎻℃墜锛氬啓 tag锛岀敤缁勫悎 victim_way锛堝皢鍚屾椂琚攣瀛樺埌 victim_way_lat锛?
        cache_tag[index][victim_way]   <= tag;
        cache_valid[index][victim_way] <= 1'b0;
        `ifdef ICACHE_DEBUG
        $display("[ICACHE] MISS  : set=%0d way=%0d tag=0x%0h addr=0x%0h",
                 index, victim_way, tag, {araddr, {OFFSET_BITS{1'b0}}});
        `endif
    end
    else if (M_AXI_RLAST && M_AXI_RVALID && axi_rready) begin
        // RLAST锛氱敤閿佸瓨鍊?victim_way_lat锛岀‘淇濅笌 AR 鎻℃墜鏃朵竴鑷?
        cache_valid[index][victim_way_lat] <= 1'b1;
        `ifdef ICACHE_DEBUG
        $display("[ICACHE] FILL OK: set=%0d way=%0d tag=0x%0h",
                 index, victim_way_lat, tag);
        `endif
    end
end

// ============================================================
// Address Latch & Idle Control
// ============================================================
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        araddr <= {(ADDR_WIDTH-OFFSET_BITS){1'b0}};
        idle   <= 1'b1;
    end
    else if (!hit && idle) begin
        araddr <= addr[ADDR_WIDTH-1 : OFFSET_BITS];
        idle   <= 1'b0;
    end
    else if (M_AXI_RLAST && M_AXI_RREADY) begin
        if (hit) begin
            araddr <= {(ADDR_WIDTH-OFFSET_BITS){1'b0}};
            idle   <= 1'b1;
        end
        else begin
            araddr <= addr[ADDR_WIDTH-1 : OFFSET_BITS];
        end
    end
end

// ============================================================
// Read Address Channel 鈥?AR handshake
// ============================================================
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        axi_arvalid <= 1'b0;
    end
    else if (!hit && idle) begin
        axi_arvalid <= 1'b1;
    end
    else if (axi_arvalid && M_AXI_ARREADY) begin
        axi_arvalid <= 1'b0;
    end
    else if (M_AXI_RLAST && M_AXI_RREADY && !hit) begin
        axi_arvalid <= 1'b1;
    end
end

// ============================================================
// Read Data Channel 鈥?R handshake
// ============================================================
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        axi_rready <= 1'b0;
    end
    else if (M_AXI_RVALID && ~axi_rready) begin
        // 姣忔媿鏁版嵁鍒版潵鏃?assert 涓€涓懆鏈?
        axi_rready <= 1'b1;
    end
    else if (axi_rready) begin
        axi_rready <= 1'b0;
    end
end


// ============================================================
// Burst Word Counter (read_index)
// ============================================================
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        read_index <= {WORD_IDX_BITS{1'b0}};
    end
    else if (M_AXI_ARVALID && M_AXI_ARREADY) begin
        read_index <= {WORD_IDX_BITS{1'b0}};
    end
    else if (M_AXI_RVALID && axi_rready) begin
        read_index <= read_index + 1;
    end
end


// ============================================================
// Cache Data Write (burst fill into victim way)
// ============================================================
integer di, dj, dw;
always @(posedge clock or negedge rst_n_sync) begin
    if (~rst_n_sync) begin
        for (di = 0; di < SET_NUMS; di = di + 1)
            for (dj = 0; dj < WAY_NUMS; dj = dj + 1)
                for (dw = 0; dw < WORDS_PER_BLOCK; dw = dw + 1)
                    cache_data[di][dj][dw] <= {DATA_WIDTH{1'b0}};
    end
    else if (M_AXI_RVALID && axi_rready) begin
        cache_data[index][victim_way_lat][read_index] <= M_AXI_RDATA;
    end
end


`ifdef ICACHE_DEBUG
always @(posedge clock) begin
    if (hit)
        $display("[ICACHE] HIT   : set=%0d way=%0d tag=0x%0h addr=0x%0h",
                 hit_index, hit_way_sel, hit_tag, addr);
end
`endif

endmodule
