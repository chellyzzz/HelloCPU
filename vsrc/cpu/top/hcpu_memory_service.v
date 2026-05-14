module hcpu_memory_service(
    input                               clock,
    input                               reset,
    input                               cop_kill,
    input                               scalar_mem_req_valid,
    input                               scalar_mem_req_store,
    input              [  31:0]         scalar_mem_req_addr,
    input              [  31:0]         scalar_mem_req_wdata,
    input              [   2:0]         scalar_mem_req_size,
    input                               scalar_mem_resp_valid,
    input              [  31:0]         scalar_mem_resp_rdata,
    input                               cop_mem_req_valid,
    input                               cop_mem_req_store,
    input              [  31:0]         cop_mem_req_addr,
    input              [  31:0]         cop_mem_req_wdata,
    input              [   2:0]         cop_mem_req_size,
    input              [  31:0]         lsu_rdata,
    input                               scalar_axi_awvalid,
    input              [  31:0]         scalar_axi_awaddr,
    input              [   3:0]         scalar_axi_awid,
    input              [   7:0]         scalar_axi_awlen,
    input              [   2:0]         scalar_axi_awsize,
    input              [   1:0]         scalar_axi_awburst,
    input                               scalar_axi_wvalid,
    input              [  31:0]         scalar_axi_wdata,
    input              [   3:0]         scalar_axi_wstrb,
    input                               scalar_axi_wlast,
    input                               scalar_axi_bready,
    input                               scalar_axi_arvalid,
    input              [  31:0]         scalar_axi_araddr,
    input              [   3:0]         scalar_axi_arid,
    input              [   7:0]         scalar_axi_arlen,
    input              [   2:0]         scalar_axi_arsize,
    input              [   1:0]         scalar_axi_arburst,
    input                               scalar_axi_rready,
    input                               mem_axi_awready,
    input                               mem_axi_wready,
    input                               mem_axi_bvalid,
    input                               mem_axi_arready,
    input                               mem_axi_rvalid,
    input                               mem_axi_rlast,
    output                              cop_mem_bus_active,
    output                              cop_mem_resp_active,
    output                              cop_mem_resp_valid,
    output             [  31:0]         cop_mem_resp_rdata,
    output                              mem_owner_scalar_active,
    output                              mem_owner_cop_active,
    output                              mem_service_req_valid,
    output                              mem_service_req_store,
    output             [  31:0]         mem_service_req_addr,
    output             [  31:0]         mem_service_req_wdata,
    output             [   2:0]         mem_service_req_size,
    output                              mem_service_resp_valid,
    output             [  31:0]         mem_service_resp_rdata,
    output reg         [   1:0]         cop_mem_state,
    output                              cop_mem_wen_r,
    output                              cop_mem_aw_done,
    output                              cop_mem_w_done,
    output reg                          cop_mem_killed_r,
    output reg                          cop_mem_done_r,
    output             [  31:0]         cop_mem_addr_r,
    output             [  31:0]         cop_mem_wdata_r,
    output             [   2:0]         cop_mem_size_r,
    output                              mem_axi_awvalid,
    output             [  31:0]         mem_axi_awaddr,
    output             [   3:0]         mem_axi_awid,
    output             [   7:0]         mem_axi_awlen,
    output             [   2:0]         mem_axi_awsize,
    output             [   1:0]         mem_axi_awburst,
    output                              mem_axi_wvalid,
    output             [  31:0]         mem_axi_wdata,
    output             [   3:0]         mem_axi_wstrb,
    output                              mem_axi_wlast,
    output                              mem_axi_bready,
    output                              mem_axi_arvalid,
    output             [  31:0]         mem_axi_araddr,
    output             [   3:0]         mem_axi_arid,
    output             [   7:0]         mem_axi_arlen,
    output             [   2:0]         mem_axi_arsize,
    output             [   1:0]         mem_axi_arburst,
    output                              mem_axi_rready,
    output                              cop_mem_aw_fire,
    output                              cop_mem_w_fire,
    output                              cop_mem_b_fire,
    output                              cop_mem_ar_fire,
    output                              cop_mem_r_fire
);

reg                    [  31:0]         cop_mem_rdata_r;
wire                                    cop_mem_new_req;
wire                                    cop_mem_slot_load;

assign cop_mem_bus_active = (cop_mem_state != 2'd0);
assign cop_mem_resp_active = cop_mem_bus_active || cop_mem_done_r;
assign cop_mem_resp_valid = cop_mem_done_r && !cop_mem_killed_r;
assign cop_mem_resp_rdata = cop_mem_rdata_r;
assign mem_owner_cop_active = cop_mem_bus_active;
assign mem_owner_scalar_active = !mem_owner_cop_active && scalar_mem_req_valid;
assign mem_service_req_valid = mem_owner_cop_active ? 1'b1 : scalar_mem_req_valid;
assign mem_service_req_store = mem_owner_cop_active ? cop_mem_wen_r : scalar_mem_req_store;
assign mem_service_req_addr = mem_owner_cop_active ? cop_mem_addr_r : scalar_mem_req_addr;
assign mem_service_req_wdata = mem_owner_cop_active ? cop_mem_wdata_r : scalar_mem_req_wdata;
assign mem_service_req_size = mem_owner_cop_active ? cop_mem_size_r : scalar_mem_req_size;
assign mem_service_resp_valid = cop_mem_resp_active ? cop_mem_resp_valid : scalar_mem_resp_valid;
assign mem_service_resp_rdata = cop_mem_resp_active ? cop_mem_resp_rdata : scalar_mem_resp_rdata;
assign cop_mem_new_req = cop_mem_req_valid && (cop_mem_state == 2'd0) && !cop_mem_done_r && !mem_owner_scalar_active;
assign cop_mem_slot_load = (cop_mem_state == 2'd0) && cop_mem_new_req;

hcpu_memory_service_request_slot u_memory_service_request_slot(
    .clock                             (clock                     ),
    .reset                             (reset                     ),
    .slot_load                         (cop_mem_slot_load         ),
    .slot_req_store                    (cop_mem_req_store         ),
    .slot_req_addr                     (cop_mem_req_addr          ),
    .slot_req_wdata                    (cop_mem_req_wdata         ),
    .slot_req_size                     (cop_mem_req_size          ),
    .slot_aw_fire                      (cop_mem_aw_fire           ),
    .slot_w_fire                       (cop_mem_w_fire            ),
    .slot_store                        (cop_mem_wen_r             ),
    .slot_aw_done                      (cop_mem_aw_done           ),
    .slot_w_done                       (cop_mem_w_done            ),
    .slot_addr                         (cop_mem_addr_r            ),
    .slot_wdata                        (cop_mem_wdata_r           ),
    .slot_size                         (cop_mem_size_r            )
);

hcpu_memory_service_axi_mux u_memory_service_axi_mux(
    .cop_mem_bus_active                (cop_mem_bus_active        ),
    .cop_mem_state                     (cop_mem_state             ),
    .cop_mem_wen_r                     (cop_mem_wen_r             ),
    .cop_mem_aw_done                   (cop_mem_aw_done           ),
    .cop_mem_w_done                    (cop_mem_w_done            ),
    .mem_service_req_addr              (mem_service_req_addr      ),
    .mem_service_req_wdata             (mem_service_req_wdata     ),
    .mem_service_req_size              (mem_service_req_size      ),
    .scalar_axi_awvalid                (scalar_axi_awvalid        ),
    .scalar_axi_awaddr                 (scalar_axi_awaddr         ),
    .scalar_axi_awid                   (scalar_axi_awid           ),
    .scalar_axi_awlen                  (scalar_axi_awlen          ),
    .scalar_axi_awsize                 (scalar_axi_awsize         ),
    .scalar_axi_awburst                (scalar_axi_awburst        ),
    .scalar_axi_wvalid                 (scalar_axi_wvalid         ),
    .scalar_axi_wdata                  (scalar_axi_wdata          ),
    .scalar_axi_wstrb                  (scalar_axi_wstrb          ),
    .scalar_axi_wlast                  (scalar_axi_wlast          ),
    .scalar_axi_bready                 (scalar_axi_bready         ),
    .scalar_axi_arvalid                (scalar_axi_arvalid        ),
    .scalar_axi_araddr                 (scalar_axi_araddr         ),
    .scalar_axi_arid                   (scalar_axi_arid           ),
    .scalar_axi_arlen                  (scalar_axi_arlen          ),
    .scalar_axi_arsize                 (scalar_axi_arsize         ),
    .scalar_axi_arburst                (scalar_axi_arburst        ),
    .scalar_axi_rready                 (scalar_axi_rready         ),
    .mem_axi_awready                   (mem_axi_awready           ),
    .mem_axi_wready                    (mem_axi_wready            ),
    .mem_axi_bvalid                    (mem_axi_bvalid            ),
    .mem_axi_arready                   (mem_axi_arready           ),
    .mem_axi_rvalid                    (mem_axi_rvalid            ),
    .mem_axi_rlast                     (mem_axi_rlast             ),
    .mem_axi_awvalid                   (mem_axi_awvalid           ),
    .mem_axi_awaddr                    (mem_axi_awaddr            ),
    .mem_axi_awid                      (mem_axi_awid              ),
    .mem_axi_awlen                     (mem_axi_awlen             ),
    .mem_axi_awsize                    (mem_axi_awsize            ),
    .mem_axi_awburst                   (mem_axi_awburst           ),
    .mem_axi_wvalid                    (mem_axi_wvalid            ),
    .mem_axi_wdata                     (mem_axi_wdata             ),
    .mem_axi_wstrb                     (mem_axi_wstrb             ),
    .mem_axi_wlast                     (mem_axi_wlast             ),
    .mem_axi_bready                    (mem_axi_bready            ),
    .mem_axi_arvalid                   (mem_axi_arvalid           ),
    .mem_axi_araddr                    (mem_axi_araddr            ),
    .mem_axi_arid                      (mem_axi_arid              ),
    .mem_axi_arlen                     (mem_axi_arlen             ),
    .mem_axi_arsize                    (mem_axi_arsize            ),
    .mem_axi_arburst                   (mem_axi_arburst           ),
    .mem_axi_rready                    (mem_axi_rready            ),
    .cop_mem_aw_fire                   (cop_mem_aw_fire           ),
    .cop_mem_w_fire                    (cop_mem_w_fire            ),
    .cop_mem_b_fire                    (cop_mem_b_fire            ),
    .cop_mem_ar_fire                   (cop_mem_ar_fire           ),
    .cop_mem_r_fire                    (cop_mem_r_fire            )
);

always @(posedge clock or posedge reset) begin
    if (reset) begin
        cop_mem_state    <= 2'd0;
        cop_mem_killed_r <= 1'b0;
        cop_mem_done_r   <= 1'b0;
        cop_mem_rdata_r  <= 32'b0;
    end else begin
        cop_mem_done_r <= 1'b0;
        if (cop_kill) begin
            if ((cop_mem_state == 2'd1) && !cop_mem_wen_r && !cop_mem_ar_fire) begin
                cop_mem_state <= 2'd0;
                cop_mem_killed_r <= 1'b0;
            end else if ((cop_mem_state == 2'd1) && cop_mem_wen_r &&
                         !(cop_mem_aw_done || cop_mem_aw_fire) && !(cop_mem_w_done || cop_mem_w_fire)) begin
                cop_mem_state <= 2'd0;
                cop_mem_killed_r <= 1'b0;
            end else if (cop_mem_state != 2'd0) begin
                cop_mem_killed_r <= 1'b1;
                if ((cop_mem_state == 2'd2) && (cop_mem_wen_r ? cop_mem_b_fire : cop_mem_r_fire)) begin
                    cop_mem_state <= 2'd0;
                    cop_mem_killed_r <= 1'b0;
                end
                if ((cop_mem_state == 2'd1) && !cop_mem_wen_r && cop_mem_ar_fire) begin
                    cop_mem_state <= 2'd2;
                end
                if ((cop_mem_state == 2'd1) && cop_mem_wen_r) begin
                    if ((cop_mem_aw_done || cop_mem_aw_fire) && (cop_mem_w_done || cop_mem_w_fire)) begin
                        cop_mem_state <= 2'd2;
                    end
                end
            end
        end else begin
            case (cop_mem_state)
                2'd0: begin
                    if (cop_mem_new_req) begin
                        cop_mem_state    <= 2'd1;
                        cop_mem_killed_r <= 1'b0;
                    end
                end
                2'd1: begin
                    if (cop_mem_wen_r) begin
                        if ((cop_mem_aw_done || cop_mem_aw_fire) && (cop_mem_w_done || cop_mem_w_fire)) begin
                            cop_mem_state <= 2'd2;
                        end
                    end else if (cop_mem_ar_fire) begin
                        cop_mem_state <= 2'd2;
                    end
                end
                2'd2: begin
                    if (cop_mem_wen_r ? cop_mem_b_fire : cop_mem_r_fire) begin
                        cop_mem_state <= cop_mem_killed_r ? 2'd0 : 2'd3;
                        cop_mem_rdata_r <= lsu_rdata;
                    end
                end
                2'd3: begin
                    cop_mem_state <= 2'd0;
                    cop_mem_done_r <= 1'b1;
                    cop_mem_killed_r <= 1'b0;
                end
                default: begin
                    cop_mem_state <= 2'd0;
                end
            endcase
        end
    end
end

endmodule
