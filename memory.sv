module Memory #(
    parameter ADDRESS_WIDTH = 6,
    parameter DATA_WIDTH    = 32,
    parameter MEMORY_SIZE   = 1 << ADDRESS_WIDTH
) (
    input  logic clk,
    input  logic reset,
    input  logic mem_req_valid,
    input  logic [ADDRESS_WIDTH-1:0] mem_req_addr,
    input  logic mem_req_write,
    input  logic [DATA_WIDTH-1:0] mem_req_data,
    output logic mem_resp_valid,
    output logic [DATA_WIDTH-1:0] mem_resp_data
);

    // Actual memory
    reg [DATA_WIDTH-1:0] memory [0:MEMORY_SIZE-1];

    // Response registers
    reg [DATA_WIDTH-1:0] mem_resp_data_r;
    reg mem_resp_valid_r;

    // Simulated read delay
    reg [3:0] delay_count;
    localparam DELAY_CYCLES = 4;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_resp_valid_r <= 0;
            delay_count <= 0;

            // Optional: initialize memory with data
            for (int i = 0; i < MEMORY_SIZE; i++)
                memory[i] <= i * 10;
        end else begin
            mem_resp_valid_r <= 0;

            if (mem_req_valid) begin
                if (mem_req_write) begin
                    // Perform write immediately
                    memory[mem_req_addr] <= mem_req_data;
                end else begin
                    // Simulate read delay
                    if (delay_count == DELAY_CYCLES - 1) begin
                        mem_resp_data_r <= memory[mem_req_addr];
                        mem_resp_valid_r <= 1;
                        delay_count <= 0;
                    end else begin
                        delay_count <= delay_count + 1;
                    end
                end
            end else begin
                delay_count <= 0;
            end
        end
    end

    // Outputs
    assign mem_resp_data  = mem_resp_data_r;
    assign mem_resp_valid = mem_resp_valid_r;

endmodule
