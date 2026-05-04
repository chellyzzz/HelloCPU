module hcpu_btb
(
    input               clock,
    input               reset,

    input  [31:0]       lookup_pc,
    output              predict_taken,
    output [31:2]       predict_target,
    output              lookup_hit,

    input               update_en,
    input  [31:0]       update_pc,
    input  [31:2]       update_target,
    input               update_taken
);

localparam ENTRIES = 64;
localparam INDEX_W  = 6;
localparam TAG_W    = 32 - INDEX_W - 2;

wire [INDEX_W-1:0] lookup_idx = lookup_pc[INDEX_W+1:2];
wire [TAG_W-1:0]   lookup_tag = lookup_pc[31:INDEX_W+2];

wire               hit = btb_valid[lookup_idx] && (btb_tag[lookup_idx] == lookup_tag);

assign lookup_hit       = hit;
assign predict_taken  = hit && btb_counter[lookup_idx][1];
assign predict_target = btb_target[lookup_idx];

reg                [ENTRIES-1:0] btb_valid;
reg         [TAG_W-1:0] [ENTRIES-1:0] btb_tag;
reg         [29:0] [ENTRIES-1:0] btb_target;
reg          [1:0] [ENTRIES-1:0] btb_counter;

wire [INDEX_W-1:0] upd_idx = update_pc[INDEX_W+1:2];
wire [TAG_W-1:0]   upd_tag = update_pc[31:INDEX_W+2];

wire upd_hit = btb_valid[upd_idx] && (btb_tag[upd_idx] == upd_tag);

integer i;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (i = 0; i < ENTRIES; i = i + 1) begin
            btb_valid[i]   <= 1'b0;
            btb_tag[i]     <= {TAG_W{1'b0}};
            btb_target[i]  <= 30'b0;
            btb_counter[i] <= 2'b01;
        end
    end
    else if (update_en) begin
        if (update_taken) begin
            if (upd_hit) begin
                btb_counter[upd_idx] <= (btb_counter[upd_idx] == 2'b11) ? 2'b11 :
                                        btb_counter[upd_idx] + 2'b01;
            end else begin
                btb_valid[upd_idx]   <= 1'b1;
                btb_tag[upd_idx]     <= upd_tag;
                btb_counter[upd_idx] <= 2'b10;
            end
            btb_target[upd_idx] <= update_target;
        end else begin
            if (upd_hit) begin
                btb_counter[upd_idx] <= (btb_counter[upd_idx] == 2'b00) ? 2'b00 :
                                        btb_counter[upd_idx] - 2'b01;
            end
        end
    end
end

endmodule
