// module ysyx_23060124__icache #(
//     parameter                           ADDR_WIDTH      = 32       ,
//     parameter                           DATA_WIDTH      = 32       ,
//     parameter                           SET_NUMS        = 4        ,// Number of cache sets
//     parameter                           WORDS_PER_BLOCK = 4         // Number of 32-bit words per block
// )
// (
//     //read data channel
//     input              [  31:0]         M_AXI_RDATA                ,
//     input              [   1:0]         M_AXI_RRESP                ,
//     input                               M_AXI_RVALID               ,
//     output                              M_AXI_RREADY               ,
//     input              [   3:0]         M_AXI_RID                  ,
//     input                               M_AXI_RLAST                ,

//     //read address channel
//     output             [  31:0]         M_AXI_ARADDR               ,
//     output                              M_AXI_ARVALID              ,
//     input                               M_AXI_ARREADY              ,
//     output             [   3:0]         M_AXI_ARID                 ,
//     output             [   7:0]         M_AXI_ARLEN                ,
//     output             [   2:0]         M_AXI_ARSIZE               ,
//     output             [   1:0]         M_AXI_ARBURST              ,

//     input                               clock                      ,
//     input                               rst_n_sync                 ,
//     input              [ADDR_WIDTH-1:0] addr                       ,
//     output             [DATA_WIDTH-1:0] data                       ,

//     input                               fence_i                    ,
//     output                              hit                         
// );

// // ============================================================
// // Local Parameters
// // ============================================================
// localparam BLOCK_SIZE     = 4 * WORDS_PER_BLOCK;              // Block size in bytes (4 bytes/word * N words)
// localparam ARLEN          = BLOCK_SIZE / 4 - 1;               // AXI burst length (number of transfers - 1)
// localparam WORD_IDX_BITS  = $clog2(WORDS_PER_BLOCK);          // Bits to index a word within a block
// localparam INDEX_BITS     = $clog2(SET_NUMS);                 // Bits for set index: log2(SET_NUMS)
// localparam OFFSET_BITS    = $clog2(BLOCK_SIZE);               // Bits for byte offset within block: log2(BLOCK_SIZE)
// localparam TAG_BITS       = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // Remaining bits for tag

// // ============================================================
// // Cache Storage
// // ============================================================
// // cache_data[set][word] — each entry is DATA_WIDTH bits
// reg [DATA_WIDTH-1:0]  cache_data  [SET_NUMS-1:0][WORDS_PER_BLOCK-1:0];
// reg [TAG_BITS-1:0]    cache_tag   [SET_NUMS-1:0];
// reg [SET_NUMS-1:0]    cache_valid;

// // ============================================================
// // AXI Control Registers
// // ============================================================
// reg                             axi_arvalid;
// reg                             axi_rready;
// reg [WORD_IDX_BITS-1:0]         read_index;          // Word counter during burst read
// reg [ADDR_WIDTH-1-OFFSET_BITS:0] araddr;             // Latched address (tag + index portion)
// reg                             idle;                // FSM idle flag

// // ============================================================
// // AXI Output Assignments
// // ============================================================
// assign M_AXI_ARADDR  = {araddr, {OFFSET_BITS{1'b0}}};
// assign M_AXI_ARVALID = axi_arvalid;
// assign M_AXI_ARID    = 4'b0;
// assign M_AXI_ARLEN   = ARLEN[7:0];
// assign M_AXI_ARSIZE  = 3'b010;       // 4 bytes per transfer
// assign M_AXI_ARBURST = 2'b01;        // INCR burst
// assign M_AXI_RREADY  = axi_rready;

// // ============================================================
// // Address Decomposition (from latched araddr, offset bits already removed)
// // ============================================================
// wire [TAG_BITS-1:0]   tag   = araddr[ADDR_WIDTH-OFFSET_BITS-1 : INDEX_BITS];
// wire [INDEX_BITS-1:0] index = araddr[INDEX_BITS-1 : 0];

// // ============================================================
// // Cache Tag & Valid Control
// // ============================================================
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         cache_valid <= {SET_NUMS{1'b0}};
//     end
//     else if (M_AXI_ARVALID && ~M_AXI_ARREADY) begin
//         // Refill starting: latch new tag, invalidate the set
//         cache_tag[index]   <= tag;
//         cache_valid[index] <= 1'b0;
//     end
//     else if (M_AXI_RLAST) begin
//         // Refill complete: mark set as valid
//         cache_valid[index] <= 1'b1;
//     end
//     else if (fence_i) begin
//         // FENCE.I: invalidate entire cache
//         cache_valid <= {SET_NUMS{1'b0}};
//     end
// end

// // ============================================================
// // Address Latch & Idle Control
// // ============================================================
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         araddr <= {(ADDR_WIDTH-OFFSET_BITS){1'b0}};
//         idle   <= 1'b1;
//     end
//     else if (!hit && idle) begin
//         // Miss detected: latch the request address
//         araddr <= addr[ADDR_WIDTH-1 : OFFSET_BITS];
//         idle   <= 1'b0;
//     end
//     else if (M_AXI_RLAST && M_AXI_RREADY) begin
//         if (hit) begin
//             // Refill done and new addr hits: go idle
//             araddr <= {(ADDR_WIDTH-OFFSET_BITS){1'b0}};
//             idle   <= 1'b1;
//         end
//         else begin
//             // Refill done but new addr misses: latch new address immediately
//             araddr <= addr[ADDR_WIDTH-1 : OFFSET_BITS];
//         end
//     end
// end

// // ============================================================
// // Read Address Channel — AR handshake
// // ============================================================
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         axi_arvalid <= 1'b0;
//     end
//     else if (!hit && idle) begin
//         // Cache miss: issue read request
//         axi_arvalid <= 1'b1;
//     end
//     else if (axi_arvalid && M_AXI_ARREADY) begin
//         // AR accepted by slave: deassert
//         axi_arvalid <= 1'b0;
//     end
//     else if (M_AXI_RLAST && M_AXI_RREADY && !hit) begin
//         // Refill done but still missing: issue another request
//         axi_arvalid <= 1'b1;
//     end
// end

// // ============================================================
// // Burst Word Counter (read_index)
// // ============================================================
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         read_index <= {WORD_IDX_BITS{1'b0}};
//     end
//     else if (M_AXI_ARVALID && M_AXI_ARREADY) begin
//         // AR handshake done: reset counter for new burst
//         read_index <= {WORD_IDX_BITS{1'b0}};
//     end
//     else if (M_AXI_RVALID && ~M_AXI_RREADY) begin
//         // Accept a data beat: advance word counter
//         read_index <= read_index + 1;
//     end
// end

// // ============================================================
// // Read Data Channel — R handshake
// // ============================================================
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         axi_rready <= 1'b0;
//     end
//     else if (M_AXI_RVALID && ~axi_rready) begin
//         // Data available: assert ready for one cycle
//         axi_rready <= 1'b1;
//     end
//     else if (axi_rready) begin
//         // Deassert after one clock cycle
//         axi_rready <= 1'b0;
//     end
// end

// // ============================================================
// // Cache Data Write (burst fill)
// // ============================================================
// integer i, j;
// always @(posedge clock or negedge rst_n_sync) begin
//     if (~rst_n_sync) begin
//         for (i = 0; i < SET_NUMS; i = i + 1) begin
//             for (j = 0; j < WORDS_PER_BLOCK; j = j + 1) begin
//                 cache_data[i][j] <= {DATA_WIDTH{1'b0}};
//             end
//         end
//     end
//     else if (M_AXI_RVALID && ~axi_rready) begin
//         // Write received word into the correct set and word position
//         cache_data[index][read_index] <= M_AXI_RDATA;
//     end
// end

// // ============================================================
// // Hit Detection (combinational, from live addr)
// // ============================================================
// wire [TAG_BITS-1:0]    hit_tag    = addr[ADDR_WIDTH-1             : INDEX_BITS + OFFSET_BITS];
// wire [INDEX_BITS-1:0]  hit_index  = addr[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
// wire [OFFSET_BITS-1:0] hit_offset = addr[OFFSET_BITS-1            : 0];

// assign hit  = cache_valid[hit_index] && (cache_tag[hit_index] == hit_tag);
// assign data = cache_data[hit_index][hit_offset[OFFSET_BITS-1:2]];

// endmodule
