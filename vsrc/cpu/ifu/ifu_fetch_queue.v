module hcpu_ifu_predecode_sidecar (
    input              [31:0]           i_ins,
    output             [27:0]           o_predecode_bundle
);

localparam TYPE_I      = 7'b0010011;
localparam TYPE_I_LOAD = 7'b0000011;
localparam TYPE_JALR   = 7'b1100111;
localparam TYPE_EBRK   = 7'b1110011;
localparam TYPE_S      = 7'b0100011;
localparam TYPE_R      = 7'b0110011;
localparam TYPE_AUIPC  = 7'b0010111;
localparam TYPE_LUI    = 7'b0110111;
localparam TYPE_JAL    = 7'b1101111;
localparam TYPE_B      = 7'b1100011;
localparam TYPE_FENCE  = 7'b0001111;
localparam TYPE_COP    = 7'b0001011;
localparam TYPE_OPV    = 7'b1010111;
localparam TYPE_VLOAD  = 7'b0000111;
localparam TYPE_VSTORE = 7'b0100111;

wire [2:0] func3 = i_ins[14:12];
wire [6:0] opcode = i_ins[6:0];
wire [6:0] func7 = i_ins[31:25];
wire [4:0] rs1 = i_ins[19:15];
wire [4:0] rs2 = i_ins[24:20];
wire [4:0] rd = i_ins[11:7];

wire type_i = (opcode == TYPE_I);
wire type_i_load = (opcode == TYPE_I_LOAD);
wire type_r = (opcode == TYPE_R);
wire type_m = type_r && (func7 == 7'b0000001);
wire type_lui = (opcode == TYPE_LUI);
wire type_auipc = (opcode == TYPE_AUIPC);
wire type_jal = (opcode == TYPE_JAL);
wire type_jalr = (opcode == TYPE_JALR);
wire type_s = (opcode == TYPE_S);
wire type_b = (opcode == TYPE_B);
wire type_ebrk = (opcode == TYPE_EBRK);
wire type_cop = (opcode == TYPE_COP);
wire type_vsetivli = (opcode == TYPE_OPV) && (func3 == 3'b111) && (i_ins[31] == 1'b0);
wire type_vaddvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[31:26] == 6'b000000);
wire type_vaddvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[31:26] == 6'b000000);
wire type_vaddvi = (opcode == TYPE_OPV) && (func3 == 3'b011) && (i_ins[31:26] == 6'b000000);
wire type_vbitvv = (opcode == TYPE_OPV) && (func3 == 3'b000) &&
                   ((i_ins[31:26] == 6'b001001) || (i_ins[31:26] == 6'b001010) || (i_ins[31:26] == 6'b001011));
wire type_vbitvx = (opcode == TYPE_OPV) && (func3 == 3'b100) &&
                   ((i_ins[31:26] == 6'b001001) || (i_ins[31:26] == 6'b001010) || (i_ins[31:26] == 6'b001011));
wire type_vbitvi = (opcode == TYPE_OPV) && (func3 == 3'b011) &&
                   ((i_ins[31:26] == 6'b001001) || (i_ins[31:26] == 6'b001010) || (i_ins[31:26] == 6'b001011));
wire type_vsubvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[31:26] == 6'b000010);
wire type_vsubvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[31:26] == 6'b000010);
wire type_vshiftvv = (opcode == TYPE_OPV) && (func3 == 3'b000) &&
                     ((i_ins[31:26] == 6'b100101) || (i_ins[31:26] == 6'b101000) || (i_ins[31:26] == 6'b101001));
wire type_vshiftvx = (opcode == TYPE_OPV) && (func3 == 3'b100) &&
                     ((i_ins[31:26] == 6'b100101) || (i_ins[31:26] == 6'b101000) || (i_ins[31:26] == 6'b101001));
wire type_vmvvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[31:26] == 6'b010111);
wire type_vmvvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[31:26] == 6'b010111);
wire type_vle8v = (opcode == TYPE_VLOAD) && (func3 == 3'b000) && (i_ins[31:20] == 12'b000000100000);
wire type_vse8v = (opcode == TYPE_VSTORE) && (func3 == 3'b000) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);
wire type_vle32v = (opcode == TYPE_VLOAD) && (func3 == 3'b110) && (i_ins[31:20] == 12'b000000100000);
wire type_vse32v = (opcode == TYPE_VSTORE) && (func3 == 3'b110) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);
wire valid_ins = type_i || type_i_load || type_r || type_lui || type_auipc ||
                 type_jal || type_jalr || type_s || type_b || type_ebrk || type_cop || type_vsetivli ||
                 type_vaddvv || type_vaddvx || type_vaddvi || type_vbitvv || type_vbitvx || type_vbitvi ||
                 type_vsubvv || type_vsubvx || type_vshiftvv || type_vshiftvx || type_vmvvv || type_vmvvx ||
                 type_vle8v || type_vse8v || type_vle32v || type_vse32v ||
                 (opcode == TYPE_FENCE);

wire [4:0] sidecar_rs1_addr = (type_auipc || type_lui || type_jal || type_vaddvv || type_vaddvi ||
                               type_vbitvv || type_vbitvi || type_vsubvv || type_vshiftvv || type_vmvvv) ? 5'b0 : rs1;
wire [4:0] sidecar_rs2_addr = (type_r || type_b || type_s || type_cop) ? rs2 : 5'b0;
wire sidecar_wen = valid_ins && !(type_s || type_b || opcode == TYPE_FENCE || type_vaddvv || type_vaddvx ||
                                  type_vaddvi || type_vbitvv || type_vbitvx || type_vmvvv || type_vmvvx ||
                                  type_vbitvi || type_vsubvv || type_vsubvx || type_vshiftvv || type_vshiftvx ||
                                  type_vle8v || type_vse8v || type_vle32v || type_vse32v);
wire sidecar_csr_wen = type_ebrk && |func3;
wire sidecar_ecall = type_ebrk && (func3 == 3'b000) && (rs2[1:0] == 2'b00);
wire sidecar_mret = type_ebrk && (func3 == 3'b000) && (rs2[1:0] == 2'b10);
wire sidecar_ebreak = type_ebrk && (func3 == 3'b000) && (rs2[1:0] == 2'b01);
wire sidecar_fence_i = (opcode == TYPE_FENCE) && (func3 == 3'b001);

assign o_predecode_bundle = {
    rd,
    sidecar_rs1_addr,
    sidecar_rs2_addr,
    sidecar_wen,
    sidecar_csr_wen,
    type_i_load,
    type_s,
    type_b,
    type_jal,
    type_jalr,
    sidecar_fence_i,
    type_m,
    type_cop || type_vsetivli || type_vaddvv || type_vaddvx || type_vaddvi || type_vbitvv || type_vbitvx ||
    type_vbitvi || type_vsubvv || type_vsubvx || type_vshiftvv || type_vshiftvx || type_vmvvv || type_vmvvx ||
    type_vle8v || type_vse8v || type_vle32v || type_vse32v,
    sidecar_ecall,
    sidecar_mret,
    sidecar_ebreak
};

endmodule

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
    output                              o_predict_btb_hit,
    output             [4:0]            o_predecode_rd,
    output             [4:0]            o_predecode_rs1_addr,
    output             [4:0]            o_predecode_rs2_addr,
    output                              o_predecode_wen,
    output                              o_predecode_csr_wen,
    output                              o_predecode_load,
    output                              o_predecode_store,
    output                              o_predecode_brch,
    output                              o_predecode_jal,
    output                              o_predecode_jalr,
    output                              o_predecode_fence_i,
    output                              o_predecode_muldiv,
    output                              o_predecode_is_cop_insn,
    output                              o_predecode_ecall,
    output                              o_predecode_mret,
    output                              o_predecode_ebreak
);

localparam DEPTH = 2;
localparam PREDECODE_WIDTH = 28;

reg [31:0] pc_q [0:DEPTH-1];
reg [31:0] ins_q [0:DEPTH-1];
reg        predict_taken_q [0:DEPTH-1];
reg [29:0] predict_target_q [0:DEPTH-1];
reg        predict_btb_hit_q [0:DEPTH-1];
reg [PREDECODE_WIDTH-1:0] predecode_q [0:DEPTH-1];
reg        valid_q [0:DEPTH-1];

reg        head;
reg        tail;
reg [1:0]  count;

wire full = (count == DEPTH);
wire empty = (count == 0);
wire deq_valid = !empty;
wire enq_ready = !full || (deq_valid && i_deq_ready);
wire [1:0] valid_count = {1'b0, valid_q[0]} + {1'b0, valid_q[1]};
wire [PREDECODE_WIDTH-1:0] enq_predecode_bundle;
wire [PREDECODE_WIDTH-1:0] deq_predecode_bundle = predecode_q[head];

wire enq_fire = i_enq_valid && enq_ready;
wire deq_fire = deq_valid && i_deq_ready;

hcpu_ifu_predecode_sidecar predecode_sidecar(
    .i_ins                              (i_ins                     ),
    .o_predecode_bundle                 (enq_predecode_bundle      )
);

assign o_enq_ready = enq_ready;
assign o_deq_valid = deq_valid;
assign o_pc = pc_q[head];
assign o_ins = ins_q[head];
assign o_predict_taken = predict_taken_q[head];
assign o_predict_target = predict_target_q[head];
assign o_predict_btb_hit = predict_btb_hit_q[head];
assign {
    o_predecode_rd,
    o_predecode_rs1_addr,
    o_predecode_rs2_addr,
    o_predecode_wen,
    o_predecode_csr_wen,
    o_predecode_load,
    o_predecode_store,
    o_predecode_brch,
    o_predecode_jal,
    o_predecode_jalr,
    o_predecode_fence_i,
    o_predecode_muldiv,
    o_predecode_is_cop_insn,
    o_predecode_ecall,
    o_predecode_mret,
    o_predecode_ebreak
} = deq_predecode_bundle;

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
            predecode_q[i] <= {PREDECODE_WIDTH{1'b0}};
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
            predecode_q[tail] <= enq_predecode_bundle;
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

`ifdef PROTOCOL_ASSERT
reg        prev_deq_stall;
reg [31:0] prev_o_pc;
reg [31:0] prev_o_ins;
reg        prev_o_predict_taken;
reg [29:0] prev_o_predict_target;
reg        prev_o_predict_btb_hit;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        prev_deq_stall <= 1'b0;
        prev_o_pc <= 32'b0;
        prev_o_ins <= 32'b0;
        prev_o_predict_taken <= 1'b0;
        prev_o_predict_target <= 30'b0;
        prev_o_predict_btb_hit <= 1'b0;
    end else begin
        if (prev_deq_stall && !flush && !i_deq_ready) begin
            if (o_pc != prev_o_pc)
                $fatal(1, "ifu_fetch_queue pc changed while dequeue remained stalled");
            if (o_ins != prev_o_ins)
                $fatal(1, "ifu_fetch_queue instruction changed while dequeue remained stalled");
            if (o_predict_taken != prev_o_predict_taken)
                $fatal(1, "ifu_fetch_queue predict_taken changed while dequeue remained stalled");
            if (o_predict_target != prev_o_predict_target)
                $fatal(1, "ifu_fetch_queue predict_target changed while dequeue remained stalled");
            if (o_predict_btb_hit != prev_o_predict_btb_hit)
                $fatal(1, "ifu_fetch_queue predict_btb_hit changed while dequeue remained stalled");
        end
        prev_deq_stall <= o_deq_valid && !i_deq_ready;
        prev_o_pc <= o_pc;
        prev_o_ins <= o_ins;
        prev_o_predict_taken <= o_predict_taken;
        prev_o_predict_target <= o_predict_target;
        prev_o_predict_btb_hit <= o_predict_btb_hit;
    end
end
`endif

endmodule
