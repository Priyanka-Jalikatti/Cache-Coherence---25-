module Bus #(
    parameter ADDRESS_WIDTH = 6,
    parameter DATA_WIDTH    = 32,
    parameter NUM_CORES     = 2
) (
    input  logic clk, reset,
    input  logic [NUM_CORES-1:0] cache_req_valid,
    input  logic [NUM_CORES-1:0] cache_req_type, // 1 bit per core: 0 = Read, 1 = Write
    input  logic [ADDRESS_WIDTH-1:0] cache_req_addr [NUM_CORES],
    input  logic [DATA_WIDTH-1:0] cache_data_out [NUM_CORES],
    input  logic mem_resp_valid,
    input  logic [DATA_WIDTH-1:0] mem_resp_data,

    output logic [NUM_CORES-1:0] cache_snoop_valid,
    output logic [NUM_CORES-1:0] cache_snoop_type,
    output logic [ADDRESS_WIDTH-1:0] cache_snoop_addr [NUM_CORES],
    output logic [DATA_WIDTH-1:0] bus_data_in_to_cache [NUM_CORES],
    output logic [NUM_CORES-1:0] bus_data_in_valid_to_cache,
    input  logic [NUM_CORES-1:0] snoop_resp_valid_from_cache,
    input  logic [DATA_WIDTH-1:0] snoop_resp_data_from_cache [NUM_CORES],
    input  logic [NUM_CORES-1:0] snoop_resp_hit_from_cache,
    input  logic [NUM_CORES-1:0] snoop_resp_state_from_cache,
    output logic mem_req_valid,
    output logic mem_req_write,
    output logic [ADDRESS_WIDTH-1:0] mem_req_addr,
    output logic [DATA_WIDTH-1:0] mem_req_data
);

    reg [NUM_CORES-1:0] arb_grant;
    reg [NUM_CORES-1:0] snoop_valid;
    reg [NUM_CORES-1:0] snoop_type;
    reg [ADDRESS_WIDTH-1:0] snoop_addr [NUM_CORES];
    reg [DATA_WIDTH-1:0] bus_data_r;
    reg bus_data_valid;
    reg [NUM_CORES-1:0] bus_data_in_valid_to_cache_r;

    reg mem_req_valid_r;
    reg mem_req_write_r;
    reg [ADDRESS_WIDTH-1:0] mem_req_addr_r;
    reg [DATA_WIDTH-1:0] mem_req_data_r;

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < NUM_CORES; i++) begin
                arb_grant[i] <= 0;
                snoop_valid[i] <= 0;
            end
            bus_data_valid <= 0;
            mem_req_valid_r <= 0;
            bus_data_in_valid_to_cache_r <= '0;
        end else begin
            mem_req_valid_r <= 0;
            bus_data_in_valid_to_cache_r <= '0;

            // Arbitration (priority: Core 0 > Core 1)
            arb_grant <= '0;
            if (cache_req_valid[0]) arb_grant[0] <= 1;
            else if (cache_req_valid[1]) arb_grant[1] <= 1;

            // Broadcast snoop to all caches
            snoop_valid <= cache_req_valid;
            for (i = 0; i < NUM_CORES; i++) begin
                snoop_addr[i] <= cache_req_addr[i];
            end
            snoop_type <= cache_req_type;

            bus_data_valid <= 0;

            // Grant handling for Core 0
            if (arb_grant[0]) begin
                if (cache_req_type[0] == 1'b0) begin // Read
                    if (snoop_resp_hit_from_cache[1]) begin
                        bus_data_r <= snoop_resp_data_from_cache[1];
                        bus_data_valid <= 1;
                        bus_data_in_valid_to_cache_r[0] <= 1;
                    end else begin
                        mem_req_valid_r <= 1;
                        mem_req_write_r <= 0;
                        mem_req_addr_r <= cache_req_addr[0];
                    end
                end else begin // Write
                    bus_data_r <= cache_data_out[0];
                    bus_data_valid <= 1;
                    bus_data_in_valid_to_cache_r[0] <= 1;
                    mem_req_valid_r <= 1;
                    mem_req_write_r <= 1;
                    mem_req_addr_r <= cache_req_addr[0];
                    mem_req_data_r <= cache_data_out[0];
                end
            end

            // Grant handling for Core 1
            else if (arb_grant[1]) begin
                if (cache_req_type[1] == 1'b0) begin // Read
                    if (snoop_resp_hit_from_cache[0]) begin
                        bus_data_r <= snoop_resp_data_from_cache[0];
                        bus_data_valid <= 1;
                        bus_data_in_valid_to_cache_r[1] <= 1;
                    end else begin
                        mem_req_valid_r <= 1;
                        mem_req_write_r <= 0;
                        mem_req_addr_r <= cache_req_addr[1];
                    end
                end else begin // Write
                    bus_data_r <= cache_data_out[1];
                    bus_data_valid <= 1;
                    bus_data_in_valid_to_cache_r[1] <= 1;
                    mem_req_valid_r <= 1;
                    mem_req_write_r <= 1;
                    mem_req_addr_r <= cache_req_addr[1];
                    mem_req_data_r <= cache_data_out[1];
                end
            end

            // Memory response broadcasting
            if (mem_resp_valid) begin
                bus_data_r <= mem_resp_data;
                bus_data_valid <= 1;
                for (i = 0; i < NUM_CORES; i++) begin
                    bus_data_in_valid_to_cache_r[i] <= 1;
                end
            end
        end
    end

    // Output assignments
    genvar gi;
    generate
        for (gi = 0; gi < NUM_CORES; gi++) begin
            assign cache_snoop_type[gi]            = snoop_type[gi];
            assign cache_snoop_addr[gi]            = snoop_addr[gi];
            assign bus_data_in_to_cache[gi]        = bus_data_r;
            assign bus_data_in_valid_to_cache[gi]  = bus_data_in_valid_to_cache_r[gi];
        end
    endgenerate

    assign cache_snoop_valid = snoop_valid;
    assign mem_req_valid     = mem_req_valid_r;
    assign mem_req_write     = mem_req_write_r;
    assign mem_req_addr      = mem_req_addr_r;
    assign mem_req_data      = mem_req_data_r;

endmodule
