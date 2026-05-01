module ysyx_23060124_stdrst(
  input clock,
  input i_rst_n,
  output o_rst_n_sync
);
  reg [10:0] shift_reg;
  always @(posedge clock or posedge i_rst_n) begin
    if (i_rst_n) begin
      shift_reg <= 11'b0;
    end else begin
      shift_reg <= {shift_reg[9:0], 1'b1};
    end
  end

  assign o_rst_n_sync = shift_reg[10];

endmodule
