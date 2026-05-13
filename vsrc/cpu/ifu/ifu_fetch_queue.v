module hcpu_ifu_fetch_queue (
    input                               clock,
    input                               reset,
    input                               flush,

    input                               i_enq_valid,
    output                              o_enq_ready,
    input              [31:0]           i_pc,
    input              [31:0]           i_ins,
    input                               i_predict_taken,
    input              [31:2]           i_predict_target,
    input                               i_predict_btb_hit,

    input                               i_deq_ready,
    output                              o_deq_valid,
    output             [31:0]           o_pc,
    output             [31:0]           o_ins,
    output                              o_predict_taken,
    output             [31:2]           o_predict_target,
    output                              o_predict_btb_hit
);

localparam DEPTH = 2;

reg [31:0] pc_q [0:DEPTH-1];
reg [31:0] ins_q [0:DEPTH-1];
reg        predict_taken_q [0:DEPTH-1];
reg [29:0] predict_target_q [0:DEPTH-1];
reg        predict_btb_hit_q [0:DEPTH-1];
reg        valid_q [0:DEPTH-1];

reg        head;
reg        tail;
reg [1:0]  count;

wire full = (count == DEPTH);
wire empty = (count == 0);
wire deq_valid = !empty;
wire enq_ready = !full || (deq_valid && i_deq_ready);
wire [1:0] valid_count = {1'b0, valid_q[0]} + {1'b0, valid_q[1]};

wire enq_fire = i_enq_valid && enq_ready;
wire deq_fire = deq_valid && i_deq_ready;

assign o_enq_ready = enq_ready;
assign o_deq_valid = deq_valid;
assign o_pc = pc_q[head];
assign o_ins = ins_q[head];
assign o_predict_taken = predict_taken_q[head];
assign o_predict_target = predict_target_q[head];
assign o_predict_btb_hit = predict_btb_hit_q[head];

integer i;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        head <= 1'b0;
        tail <= 1'b0;
        count <= 2'b0;
        for (i = 0; i < DEPTH; i = i + 1) begin
            pc_q[i] <= 32'b0;
            ins_q[i] <= 32'b0;
            predict_taken_q[i] <= 1'b0;
            predict_target_q[i] <= 30'b0;
            predict_btb_hit_q[i] <= 1'b0;
            valid_q[i] <= 1'b0;
        end
    end else if (flush) begin
        head <= 1'b0;
        tail <= 1'b0;
        count <= 2'b0;
        for (i = 0; i < DEPTH; i = i + 1) begin
            valid_q[i] <= 1'b0;
        end
    end else begin
        if (deq_fire) begin
            valid_q[head] <= 1'b0;
            head <= head + 1'b1;
        end

        if (enq_fire) begin
            pc_q[tail] <= i_pc;
            ins_q[tail] <= i_ins;
            predict_taken_q[tail] <= i_predict_taken;
            predict_target_q[tail] <= i_predict_target;
            predict_btb_hit_q[tail] <= i_predict_btb_hit;
            valid_q[tail] <= 1'b1;
            tail <= tail + 1'b1;
        end

        case ({enq_fire, deq_fire})
            2'b10: count <= count + 2'd1;
            2'b01: count <= count - 2'd1;
            default: count <= count;
        endcase
    end
end

`ifndef SYNTHESIS
always @(*) begin
    if (count > DEPTH)
        $fatal(1, "ifu_fetch_queue count overflow");
    if (valid_count != count)
        $fatal(1, "ifu_fetch_queue valid/count mismatch");
    if ((count == 0) != empty)
        $fatal(1, "ifu_fetch_queue empty mismatch");
    if ((count == DEPTH) != full)
        $fatal(1, "ifu_fetch_queue full mismatch");
    if (o_deq_valid != !empty)
        $fatal(1, "ifu_fetch_queue deq valid mismatch");
    if (count == 0 && (head != tail))
        $fatal(1, "ifu_fetch_queue empty queue head/tail mismatch");
end
`endif

endmodule
