module hcpu_cop_backend(
    input               clock,
    input               reset,
    input               i_pre_valid,
    input               i_post_ready,
    input               i_flush,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [31:0]   i_ins,
    output              o_cop_mem_req_valid,
    output              o_cop_mem_req_store,
    output     [31:0]   o_cop_mem_req_addr,
    output     [31:0]   o_cop_mem_req_wdata,
    output     [2:0]    o_cop_mem_req_size,
    input               i_cop_mem_resp_valid,
    input      [31:0]   i_cop_mem_resp_rdata,
    output              o_pre_ready,
    output              o_post_valid,
    output              o_busy,
    output     [31:0]   o_vector_vl,
    output     [31:0]   o_vector_vtype,
    output     [31:0]   o_vector_vstart,
    output     [31:0]   o_res
);

wire        cop_done;
wire [31:0] cop_res;
wire [31:0] cop_vl;
wire [31:0] cop_vtype;
wire [31:0] cop_vstart;
wire        cop_mem_req_valid;
wire        cop_mem_req_store;
wire [31:0] cop_mem_addr;
wire [31:0] cop_mem_wdata;
wire [2:0]  cop_mem_size;
wire        backend_accept;
wire        backend_done;
wire        backend_commit_visible;
wire        backend_resp_fire;
reg         cop_busy;
reg         resp_valid;
reg [31:0]  resp_res;

hcpu_dummy_coprocessor u_dummy_coprocessor(
    .clock      (clock),
    .reset      (reset),
    .i_flush    (i_flush),
    .i_valid    (i_pre_valid),
    .i_src1     (i_src1),
    .i_src2     (i_src2),
    .i_ins      (i_ins),
    .o_res      (cop_res),
    .o_vl       (cop_vl),
    .o_vtype    (cop_vtype),
    .o_vstart   (cop_vstart),
    .o_done     (cop_done),
    .o_cop_mem_req_valid (cop_mem_req_valid),
    .o_cop_mem_req_store (cop_mem_req_store),
    .o_cop_mem_req_addr  (cop_mem_addr),
    .o_cop_mem_req_wdata (cop_mem_wdata),
    .o_cop_mem_req_size  (cop_mem_size),
    .i_cop_mem_resp_valid(i_cop_mem_resp_valid),
    .i_cop_mem_resp_rdata(i_cop_mem_resp_rdata)
);

assign backend_accept = i_pre_valid && !cop_busy && !resp_valid;
assign backend_done = cop_done;
assign backend_commit_visible = resp_valid;
assign backend_resp_fire = backend_commit_visible && i_post_ready;

assign o_pre_ready = !cop_busy && !resp_valid;
assign o_post_valid = backend_commit_visible;
assign o_busy = cop_busy || resp_valid;
assign o_vector_vl = cop_vl;
assign o_vector_vtype = cop_vtype;
assign o_vector_vstart = cop_vstart;
assign o_res = resp_res;
assign o_cop_mem_req_valid = cop_mem_req_valid;
assign o_cop_mem_req_store = cop_mem_req_store;
assign o_cop_mem_req_addr = cop_mem_addr;
assign o_cop_mem_req_wdata = cop_mem_wdata;
assign o_cop_mem_req_size = cop_mem_size;

always @(posedge clock or posedge reset) begin
    if (reset || i_flush) begin
        cop_busy <= 1'b0;
        resp_valid <= 1'b0;
        resp_res <= 32'b0;
    end else begin
        if (backend_accept) begin
            cop_busy <= 1'b1;
        end

        if (backend_done) begin
            cop_busy <= 1'b0;
            resp_valid <= 1'b1;
            resp_res <= cop_res;
        end

        if (backend_resp_fire) begin
            resp_valid <= 1'b0;
        end
    end
end

endmodule
