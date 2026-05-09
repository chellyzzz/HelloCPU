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
wire [31:0] cop_result = (cop_funct3 == 3'b001) ? lane_add8 :
                          (cop_funct3 == 3'b010) ? lane_xor8 :
                          (cop_funct3 == 3'b011) ? lane_and8 :
                          (cop_funct3 == 3'b100) ? scratch :
                          (cop_funct3 == 3'b101) ? vlen :
                          (cop_funct3 == 3'b110) ? vlen :
                          (cop_funct3 == 3'b111) ? op_count :
                          scalar_op;
wire        scratch_write = (cop_funct3 == 3'b100);
wire        vlen_write    = (cop_funct3 == 3'b101);

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
