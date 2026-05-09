module hcpu_dummy_coprocessor(
    input               clock,
    input               reset,
    input               i_flush,
    input               i_valid,
    input      [31:0]   i_src1,
    input      [31:0]   i_src2,
    input      [31:0]   i_ins,
    output     [31:0]   o_res,
    output reg          o_done
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

assign o_res = latched_res;

wire [2:0]  cop_funct3 = i_ins[14:12];
wire [6:0]  cop_funct7 = i_ins[31:25];
wire [31:0] scalar_op  = (cop_funct7 == 7'd1) ? (i_src1 - i_src2) :
                          (cop_funct7 == 7'd2) ? (i_src1 * i_src2) :
                          (i_src1 + i_src2);
wire [31:0] lane_add8 = {
    i_src1[31:24] + i_src2[31:24],
    i_src1[23:16] + i_src2[23:16],
    i_src1[15:8]  + i_src2[15:8],
    i_src1[7:0]   + i_src2[7:0]
};
wire [31:0] lane_xor8 = i_src1 ^ i_src2;
wire [31:0] lane_and8 = i_src1 & i_src2;
wire [1:0]  vrf_idx   = i_src2[1:0];
wire [31:0] vrf_lane_add8 = {
    vrf[0][31:24] + vrf[1][31:24],
    vrf[0][23:16] + vrf[1][23:16],
    vrf[0][15:8]  + vrf[1][15:8],
    vrf[0][7:0]   + vrf[1][7:0]
};
wire [31:0] vrf_lane_sub8 = {
    vrf[0][31:24] - vrf[1][31:24],
    vrf[0][23:16] - vrf[1][23:16],
    vrf[0][15:8]  - vrf[1][15:8],
    vrf[0][7:0]   - vrf[1][7:0]
};
wire [31:0] vrf_lane_xor8 = vrf[0] ^ vrf[1];
wire [31:0] vrf_lane_and8 = vrf[0] & vrf[1];
wire [31:0] vrf_op_result = (cop_funct7 == 7'd5) ? vrf_lane_add8 :
                            (cop_funct7 == 7'd6) ? vrf_lane_xor8 :
                            (cop_funct7 == 7'd7) ? vrf_lane_and8 :
                            (cop_funct7 == 7'd8) ? vrf_lane_sub8 :
                            vrf_lane_add8;
wire        is_vrf_op  = (cop_funct3 == 3'b000) && (cop_funct7 >= 7'd3) && (cop_funct7 <= 7'd8);
wire        is_vrf_lane = (cop_funct3 == 3'b000) && (cop_funct7 >= 7'd5) && (cop_funct7 <= 7'd8);
wire [31:0] cop_result = (cop_funct3 == 3'b001) ? lane_add8 :
                          (cop_funct3 == 3'b010) ? lane_xor8 :
                          (cop_funct3 == 3'b011) ? lane_and8 :
                          (cop_funct3 == 3'b100) ? scratch :
                          (cop_funct3 == 3'b101) ? vlen :
                          (cop_funct3 == 3'b110) ? vlen :
                          (cop_funct3 == 3'b111) ? op_count :
                          is_vrf_lane ? vrf_op_result :
                          is_vrf_op  ? vrf[vrf_idx] :
                          scalar_op;
wire        scratch_write = (cop_funct3 == 3'b100);
wire        vlen_write    = (cop_funct3 == 3'b101);
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
        o_done      <= 1'b0;
    end else if (i_flush) begin
        busy        <= 1'b0;
        countdown   <= 2'b0;
        latched_res <= 32'b0;
        pending_scratch_write <= 1'b0;
        pending_scratch_value <= 32'b0;
        pending_vlen_write    <= 1'b0;
        pending_vlen_value    <= 32'b0;
        o_done      <= 1'b0;
    end else begin
        o_done <= 1'b0;

        if (i_valid && !busy) begin
            busy        <= 1'b1;
            countdown   <= 2'd2;
            latched_res <= cop_result;
            pending_scratch_write <= scratch_write;
            pending_scratch_value <= i_src1;
            pending_vlen_write    <= vlen_write;
            pending_vlen_value    <= i_src1;
            if (vrf_write) begin
                vrf[vrf_write_idx] <= vrf_write_value;
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
