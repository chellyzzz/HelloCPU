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

localparam ENTRIES = 128;
localparam INDEX_W  = 7;
localparam TAG_W    = 32 - INDEX_W - 2;
localparam BHT_ENTRIES = 512;
localparam BHT_INDEX_W = 9;
localparam LHT_ENTRIES = 1024;
localparam LHT_INDEX_W = 10;
localparam LOCAL_HIST_W = 8;
localparam LOCAL_PHT_ENTRIES = 256;
localparam CHOOSER_ENTRIES = 1024;
localparam CHOOSER_INDEX_W = 10;
localparam LOOP_ENTRIES = 128;
localparam LOOP_INDEX_W = 7;
localparam LOOP_TAG_W = 32 - LOOP_INDEX_W - 2;
localparam LOOP_TRIP_W = 16;

wire [INDEX_W-1:0] lookup_idx = lookup_pc[INDEX_W+1:2];
wire [TAG_W-1:0]   lookup_tag = lookup_pc[31:INDEX_W+2];
wire [BHT_INDEX_W-1:0] bht_lookup_idx = lookup_pc[BHT_INDEX_W+1:2];
wire [1:0]         bht_lookup_counter = bht_counter[bht_lookup_idx];
wire [LHT_INDEX_W-1:0] local_lookup_idx = lookup_pc[LHT_INDEX_W+1:2];
wire [LOCAL_HIST_W-1:0] local_lookup_hist = local_history[local_lookup_idx];
wire [1:0]         local_lookup_counter = local_pht[local_lookup_hist];
wire [CHOOSER_INDEX_W-1:0] chooser_lookup_idx = lookup_pc[CHOOSER_INDEX_W+1:2];
wire [LOOP_INDEX_W-1:0] loop_lookup_idx = lookup_pc[LOOP_INDEX_W+1:2];
wire [LOOP_TAG_W-1:0] loop_lookup_tag = lookup_pc[31:LOOP_INDEX_W+2];

wire               hit = btb_valid[lookup_idx] && (btb_tag[lookup_idx] == lookup_tag);
wire               btb_predict_taken_hit = (btb_counter[lookup_idx] == 2'b11) ? 1'b1 :
                                            (btb_counter[lookup_idx] == 2'b00) ? 1'b0 :
                                            bht_lookup_counter[1];
wire               current_predict_taken = hit ? btb_predict_taken_hit : bht_lookup_counter[1];
wire               local_predict_taken = local_lookup_counter[1];
wire               chooser_select_local = chooser_counter[chooser_lookup_idx][1];
wire               tournament_predict_taken = chooser_select_local ? local_predict_taken : current_predict_taken;
wire               loop_lookup_hit = loop_valid[loop_lookup_idx] && (loop_tag[loop_lookup_idx] == loop_lookup_tag);
wire               loop_predict_exit = loop_lookup_hit &&
                                       (loop_confidence[loop_lookup_idx] == 2'b11) &&
                                       (loop_trip_count[loop_lookup_idx] != {LOOP_TRIP_W{1'b0}}) &&
                                       (loop_iter_count[loop_lookup_idx] >= loop_trip_count[loop_lookup_idx]);

assign lookup_hit       = hit;
assign predict_taken  = loop_predict_exit ? 1'b0 : tournament_predict_taken;
assign predict_target = btb_target[lookup_idx];

reg                btb_valid   [0:ENTRIES-1];
reg         [TAG_W-1:0] btb_tag     [0:ENTRIES-1];
reg         [29:0] btb_target  [0:ENTRIES-1];
reg          [1:0] btb_counter [0:ENTRIES-1];
reg          [1:0] bht_counter [0:BHT_ENTRIES-1];
reg [LOCAL_HIST_W-1:0] local_history [0:LHT_ENTRIES-1];
reg          [1:0] local_pht [0:LOCAL_PHT_ENTRIES-1];
reg          [1:0] chooser_counter [0:CHOOSER_ENTRIES-1];
reg                loop_valid [0:LOOP_ENTRIES-1];
reg [LOOP_TAG_W-1:0] loop_tag [0:LOOP_ENTRIES-1];
reg [LOOP_TRIP_W-1:0] loop_trip_count [0:LOOP_ENTRIES-1];
reg [LOOP_TRIP_W-1:0] loop_iter_count [0:LOOP_ENTRIES-1];
reg          [1:0] loop_confidence [0:LOOP_ENTRIES-1];

wire [INDEX_W-1:0] upd_idx = update_pc[INDEX_W+1:2];
wire [TAG_W-1:0]   upd_tag = update_pc[31:INDEX_W+2];
wire [BHT_INDEX_W-1:0] bht_upd_idx = update_pc[BHT_INDEX_W+1:2];
wire [LHT_INDEX_W-1:0] local_upd_idx = update_pc[LHT_INDEX_W+1:2];
wire [LOCAL_HIST_W-1:0] local_upd_hist = local_history[local_upd_idx];
wire [1:0] local_upd_counter = local_pht[local_upd_hist];
wire [CHOOSER_INDEX_W-1:0] chooser_upd_idx = update_pc[CHOOSER_INDEX_W+1:2];
wire [LOOP_INDEX_W-1:0] loop_upd_idx = update_pc[LOOP_INDEX_W+1:2];
wire [LOOP_TAG_W-1:0] loop_upd_tag = update_pc[31:LOOP_INDEX_W+2];
wire update_backward_branch = {update_target, 2'b00} < update_pc;

wire upd_hit = btb_valid[upd_idx] && (btb_tag[upd_idx] == upd_tag);
wire current_update_taken_hit = (btb_counter[upd_idx] == 2'b11) ? 1'b1 :
                                (btb_counter[upd_idx] == 2'b00) ? 1'b0 :
                                bht_counter[bht_upd_idx][1];
wire current_update_taken = upd_hit ? current_update_taken_hit : bht_counter[bht_upd_idx][1];
wire local_update_taken = local_upd_counter[1];
wire current_update_correct = (current_update_taken == update_taken);
wire local_update_correct = (local_update_taken == update_taken);
wire loop_upd_hit = loop_valid[loop_upd_idx] && (loop_tag[loop_upd_idx] == loop_upd_tag);

integer i;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        for (i = 0; i < ENTRIES; i = i + 1) begin
            btb_valid[i]   = 1'b0;
            btb_tag[i]     = {TAG_W{1'b0}};
            btb_target[i]  = 30'b0;
            btb_counter[i] = 2'b01;
        end
        for (i = 0; i < BHT_ENTRIES; i = i + 1) begin
            bht_counter[i] = 2'b01;
        end
        for (i = 0; i < LHT_ENTRIES; i = i + 1) begin
            local_history[i] = {LOCAL_HIST_W{1'b0}};
        end
        for (i = 0; i < LOCAL_PHT_ENTRIES; i = i + 1) begin
            local_pht[i] = 2'b01;
        end
        for (i = 0; i < CHOOSER_ENTRIES; i = i + 1) begin
            chooser_counter[i] = 2'b01;
        end
        for (i = 0; i < LOOP_ENTRIES; i = i + 1) begin
            loop_valid[i] = 1'b0;
            loop_tag[i] = {LOOP_TAG_W{1'b0}};
            loop_trip_count[i] = {LOOP_TRIP_W{1'b0}};
            loop_iter_count[i] = {LOOP_TRIP_W{1'b0}};
            loop_confidence[i] = 2'b00;
        end
    end
    else if (update_en) begin
        if (current_update_correct != local_update_correct) begin
            if (local_update_correct) begin
                chooser_counter[chooser_upd_idx] <= (chooser_counter[chooser_upd_idx] == 2'b11) ? 2'b11 :
                                                    chooser_counter[chooser_upd_idx] + 2'b01;
            end else begin
                chooser_counter[chooser_upd_idx] <= (chooser_counter[chooser_upd_idx] == 2'b00) ? 2'b00 :
                                                    chooser_counter[chooser_upd_idx] - 2'b01;
            end
        end

        if (update_taken) begin
            bht_counter[bht_upd_idx] <= (bht_counter[bht_upd_idx] == 2'b11) ? 2'b11 :
                                        bht_counter[bht_upd_idx] + 2'b01;
            local_pht[local_upd_hist] <= (local_pht[local_upd_hist] == 2'b11) ? 2'b11 :
                                         local_pht[local_upd_hist] + 2'b01;
        end else begin
            bht_counter[bht_upd_idx] <= (bht_counter[bht_upd_idx] == 2'b00) ? 2'b00 :
                                        bht_counter[bht_upd_idx] - 2'b01;
            local_pht[local_upd_hist] <= (local_pht[local_upd_hist] == 2'b00) ? 2'b00 :
                                         local_pht[local_upd_hist] - 2'b01;
        end
        local_history[local_upd_idx] <= {local_upd_hist[LOCAL_HIST_W-2:0], update_taken};

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
                btb_counter[upd_idx] <= (btb_counter[upd_idx] <= 2'b01) ? 2'b00 :
                                        btb_counter[upd_idx] - 2'b10;
            end
        end

        if (update_backward_branch) begin
            if (!loop_upd_hit) begin
                loop_valid[loop_upd_idx] <= 1'b1;
                loop_tag[loop_upd_idx] <= loop_upd_tag;
                loop_trip_count[loop_upd_idx] <= {LOOP_TRIP_W{1'b0}};
                loop_iter_count[loop_upd_idx] <= update_taken ? {{(LOOP_TRIP_W-1){1'b0}}, 1'b1} : {LOOP_TRIP_W{1'b0}};
                loop_confidence[loop_upd_idx] <= 2'b00;
            end else if (update_taken) begin
                loop_iter_count[loop_upd_idx] <= (loop_iter_count[loop_upd_idx] == {LOOP_TRIP_W{1'b1}}) ?
                                                 loop_iter_count[loop_upd_idx] :
                                                 loop_iter_count[loop_upd_idx] + {{(LOOP_TRIP_W-1){1'b0}}, 1'b1};
            end else begin
                if (loop_iter_count[loop_upd_idx] != {LOOP_TRIP_W{1'b0}}) begin
                    if (loop_trip_count[loop_upd_idx] == loop_iter_count[loop_upd_idx]) begin
                        loop_confidence[loop_upd_idx] <= (loop_confidence[loop_upd_idx] == 2'b11) ? 2'b11 :
                                                         loop_confidence[loop_upd_idx] + 2'b01;
                    end else begin
                        loop_trip_count[loop_upd_idx] <= loop_iter_count[loop_upd_idx];
                        loop_confidence[loop_upd_idx] <= (loop_confidence[loop_upd_idx] == 2'b00) ? 2'b00 :
                                                         loop_confidence[loop_upd_idx] - 2'b01;
                    end
                end
                loop_iter_count[loop_upd_idx] <= {LOOP_TRIP_W{1'b0}};
            end
        end
    end
end

endmodule
