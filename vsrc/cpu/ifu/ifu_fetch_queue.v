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
wire type_vaddvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[31:26] == 6'b000000) && (i_ins[25] == 1'b1);
wire type_vaddvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[31:26] == 6'b000000) && (i_ins[25] == 1'b1);
wire type_vaddvi = (opcode == TYPE_OPV) && (func3 == 3'b011) && (i_ins[31:26] == 6'b000000) && (i_ins[25] == 1'b1);
wire type_vbitvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[25] == 1'b1) &&
                   ((i_ins[31:26] == 6'b001001) || (i_ins[31:26] == 6'b001010) || (i_ins[31:26] == 6'b001011));
wire type_vbitvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[25] == 1'b1) &&
                   ((i_ins[31:26] == 6'b001001) || (i_ins[31:26] == 6'b001010) || (i_ins[31:26] == 6'b001011));
wire type_vmvvv = (opcode == TYPE_OPV) && (func3 == 3'b000) && (i_ins[31:26] == 6'b010111) && (i_ins[25] == 1'b1);
wire type_vmvvx = (opcode == TYPE_OPV) && (func3 == 3'b100) && (i_ins[31:26] == 6'b010111) && (i_ins[25] == 1'b1);
wire type_vle8v = (opcode == TYPE_VLOAD) && (func3 == 3'b000) && (i_ins[31:20] == 12'b000000100000);
wire type_vse8v = (opcode == TYPE_VSTORE) && (func3 == 3'b000) && (i_ins[31:25] == 7'b0000001) && (i_ins[24:20] == 5'b00000);
wire valid_ins = type_i || type_i_load || type_r || type_lui || type_auipc ||
                 type_jal || type_jalr || type_s || type_b || type_ebrk || type_cop || type_vsetivli ||
                 type_vaddvv || type_vaddvx || type_vaddvi || type_vbitvv || type_vbitvx || type_vmvvv || type_vmvvx ||
                 type_vle8v || type_vse8v ||
                 (opcode == TYPE_FENCE);

wire [4:0] sidecar_rs1_addr = (type_auipc || type_lui || type_jal || type_vaddvv || type_vaddvi || type_vbitvv || type_vmvvv) ? 5'b0 : rs1;
wire [4:0] sidecar_rs2_addr = (type_r || type_b || type_s || type_cop) ? rs2 : 5'b0;
wire sidecar_wen = valid_ins && !(type_s || type_b || opcode == TYPE_FENCE || type_vaddvv || type_vaddvx ||
                                  type_vaddvi || type_vbitvv || type_vbitvx || type_vmvvv || type_vmvvx ||
                                  type_vle8v || type_vse8v);
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
    type_vmvvv || type_vmvvx || type_vle8v || type_vse8v,
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
    output                              o_predecode_ebreak,
    output                              o_pair_valid,
    output                              o_pair_candidate_alu_branch,
    output                              o_pair_has_raw,
    output                              o_pair_has_waw,
    output                              o_pair_has_dual_writeback,
    output                              o_pair_has_exclusive_backend,
    output                              o_pair_has_redirect_control,
    output                              o_pair_order_alu_then_branch,
    output                              o_pair_order_branch_then_alu,
    output                              o_pair_younger_valid,
    output             [31:0]           o_pair_younger_pc,
    output             [31:0]           o_pair_younger_ins,
    output                              o_pair_younger_predict_taken,
    output             [31:2]           o_pair_younger_predict_target,
    output                              o_pair_younger_predict_btb_hit,
    output             [4:0]            o_pair_younger_predecode_rd,
    output             [4:0]            o_pair_younger_predecode_rs1_addr,
    output             [4:0]            o_pair_younger_predecode_rs2_addr,
    output                              o_pair_younger_predecode_wen,
    output                              o_pair_younger_predecode_csr_wen,
    output                              o_pair_younger_predecode_load,
    output                              o_pair_younger_predecode_store,
    output                              o_pair_younger_predecode_brch,
    output                              o_pair_younger_predecode_jal,
    output                              o_pair_younger_predecode_jalr,
    output                              o_pair_younger_predecode_fence_i,
    output                              o_pair_younger_predecode_muldiv,
    output                              o_pair_younger_predecode_is_cop_insn,
    output                              o_pair_younger_predecode_ecall,
    output                              o_pair_younger_predecode_mret,
    output                              o_pair_younger_predecode_ebreak
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
wire next_head = head + 1'b1;
wire [PREDECODE_WIDTH-1:0] pair_predecode_bundle = predecode_q[next_head];

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

wire [4:0] pair0_rd;
wire [4:0] pair0_rs1_addr;
wire [4:0] pair0_rs2_addr;
wire       pair0_wen;
wire       pair0_csr_wen;
wire       pair0_load;
wire       pair0_store;
wire       pair0_brch;
wire       pair0_jal;
wire       pair0_jalr;
wire       pair0_fence_i;
wire       pair0_muldiv;
wire       pair0_is_cop_insn;
wire       pair0_ecall;
wire       pair0_mret;
wire       pair0_ebreak;

wire [4:0] pair1_rd;
wire [4:0] pair1_rs1_addr;
wire [4:0] pair1_rs2_addr;
wire       pair1_wen;
wire       pair1_csr_wen;
wire       pair1_load;
wire       pair1_store;
wire       pair1_brch;
wire       pair1_jal;
wire       pair1_jalr;
wire       pair1_fence_i;
wire       pair1_muldiv;
wire       pair1_is_cop_insn;
wire       pair1_ecall;
wire       pair1_mret;
wire       pair1_ebreak;

assign {
    pair0_rd,
    pair0_rs1_addr,
    pair0_rs2_addr,
    pair0_wen,
    pair0_csr_wen,
    pair0_load,
    pair0_store,
    pair0_brch,
    pair0_jal,
    pair0_jalr,
    pair0_fence_i,
    pair0_muldiv,
    pair0_is_cop_insn,
    pair0_ecall,
    pair0_mret,
    pair0_ebreak
} = deq_predecode_bundle;

assign {
    pair1_rd,
    pair1_rs1_addr,
    pair1_rs2_addr,
    pair1_wen,
    pair1_csr_wen,
    pair1_load,
    pair1_store,
    pair1_brch,
    pair1_jal,
    pair1_jalr,
    pair1_fence_i,
    pair1_muldiv,
    pair1_is_cop_insn,
    pair1_ecall,
    pair1_mret,
    pair1_ebreak
} = pair_predecode_bundle;

wire pair0_is_simple_alu = !pair0_load && !pair0_store && !pair0_brch && !pair0_jal &&
                           !pair0_jalr && !pair0_fence_i && !pair0_muldiv &&
                           !pair0_is_cop_insn && !pair0_ecall && !pair0_mret &&
                           !pair0_ebreak && !pair0_csr_wen;
wire pair1_is_simple_alu = !pair1_load && !pair1_store && !pair1_brch && !pair1_jal &&
                           !pair1_jalr && !pair1_fence_i && !pair1_muldiv &&
                           !pair1_is_cop_insn && !pair1_ecall && !pair1_mret &&
                           !pair1_ebreak && !pair1_csr_wen;
wire pair0_has_exclusive_backend = pair0_load || pair0_store || pair0_muldiv || pair0_is_cop_insn;
wire pair1_has_exclusive_backend = pair1_load || pair1_store || pair1_muldiv || pair1_is_cop_insn;
wire pair0_has_redirect_control = pair0_jal || pair0_jalr || pair0_fence_i || pair0_ecall ||
                                  pair0_mret || pair0_ebreak;
wire pair1_has_redirect_control = pair1_jal || pair1_jalr || pair1_fence_i || pair1_ecall ||
                                  pair1_mret || pair1_ebreak;
wire pair_has_raw = pair0_wen && (pair0_rd != 5'b0) &&
                    (((pair1_rs1_addr == pair0_rd) && (pair1_rs1_addr != 5'b0)) ||
                     ((pair1_rs2_addr == pair0_rd) && (pair1_rs2_addr != 5'b0)));
wire pair_has_waw = pair0_wen && pair1_wen && (pair0_rd != 5'b0) && (pair1_rd == pair0_rd);
wire pair_has_dual_writeback = pair0_wen && pair1_wen;
wire pair_has_exclusive_backend = pair0_has_exclusive_backend || pair1_has_exclusive_backend;
wire pair_has_redirect_control = pair0_has_redirect_control || pair1_has_redirect_control;
wire pair_order_alu_then_branch = pair0_is_simple_alu && pair1_brch;
wire pair_order_branch_then_alu = pair0_brch && pair1_is_simple_alu;
wire pair_candidate_alu_branch = pair_order_alu_then_branch || pair_order_branch_then_alu;

assign o_pair_valid = (count == DEPTH);
assign o_pair_candidate_alu_branch = o_pair_valid && pair_candidate_alu_branch && !pair_has_raw &&
                                     !pair_has_waw && !pair_has_dual_writeback &&
                                     !pair_has_exclusive_backend && !pair_has_redirect_control;
assign o_pair_has_raw = o_pair_valid && pair_has_raw;
assign o_pair_has_waw = o_pair_valid && pair_has_waw;
assign o_pair_has_dual_writeback = o_pair_valid && pair_has_dual_writeback;
assign o_pair_has_exclusive_backend = o_pair_valid && pair_has_exclusive_backend;
assign o_pair_has_redirect_control = o_pair_valid && pair_has_redirect_control;
assign o_pair_order_alu_then_branch = o_pair_valid && pair_order_alu_then_branch;
assign o_pair_order_branch_then_alu = o_pair_valid && pair_order_branch_then_alu;
assign o_pair_younger_valid = o_pair_valid;
assign o_pair_younger_pc = o_pair_younger_valid ? pc_q[next_head] : 32'b0;
assign o_pair_younger_ins = o_pair_younger_valid ? ins_q[next_head] : 32'b0;
assign o_pair_younger_predict_taken = o_pair_younger_valid && predict_taken_q[next_head];
assign o_pair_younger_predict_target = o_pair_younger_valid ? predict_target_q[next_head] : 30'b0;
assign o_pair_younger_predict_btb_hit = o_pair_younger_valid && predict_btb_hit_q[next_head];
assign o_pair_younger_predecode_rd = o_pair_younger_valid ? pair1_rd : 5'b0;
assign o_pair_younger_predecode_rs1_addr = o_pair_younger_valid ? pair1_rs1_addr : 5'b0;
assign o_pair_younger_predecode_rs2_addr = o_pair_younger_valid ? pair1_rs2_addr : 5'b0;
assign o_pair_younger_predecode_wen = o_pair_younger_valid && pair1_wen;
assign o_pair_younger_predecode_csr_wen = o_pair_younger_valid && pair1_csr_wen;
assign o_pair_younger_predecode_load = o_pair_younger_valid && pair1_load;
assign o_pair_younger_predecode_store = o_pair_younger_valid && pair1_store;
assign o_pair_younger_predecode_brch = o_pair_younger_valid && pair1_brch;
assign o_pair_younger_predecode_jal = o_pair_younger_valid && pair1_jal;
assign o_pair_younger_predecode_jalr = o_pair_younger_valid && pair1_jalr;
assign o_pair_younger_predecode_fence_i = o_pair_younger_valid && pair1_fence_i;
assign o_pair_younger_predecode_muldiv = o_pair_younger_valid && pair1_muldiv;
assign o_pair_younger_predecode_is_cop_insn = o_pair_younger_valid && pair1_is_cop_insn;
assign o_pair_younger_predecode_ecall = o_pair_younger_valid && pair1_ecall;
assign o_pair_younger_predecode_mret = o_pair_younger_valid && pair1_mret;
assign o_pair_younger_predecode_ebreak = o_pair_younger_valid && pair1_ebreak;

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
reg        prev_pair_stall;
reg        prev_o_pair_valid;
reg        prev_o_pair_candidate_alu_branch;
reg        prev_o_pair_has_raw;
reg        prev_o_pair_has_waw;
reg        prev_o_pair_has_dual_writeback;
reg        prev_o_pair_has_exclusive_backend;
reg        prev_o_pair_has_redirect_control;
reg        prev_o_pair_order_alu_then_branch;
reg        prev_o_pair_order_branch_then_alu;
reg [31:0] prev_o_pair_younger_pc;
reg [31:0] prev_o_pair_younger_ins;
reg        prev_o_pair_younger_predict_taken;
reg [29:0] prev_o_pair_younger_predict_target;
reg        prev_o_pair_younger_predict_btb_hit;
reg [PREDECODE_WIDTH-1:0] prev_o_pair_younger_predecode_bundle;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        prev_deq_stall <= 1'b0;
        prev_o_pc <= 32'b0;
        prev_o_ins <= 32'b0;
        prev_o_predict_taken <= 1'b0;
        prev_o_predict_target <= 30'b0;
        prev_o_predict_btb_hit <= 1'b0;
        prev_pair_stall <= 1'b0;
        prev_o_pair_valid <= 1'b0;
        prev_o_pair_candidate_alu_branch <= 1'b0;
        prev_o_pair_has_raw <= 1'b0;
        prev_o_pair_has_waw <= 1'b0;
        prev_o_pair_has_dual_writeback <= 1'b0;
        prev_o_pair_has_exclusive_backend <= 1'b0;
        prev_o_pair_has_redirect_control <= 1'b0;
        prev_o_pair_order_alu_then_branch <= 1'b0;
        prev_o_pair_order_branch_then_alu <= 1'b0;
        prev_o_pair_younger_pc <= 32'b0;
        prev_o_pair_younger_ins <= 32'b0;
        prev_o_pair_younger_predict_taken <= 1'b0;
        prev_o_pair_younger_predict_target <= 30'b0;
        prev_o_pair_younger_predict_btb_hit <= 1'b0;
        prev_o_pair_younger_predecode_bundle <= {PREDECODE_WIDTH{1'b0}};
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
        if (prev_pair_stall && !flush && !i_deq_ready) begin
            if (o_pair_valid != prev_o_pair_valid)
                $fatal(1, "ifu_fetch_queue pair_valid changed while full queue remained stalled");
            if (o_pair_candidate_alu_branch != prev_o_pair_candidate_alu_branch)
                $fatal(1, "ifu_fetch_queue pair candidate changed while full queue remained stalled");
            if (o_pair_has_raw != prev_o_pair_has_raw)
                $fatal(1, "ifu_fetch_queue pair raw flag changed while full queue remained stalled");
            if (o_pair_has_waw != prev_o_pair_has_waw)
                $fatal(1, "ifu_fetch_queue pair waw flag changed while full queue remained stalled");
            if (o_pair_has_dual_writeback != prev_o_pair_has_dual_writeback)
                $fatal(1, "ifu_fetch_queue pair dual-writeback flag changed while full queue remained stalled");
            if (o_pair_has_exclusive_backend != prev_o_pair_has_exclusive_backend)
                $fatal(1, "ifu_fetch_queue pair exclusive-backend flag changed while full queue remained stalled");
            if (o_pair_has_redirect_control != prev_o_pair_has_redirect_control)
                $fatal(1, "ifu_fetch_queue pair redirect-control flag changed while full queue remained stalled");
            if (o_pair_order_alu_then_branch != prev_o_pair_order_alu_then_branch)
                $fatal(1, "ifu_fetch_queue pair order alu-then-branch changed while full queue remained stalled");
            if (o_pair_order_branch_then_alu != prev_o_pair_order_branch_then_alu)
                $fatal(1, "ifu_fetch_queue pair order branch-then-alu changed while full queue remained stalled");
            if (o_pair_younger_pc != prev_o_pair_younger_pc)
                $fatal(1, "ifu_fetch_queue younger pc changed while full queue remained stalled");
            if (o_pair_younger_ins != prev_o_pair_younger_ins)
                $fatal(1, "ifu_fetch_queue younger instruction changed while full queue remained stalled");
            if (o_pair_younger_predict_taken != prev_o_pair_younger_predict_taken)
                $fatal(1, "ifu_fetch_queue younger predict_taken changed while full queue remained stalled");
            if (o_pair_younger_predict_target != prev_o_pair_younger_predict_target)
                $fatal(1, "ifu_fetch_queue younger predict_target changed while full queue remained stalled");
            if (o_pair_younger_predict_btb_hit != prev_o_pair_younger_predict_btb_hit)
                $fatal(1, "ifu_fetch_queue younger predict_btb_hit changed while full queue remained stalled");
            if ({
                o_pair_younger_predecode_rd,
                o_pair_younger_predecode_rs1_addr,
                o_pair_younger_predecode_rs2_addr,
                o_pair_younger_predecode_wen,
                o_pair_younger_predecode_csr_wen,
                o_pair_younger_predecode_load,
                o_pair_younger_predecode_store,
                o_pair_younger_predecode_brch,
                o_pair_younger_predecode_jal,
                o_pair_younger_predecode_jalr,
                o_pair_younger_predecode_fence_i,
                o_pair_younger_predecode_muldiv,
                o_pair_younger_predecode_is_cop_insn,
                o_pair_younger_predecode_ecall,
                o_pair_younger_predecode_mret,
                o_pair_younger_predecode_ebreak
            } != prev_o_pair_younger_predecode_bundle)
                $fatal(1, "ifu_fetch_queue younger predecode bundle changed while full queue remained stalled");
        end
        prev_deq_stall <= o_deq_valid && !i_deq_ready;
        prev_o_pc <= o_pc;
        prev_o_ins <= o_ins;
        prev_o_predict_taken <= o_predict_taken;
        prev_o_predict_target <= o_predict_target;
        prev_o_predict_btb_hit <= o_predict_btb_hit;
        prev_pair_stall <= o_pair_valid && !i_deq_ready;
        prev_o_pair_valid <= o_pair_valid;
        prev_o_pair_candidate_alu_branch <= o_pair_candidate_alu_branch;
        prev_o_pair_has_raw <= o_pair_has_raw;
        prev_o_pair_has_waw <= o_pair_has_waw;
        prev_o_pair_has_dual_writeback <= o_pair_has_dual_writeback;
        prev_o_pair_has_exclusive_backend <= o_pair_has_exclusive_backend;
        prev_o_pair_has_redirect_control <= o_pair_has_redirect_control;
        prev_o_pair_order_alu_then_branch <= o_pair_order_alu_then_branch;
        prev_o_pair_order_branch_then_alu <= o_pair_order_branch_then_alu;
        prev_o_pair_younger_pc <= o_pair_younger_pc;
        prev_o_pair_younger_ins <= o_pair_younger_ins;
        prev_o_pair_younger_predict_taken <= o_pair_younger_predict_taken;
        prev_o_pair_younger_predict_target <= o_pair_younger_predict_target;
        prev_o_pair_younger_predict_btb_hit <= o_pair_younger_predict_btb_hit;
        prev_o_pair_younger_predecode_bundle <= {
            o_pair_younger_predecode_rd,
            o_pair_younger_predecode_rs1_addr,
            o_pair_younger_predecode_rs2_addr,
            o_pair_younger_predecode_wen,
            o_pair_younger_predecode_csr_wen,
            o_pair_younger_predecode_load,
            o_pair_younger_predecode_store,
            o_pair_younger_predecode_brch,
            o_pair_younger_predecode_jal,
            o_pair_younger_predecode_jalr,
            o_pair_younger_predecode_fence_i,
            o_pair_younger_predecode_muldiv,
            o_pair_younger_predecode_is_cop_insn,
            o_pair_younger_predecode_ecall,
            o_pair_younger_predecode_mret,
            o_pair_younger_predecode_ebreak
        };
    end
end
`endif

endmodule
