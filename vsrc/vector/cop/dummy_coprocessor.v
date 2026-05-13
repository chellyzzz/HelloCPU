module hcpu_dummy_coprocessor(
    input               clock,
    input               reset,
    input               i_flush,
    input               i_valid,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [31:0]   i_ins,
    output     [31:0]   o_res,
    output reg          o_done,
    output reg          o_cop_mem_req_valid,
    output reg          o_cop_mem_req_store,
    output reg [31:0]   o_cop_mem_req_addr,
    output reg [31:0]   o_cop_mem_req_wdata,
    output     [2:0]    o_cop_mem_req_size,
    input               i_cop_mem_resp_valid,
    input      [31:0]   i_cop_mem_resp_rdata
);

reg         busy;
reg [1:0]   countdown;
reg [31:0]  latched_res;
reg [31:0]  scratch;
reg         pending_scratch_write;
reg [31:0]  pending_scratch_value;
reg [31:0]  vlen;
reg         pending_vlen_write;
reg [31:0]  pending_vlen_value;
reg [31:0]  op_count;
reg [31:0]  vrf [0:3];
reg         mem_active;
reg         mem_is_store;
reg [1:0]   mem_lane;
reg [31:0]  mem_base_addr;
reg [31:0]  mem_load_data;

assign o_res = latched_res;
assign o_cop_mem_req_size = 3'b000;

wire [2:0]  cop_funct3;
wire [6:0]  cop_funct7;
wire [3:0]  scalar_lane_op;
wire [3:0]  vrf_lane_op;
wire        is_vrf_op;
wire        is_vrf_lane;
wire        is_mem_load;
wire        is_mem_store;
wire        scratch_write;
wire        vlen_write;
wire [31:0] scalar_lane_result;
wire [31:0] vrf_op_result;

hcpu_vector_cop_decode u_cop_decode(
    .i_ins(i_ins),
    .o_funct3(cop_funct3),
    .o_funct7(cop_funct7),
    .o_scalar_lane_op(scalar_lane_op),
    .o_vrf_lane_op(vrf_lane_op),
    .o_is_vrf_op(is_vrf_op),
    .o_is_vrf_lane(is_vrf_lane),
    .o_is_mem_load(is_mem_load),
    .o_is_mem_store(is_mem_store),
    .o_scratch_write(scratch_write),
    .o_vlen_write(vlen_write)
);

hcpu_vector_lane_alu u_scalar_lane_alu(
    .i_lhs(i_src1),
    .i_rhs(i_src2),
    .i_op(scalar_lane_op),
    .o_res(scalar_lane_result)
);

hcpu_vector_lane_alu u_vrf_lane_alu(
    .i_lhs(vrf[0]),
    .i_rhs(vrf[1]),
    .i_op(vrf_lane_op),
    .o_res(vrf_op_result)
);

wire [31:0] scalar_op  = (cop_funct7 == 7'd1) ? (i_src1 - i_src2) :
                          (cop_funct7 == 7'd2) ? (i_src1 * i_src2) :
                          (i_src1 + i_src2);
wire [1:0]  vrf_idx   = i_src2[1:0];
wire        is_mem_op = is_mem_load || is_mem_store;
wire [31:0] cop_result = (cop_funct3 == 3'b001) ? scalar_lane_result :
                          (cop_funct3 == 3'b010) ? scalar_lane_result :
                          (cop_funct3 == 3'b011) ? scalar_lane_result :
                          (cop_funct3 == 3'b100) ? scratch :
                          (cop_funct3 == 3'b101) ? vlen :
                          (cop_funct3 == 3'b110) ? vlen :
                          (cop_funct3 == 3'b111) ? op_count :
                          is_vrf_lane ? vrf_op_result :
                          is_vrf_op  ? vrf[vrf_idx] :
                          scalar_op;
wire        vrf_write     = is_vrf_op && (cop_funct7 != 7'd4);
wire [1:0]  vrf_write_idx = is_vrf_lane ? 2'd0 : vrf_idx;
wire [31:0] vrf_write_value = is_vrf_lane ? vrf_op_result : i_src1;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        busy        <= 1'b0;
        countdown   <= 2'b0;
        latched_res <= 32'b0;
        scratch     <= 32'b0;
        pending_scratch_write <= 1'b0;
        pending_scratch_value <= 32'b0;
        vlen        <= 32'b0;
        pending_vlen_write    <= 1'b0;
        pending_vlen_value    <= 32'b0;
        op_count    <= 32'b0;
        vrf[0]      <= 32'b0;
        vrf[1]      <= 32'b0;
        vrf[2]      <= 32'b0;
        vrf[3]      <= 32'b0;
        mem_active  <= 1'b0;
        mem_is_store <= 1'b0;
        mem_lane    <= 2'b0;
        mem_base_addr <= 32'b0;
        mem_load_data <= 32'b0;
        o_cop_mem_req_valid <= 1'b0;
        o_cop_mem_req_store <= 1'b0;
        o_cop_mem_req_addr  <= 32'b0;
        o_cop_mem_req_wdata <= 32'b0;
        o_done      <= 1'b0;
    end else if (i_flush) begin
        busy        <= 1'b0;
        countdown   <= 2'b0;
        latched_res <= 32'b0;
        pending_scratch_write <= 1'b0;
        pending_scratch_value <= 32'b0;
        pending_vlen_write    <= 1'b0;
        pending_vlen_value    <= 32'b0;
        mem_active  <= 1'b0;
        mem_is_store <= 1'b0;
        mem_lane    <= 2'b0;
        mem_base_addr <= 32'b0;
        mem_load_data <= 32'b0;
        o_cop_mem_req_valid <= 1'b0;
        o_cop_mem_req_store <= 1'b0;
        o_cop_mem_req_addr  <= 32'b0;
        o_cop_mem_req_wdata <= 32'b0;
        o_done      <= 1'b0;
    end else begin
        o_done <= 1'b0;

        if (i_valid && !busy) begin
            busy        <= 1'b1;
            latched_res <= cop_result;
            pending_scratch_write <= scratch_write;
            pending_scratch_value <= i_src1;
            pending_vlen_write    <= vlen_write;
            pending_vlen_value    <= i_src1;
            if (is_mem_op) begin
                countdown    <= 2'b0;
                mem_active   <= 1'b1;
                mem_is_store <= is_mem_store;
                mem_lane     <= 2'b0;
                mem_base_addr <= i_src1;
                mem_load_data <= 32'b0;
                o_cop_mem_req_valid <= 1'b1;
                o_cop_mem_req_store <= is_mem_store;
                o_cop_mem_req_addr  <= i_src1;
                o_cop_mem_req_wdata <= {24'b0, vrf[0][7:0]};
            end else begin
                countdown   <= 2'd2;
            end
            if (vrf_write) begin
                vrf[vrf_write_idx] <= vrf_write_value;
            end
        end else if (busy && mem_active) begin
            if (i_cop_mem_resp_valid) begin
                if (!mem_is_store) begin
                    case (mem_lane)
                        2'd0: mem_load_data[7:0]   <= i_cop_mem_resp_rdata[7:0];
                        2'd1: mem_load_data[15:8]  <= i_cop_mem_resp_rdata[7:0];
                        2'd2: mem_load_data[23:16] <= i_cop_mem_resp_rdata[7:0];
                        2'd3: mem_load_data[31:24] <= i_cop_mem_resp_rdata[7:0];
                    endcase
                end

                if (mem_lane == 2'd3) begin
                    busy                  <= 1'b0;
                    mem_active            <= 1'b0;
                    o_cop_mem_req_valid   <= 1'b0;
                    o_cop_mem_req_store   <= 1'b0;
                    o_done                <= 1'b1;
                    op_count              <= op_count + 32'd1;
                    pending_scratch_write <= 1'b0;
                    pending_vlen_write    <= 1'b0;
                    if (mem_is_store) begin
                        latched_res <= vrf[0];
                    end else begin
                        vrf[0] <= {i_cop_mem_resp_rdata[7:0], mem_load_data[23:16], mem_load_data[15:8], mem_load_data[7:0]};
                        latched_res <= {i_cop_mem_resp_rdata[7:0], mem_load_data[23:16], mem_load_data[15:8], mem_load_data[7:0]};
                    end
                end else begin
                    mem_lane   <= mem_lane + 2'd1;
                    o_cop_mem_req_valid <= 1'b1;
                    o_cop_mem_req_addr  <= mem_base_addr + {30'b0, mem_lane + 2'd1};
                    o_cop_mem_req_wdata <= {24'b0,
                        (mem_lane == 2'd0) ? vrf[0][15:8] :
                        (mem_lane == 2'd1) ? vrf[0][23:16] :
                                             vrf[0][31:24]};
                    o_cop_mem_req_store <= mem_is_store;
                end
            end
        end else if (busy) begin
            if (countdown == 2'd1) begin
                busy                  <= 1'b0;
                countdown             <= 2'b0;
                o_done                <= 1'b1;
                op_count              <= op_count + 32'd1;
                pending_scratch_write <= 1'b0;
                pending_vlen_write    <= 1'b0;
                if (pending_scratch_write) begin
                    scratch <= pending_scratch_value;
                end
                if (pending_vlen_write) begin
                    vlen <= pending_vlen_value;
                end
            end else begin
                countdown <= countdown - 2'd1;
            end
        end
    end
end

endmodule
