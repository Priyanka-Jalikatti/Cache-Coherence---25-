module Core #(
    parameter ADDRESS_WIDTH = 6,
    parameter DATA_WIDTH    = 32
) (
    input  logic clk, reset,
    output logic req_valid,
    output logic req_type, // 0: Read, 1: Write
    output logic [ADDRESS_WIDTH-1:0] req_addr,
    output logic [DATA_WIDTH-1:0] req_data,
    input  logic cache_resp_valid,
    input  logic [DATA_WIDTH-1:0] cache_resp_data
);

    reg req_valid_r;
    reg req_type_r;
    reg [ADDRESS_WIDTH-1:0] req_addr_r;
    reg [DATA_WIDTH-1:0] req_data_r;
    reg [2:0] state;
    localparam IDLE = 3'b000, WAIT_RESP = 3'b001;
    reg [3:0] cycle_count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            req_valid_r <= 1'b0;
            state <= IDLE;
            cycle_count <= '0;
        end else begin
            case (state)
                IDLE: begin
                    cycle_count <= cycle_count + 1;
                    if (cycle_count == 5) begin
                        req_valid_r <= 1'b1;
                        req_type_r <= cycle_count[0];
                        req_addr_r <= {3'b000, cycle_count[2:0], 2'b00};
                        req_data_r <= cycle_count * 10;
                        state <= WAIT_RESP;
                    end else begin
                        req_valid_r <= 1'b0;
                    end
                end
                WAIT_RESP: begin
                    req_valid_r <= 1'b0;
                    if (cache_resp_valid) begin
                        state <= IDLE;
                        cycle_count <= '0;
                    end
                end
            endcase
        end
    end

    assign req_valid = req_valid_r;
    assign req_type  = req_type_r;
    assign req_addr  = req_addr_r;
    assign req_data  = req_data_r;

endmodule
