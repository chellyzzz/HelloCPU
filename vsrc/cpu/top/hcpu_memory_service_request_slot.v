module hcpu_memory_service_request_slot(
    input                               clock,
    input                               reset,
    input                               slot_load,
    input                               slot_req_store,
    input              [  31:0]         slot_req_addr,
    input              [  31:0]         slot_req_wdata,
    input              [   2:0]         slot_req_size,
    input                               slot_aw_fire,
    input                               slot_w_fire,
    output reg                          slot_store,
    output reg                          slot_aw_done,
    output reg                          slot_w_done,
    output reg         [  31:0]         slot_addr,
    output reg         [  31:0]         slot_wdata,
    output reg         [   2:0]         slot_size
);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        slot_store   <= 1'b0;
        slot_aw_done <= 1'b0;
        slot_w_done  <= 1'b0;
        slot_addr    <= 32'b0;
        slot_wdata   <= 32'b0;
        slot_size    <= 3'b0;
    end else begin
        if (slot_load) begin
            slot_store   <= slot_req_store;
            slot_aw_done <= 1'b0;
            slot_w_done  <= 1'b0;
            slot_addr    <= slot_req_addr;
            slot_wdata   <= slot_req_wdata;
            slot_size    <= slot_req_size;
        end else begin
            if (slot_aw_fire) begin
                slot_aw_done <= 1'b1;
            end
            if (slot_w_fire) begin
                slot_w_done <= 1'b1;
            end
        end
    end
end

endmodule
