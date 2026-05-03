module hcpu_ras
(
    input               clock,
    input               reset,

    input               push_en,
    input  [31:2]       push_data,

    input               pop_en,

    output              predict_valid,
    output [31:2]       predict_target
);

localparam DEPTH = 8;
localparam PTR_W  = 3;

reg  [29:0] stack [0:DEPTH-1];
reg  [PTR_W:0] wr_ptr;

assign predict_valid  = (wr_ptr != 0);
assign predict_target = stack[wr_ptr - 1];

integer i;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        wr_ptr <= 0;
        for (i = 0; i < DEPTH; i = i + 1)
            stack[i] <= 30'b0;
    end
    else begin
        if (push_en && pop_en) begin
            stack[wr_ptr - 1] <= push_data;
        end
        else if (push_en && !pop_en) begin
            if (wr_ptr < DEPTH) begin
                stack[wr_ptr] <= push_data;
                wr_ptr <= wr_ptr + 1;
            end
        end
        else if (!push_en && pop_en) begin
            if (wr_ptr > 0)
                wr_ptr <= wr_ptr - 1;
        end
    end
end

endmodule
