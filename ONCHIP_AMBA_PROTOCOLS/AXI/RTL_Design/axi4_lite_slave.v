// Axi4_lite slave design using Verilog_HDL
// Author: Teja Reddy
module axi4_lite_slave #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter STRB_WIDTH = DATA_WIDTH/8, 
    parameter MEM_SIZE = 1024 
)( 
    input wire clk, 
    input wire reset_n, 
     
    // AXI4-Lite Slave Interface 
    // Write Address Channel 
    input wire [ADDR_WIDTH-1:0]   S_AXI_AWADDR, 
    input wire                    S_AXI_AWVALID, 
    output reg                    S_AXI_AWREADY, 
     
    // Write Data Channel 
    input wire [DATA_WIDTH-1:0]   S_AXI_WDATA, 
 
 
    input wire [STRB_WIDTH-1:0]   S_AXI_WSTRB, 
    input wire                    S_AXI_WVALID, 
    output reg                    S_AXI_WREADY, 
     
    // Write Response Channel 
    output reg [1:0]              S_AXI_BRESP, 
    output reg                    S_AXI_BVALID, 
    input wire                    S_AXI_BREADY, 
     
    // Read Address Channel 
    input wire [ADDR_WIDTH-1:0]   S_AXI_ARADDR, 
    input wire                    S_AXI_ARVALID, 
    output reg                    S_AXI_ARREADY, 
     
    // Read Data Channel 
    output reg [DATA_WIDTH-1:0]   S_AXI_RDATA, 
    output reg [1:0]              S_AXI_RRESP, 
    output reg                    S_AXI_RVALID, 
    input wire                    S_AXI_RREADY 
); 
 
    // Local Parameters 
    localparam MEM_DEPTH = MEM_SIZE / (DATA_WIDTH/8); 
    localparam ADDR_LSB = $clog2(DATA_WIDTH/8); 
     
    // Response Codes 
    localparam RESP_OKAY   = 2'b00; 
    localparam RESP_SLVERR = 2'b10; 
     
    // Memory Array 
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1]; 
     
    // Write FSM States 
    typedef enum logic [1:0] { 
        W_IDLE      = 2'b00, 
        W_ADDR_WAIT = 2'b01, 
        W_DATA_WAIT = 2'b10, 
        W_RESP      = 2'b11 
    } write_state_t; 
     
    // Read FSM States   
    typedef enum logic [1:0] { 
        R_IDLE      = 2'b00, 
        R_ADDR_WAIT = 2'b01, 
        R_DATA_SEND = 2'b10 
    } read_state_t; 
     
    write_state_t write_state, write_state_next; 
    read_state_t read_state, read_state_next; 
     
 
 
    // Internal Registers 
    reg [ADDR_WIDTH-1:0] write_addr_reg; 
    reg [DATA_WIDTH-1:0] write_data_reg; 
    reg [STRB_WIDTH-1:0] write_strb_reg; 
    reg [ADDR_WIDTH-1:0] read_addr_reg; 
     
    // Address Validation 
    function automatic logic addr_valid(input [ADDR_WIDTH-1:0] addr); 
        return (addr < MEM_SIZE); 
    endfunction 
     
    // Initialize Memory 
    initial begin 
        for (int i = 0; i < MEM_DEPTH; i++) begin 
            memory[i] = '0; 
        end 
    end 
     
    // Write FSM Sequential Logic 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            write_state <= W_IDLE; 
        end else begin 
            write_state <= write_state_next; 
        end 
    end 
     
    // Write FSM Combinational Logic 
    always_comb begin 
        write_state_next = write_state; 
        case (write_state) 
            W_IDLE: begin 
                if (S_AXI_AWVALID || S_AXI_WVALID) 
                    write_state_next = W_ADDR_WAIT; 
            end 
            W_ADDR_WAIT: begin 
                if (S_AXI_AWVALID && S_AXI_AWREADY && S_AXI_WVALID && S_AXI_WREADY) 
                    write_state_next = W_RESP; 
                else if (S_AXI_AWVALID && S_AXI_AWREADY) 
                    write_state_next = W_DATA_WAIT; 
            end 
            W_DATA_WAIT: begin 
                if (S_AXI_WVALID && S_AXI_WREADY) 
                    write_state_next = W_RESP; 
            end 
            W_RESP: begin 
                if (S_AXI_BVALID && S_AXI_BREADY) 
                    write_state_next = W_IDLE; 
            end 
        endcase 
 
 
    end 
     
    // Write Channel Control 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            S_AXI_AWREADY <= 1'b0; 
            S_AXI_WREADY  <= 1'b0; 
            S_AXI_BVALID  <= 1'b0; 
            S_AXI_BRESP   <= RESP_OKAY; 
            write_addr_reg <= '0; 
            write_data_reg <= '0; 
            write_strb_reg <= '0; 
        end else begin 
            case (write_state) 
                W_IDLE: begin 
                    S_AXI_AWREADY <= 1'b1; 
                    S_AXI_WREADY  <= 1'b1; 
                    S_AXI_BVALID  <= 1'b0; 
                end 
                W_ADDR_WAIT: begin 
                    // Capture address when handshake occurs 
                    if (S_AXI_AWVALID && S_AXI_AWREADY) begin 
                        write_addr_reg <= S_AXI_AWADDR; 
                        S_AXI_AWREADY <= 1'b0; 
                    end 
                     
                    // Capture data when handshake occurs 
                    if (S_AXI_WVALID && S_AXI_WREADY) begin 
                        write_data_reg <= S_AXI_WDATA; 
                        write_strb_reg <= S_AXI_WSTRB; 
                        S_AXI_WREADY <= 1'b0; 
                    end 
                end 
                W_DATA_WAIT: begin 
                    if (S_AXI_WVALID && S_AXI_WREADY) begin 
                        write_data_reg <= S_AXI_WDATA; 
                        write_strb_reg <= S_AXI_WSTRB; 
                        S_AXI_WREADY <= 1'b0; 
                    end 
                end 
                W_RESP: begin 
                    S_AXI_BVALID <= 1'b1; 
                     
                    // Determine response based on address validity 
                    if (addr_valid(write_addr_reg)) begin 
                        S_AXI_BRESP <= RESP_OKAY; 
                        // Perform actual write to memory 
                        write_to_memory(write_addr_reg, write_data_reg, write_strb_reg); 
                    end else begin 
                        S_AXI_BRESP <= RESP_SLVERR; 
 
 
                    end 
                     
                    if (S_AXI_BREADY) begin 
                        S_AXI_AWREADY <= 1'b1; 
                        S_AXI_WREADY  <= 1'b1; 
                    end 
                end 
            endcase 
        end 
    end 
     
    // Write to Memory Task 
    task automatic write_to_memory( 
        input [ADDR_WIDTH-1:0] addr, 
        input [DATA_WIDTH-1:0] data, 
        input [STRB_WIDTH-1:0] strb 
    ); 
        logic [ADDR_WIDTH-ADDR_LSB-1:0] mem_addr; 
        mem_addr = addr >> ADDR_LSB; 
         
        if (mem_addr < MEM_DEPTH) begin 
            for (int i = 0; i < STRB_WIDTH; i++) begin 
                if (strb[i]) begin 
                    memory[mem_addr][(i*8) +: 8] <= data[(i*8) +: 8]; 
                end 
            end 
        end 
    endtask 
     
    // Read FSM Sequential Logic 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            read_state <= R_IDLE; 
        end else begin 
            read_state <= read_state_next; 
        end 
    end 
     
    // Read FSM Combinational Logic 
    always_comb begin 
        read_state_next = read_state; 
        case (read_state) 
            R_IDLE: begin 
                if (S_AXI_ARVALID) 
                    read_state_next = R_ADDR_WAIT; 
            end 
            R_ADDR_WAIT: begin 
                if (S_AXI_ARVALID && S_AXI_ARREADY) 
                    read_state_next = R_DATA_SEND; 
            end 
 
 
            R_DATA_SEND: begin 
                if (S_AXI_RVALID && S_AXI_RREADY) 
                    read_state_next = R_IDLE; 
            end 
        endcase 
    end 
     
    // Read Channel Control 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            S_AXI_ARREADY <= 1'b0; 
            S_AXI_RDATA   <= '0; 
            S_AXI_RRESP   <= RESP_OKAY; 
            S_AXI_RVALID  <= 1'b0; 
            read_addr_reg <= '0; 
        end else begin 
            case (read_state) 
                R_IDLE: begin 
                    S_AXI_ARREADY <= 1'b1; 
                    S_AXI_RVALID  <= 1'b0; 
                end 
                R_ADDR_WAIT: begin 
                    if (S_AXI_ARVALID && S_AXI_ARREADY) begin 
                        read_addr_reg <= S_AXI_ARADDR; 
                        S_AXI_ARREADY <= 1'b0; 
                    end 
                end 
                R_DATA_SEND: begin 
                    S_AXI_RVALID <= 1'b1; 
                     
                    // Determine response and data based on address validity 
                    if (addr_valid(read_addr_reg)) begin 
                        S_AXI_RRESP <= RESP_OKAY; 
                        S_AXI_RDATA <= read_from_memory(read_addr_reg); 
                    end else begin 
                        S_AXI_RRESP <= RESP_SLVERR; 
                        S_AXI_RDATA <= '0; 
                    end 
                     
                    if (S_AXI_RREADY) begin 
                        S_AXI_ARREADY <= 1'b1; 
                    end 
                end 
            endcase 
        end 
    end 
     
    // Read from Memory Function 
    function automatic [DATA_WIDTH-1:0] read_from_memory(input [ADDR_WIDTH-1:0] addr); 
        logic [ADDR_WIDTH-ADDR_LSB-1:0] mem_addr; 
 
 
        mem_addr = addr >> ADDR_LSB; 
         
        if (mem_addr < MEM_DEPTH) begin 
            return memory[mem_addr]; 
        end else begin 
            return '0; 
        end 
    endfunction 
endmodule 


