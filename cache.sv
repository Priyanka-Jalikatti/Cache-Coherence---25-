module Cache #(
    parameter CACHE_SIZE    = 8,
    parameter BLOCK_SIZE    = 4,
    parameter ADDRESS_WIDTH = 6,
    parameter DATA_WIDTH    = 32,
    parameter INDEX_WIDTH   = 3,
    parameter TAG_WIDTH     = ADDRESS_WIDTH - INDEX_WIDTH - $clog2(BLOCK_SIZE)
) (
    input  logic clk, reset,
    input  logic core_req_valid,
    input  logic core_req_type, // 0: Read, 1: Write
    input  logic [ADDRESS_WIDTH-1:0] core_req_addr,
    input  logic [DATA_WIDTH-1:0] core_req_data,
    input  logic bus_snoop_valid,
    input  logic [1:0] bus_snoop_type, // 01: BusRd, 10: BusRdX
    input  logic [ADDRESS_WIDTH-1:0] bus_snoop_addr,
    input  logic [DATA_WIDTH-1:0] bus_data_in,
    input  logic bus_data_in_valid_from_bus,

    output logic core_resp_valid,
    output logic [DATA_WIDTH-1:0] core_resp_data,
    output logic bus_req_valid,
    output logic [1:0] bus_req_type, // 01: BusRd, 10: BusRdX
    output logic [ADDRESS_WIDTH-1:0] bus_req_addr,
    output logic [DATA_WIDTH-1:0] bus_data_out,
    output logic snoop_resp_valid,
    output logic [DATA_WIDTH-1:0] snoop_resp_data,
    output logic snoop_resp_hit,
    output logic [1:0] snoop_resp_state
);

    // Internal storage
    reg [DATA_WIDTH-1:0] cache_data [CACHE_SIZE-1:0];
    reg [TAG_WIDTH-1:0]  cache_tag  [CACHE_SIZE-1:0];
    reg [1:0]            cache_state[CACHE_SIZE-1:0]; // 00=I, 01=S, 10=E, 11=M
    reg                  cache_valid[CACHE_SIZE-1:0];

    // Internal registers
    reg core_req_pending;
    reg core_req_type_r;
    reg [ADDRESS_WIDTH-1:0] core_req_addr_r;
    reg [DATA_WIDTH-1:0] core_req_data_r;
    reg [INDEX_WIDTH-1:0] core_index;
    reg [TAG_WIDTH-1:0] core_tag;

    reg bus_req_valid_r;
    reg [1:0] bus_req_type_r;
    reg [ADDRESS_WIDTH-1:0] bus_req_addr_r;

    reg core_resp_valid_r;
    reg [DATA_WIDTH-1:0] core_resp_data_r;

    reg snoop_resp_valid_r;
    reg [DATA_WIDTH-1:0] snoop_resp_data_r;
    reg snoop_resp_hit_r;
    reg [1:0] snoop_resp_state_r;

    // Address decoding
    function automatic [INDEX_WIDTH-1:0] get_index(input [ADDRESS_WIDTH-1:0] addr);
        get_index = addr[$clog2(BLOCK_SIZE) +: INDEX_WIDTH];
    endfunction

    function automatic [TAG_WIDTH-1:0] get_tag(input [ADDRESS_WIDTH-1:0] addr);
        get_tag = addr[$clog2(BLOCK_SIZE) + INDEX_WIDTH +: TAG_WIDTH];
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache_valid[i] <= 0;
                cache_state[i] <= 2'b00;
            end
            core_req_pending <= 0;
            core_resp_valid_r <= 0;
            bus_req_valid_r <= 0;
            snoop_resp_valid_r <= 0;
        end else begin
            core_resp_valid_r <= 0;
            bus_req_valid_r <= 0;
            snoop_resp_valid_r <= 0;

            // Core request
            if (core_req_valid && !core_req_pending) begin
                core_req_pending <= 1;
                core_req_type_r <= core_req_type;
                core_req_addr_r <= core_req_addr;
                core_req_data_r <= core_req_data;
                core_index <= get_index(core_req_addr);
                core_tag <= get_tag(core_req_addr);

                if (cache_valid[core_index] && cache_tag[core_index] == core_tag) begin
                    // Cache HIT
                    if (core_req_type == 1'b0) begin // READ
                        core_resp_valid_r <= 1;
                        core_resp_data_r <= cache_data[core_index];
                    end else begin // WRITE
                        cache_data[core_index] <= core_req_data;
                        cache_state[core_index] <= 2'b11; // Modified
                        core_resp_valid_r <= 1;
                    end
                    core_req_pending <= 0;
                end else begin
                    // Cache MISS
                    bus_req_valid_r <= 1;
                    bus_req_addr_r <= core_req_addr;
                    bus_req_type_r <= (core_req_type == 1'b0) ? 2'b01 : 2'b10;
                end
            end

            // Bus response
            if (bus_data_in_valid_from_bus && core_req_pending) begin
                cache_data[core_index] <= bus_data_in;
                cache_tag[core_index] <= core_tag;
                cache_valid[core_index] <= 1;
                cache_state[core_index] <= (core_req_type_r == 1'b0) ? 2'b10 : 2'b11;
                core_resp_valid_r <= 1;
                core_resp_data_r <= bus_data_in;
                core_req_pending <= 0;
            end

            // Snoop handling
            if (bus_snoop_valid) begin
                int snoop_index = get_index(bus_snoop_addr);
                int snoop_tag = get_tag(bus_snoop_addr);
                if (cache_valid[snoop_index] && cache_tag[snoop_index] == snoop_tag) begin
                    snoop_resp_hit_r <= 1;
                    snoop_resp_state_r <= cache_state[snoop_index];
                    snoop_resp_valid_r <= 1;
                    snoop_resp_data_r <= cache_data[snoop_index];

                    if (bus_snoop_type == 2'b01) begin // BusRd
                        if (cache_state[snoop_index] == 2'b11 || cache_state[snoop_index] == 2'b10)
                            cache_state[snoop_index] <= 2'b01; // Shared
                    end else if (bus_snoop_type == 2'b10) begin // BusRdX
                        cache_state[snoop_index] <= 2'b00; // Invalidate
                    end
                end else begin
                    snoop_resp_hit_r <= 0;
                    snoop_resp_state_r <= 2'b00;
                end
            end
        end
    end

    // Output assignments
    assign core_resp_valid  = core_resp_valid_r;
    assign core_resp_data   = core_resp_data_r;
    assign bus_req_valid    = bus_req_valid_r;
    assign bus_req_type     = bus_req_type_r;
    assign bus_req_addr     = bus_req_addr_r;
    assign bus_data_out     = core_req_data_r;
    assign snoop_resp_valid = snoop_resp_valid_r;
    assign snoop_resp_data  = snoop_resp_data_r;
    assign snoop_resp_hit   = snoop_resp_hit_r;
    assign snoop_resp_state = snoop_resp_state_r;

endmodule
