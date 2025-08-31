// Complete AXI4-Lite System Implementation in Verilog 2001 - FIXED VERSION
// Includes Master, Slave, Top Module, and Testbench

//============================================================================
// AXI4-Lite Master Module
// Author: Teja Reddy
//============================================================================
module axi4_lite_master #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter STRB_WIDTH = DATA_WIDTH/8 
)( 
    input wire clk, 
    input wire reset_n, 
     
    // User Interface 
    input wire                    write_req, 
    input wire [ADDR_WIDTH-1:0]   write_addr, 
    input wire [DATA_WIDTH-1:0]   write_data, 
    input wire [STRB_WIDTH-1:0]   write_strb, 
    output reg                    write_done, 
    output reg [1:0]              write_resp, 
     
    input wire                    read_req, 
    input wire [ADDR_WIDTH-1:0]   read_addr, 
    output reg [DATA_WIDTH-1:0]   read_data, 
    output reg                    read_done, 
    output reg [1:0]              read_resp, 
     
    // AXI4-Lite Interface 
    output reg [ADDR_WIDTH-1:0]   M_AXI_AWADDR, 
    output reg                    M_AXI_AWVALID, 
    input wire                    M_AXI_AWREADY, 
    output reg [DATA_WIDTH-1:0]   M_AXI_WDATA, 
    output reg [STRB_WIDTH-1:0]   M_AXI_WSTRB, 
    output reg                    M_AXI_WVALID, 
    input wire                    M_AXI_WREADY, 
    input wire [1:0]              M_AXI_BRESP, 
    input wire                    M_AXI_BVALID, 
    output reg                    M_AXI_BREADY, 
    output reg [ADDR_WIDTH-1:0]   M_AXI_ARADDR, 
    output reg                    M_AXI_ARVALID, 
    input wire                    M_AXI_ARREADY, 
    input wire [DATA_WIDTH-1:0]   M_AXI_RDATA, 
    input wire [1:0]              M_AXI_RRESP, 
    input wire                    M_AXI_RVALID, 
    output reg                    M_AXI_RREADY 
); 

    // Write FSM States
    parameter WRITE_IDLE = 2'b00;
    parameter WRITE_ADDR = 2'b01;
    parameter WRITE_DATA = 2'b10;
    parameter WRITE_RESP = 2'b11;
    
    // Read FSM States
    parameter READ_IDLE = 2'b00;
    parameter READ_ADDR = 2'b01;
    parameter READ_DATA = 2'b10;
    
    reg [1:0] write_state, write_state_next;
    reg [1:0] read_state, read_state_next;
    
    // Write FSM Sequential Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_state <= WRITE_IDLE;
        end else begin
            write_state <= write_state_next;
        end
    end
    
    // Write FSM Combinational Logic
    always @(*) begin
        write_state_next = write_state;
        case (write_state)
            WRITE_IDLE: begin
                if (write_req)
                    write_state_next = WRITE_ADDR;
            end
            WRITE_ADDR: begin
                if (M_AXI_AWVALID && M_AXI_AWREADY)
                    write_state_next = WRITE_DATA;
            end
            WRITE_DATA: begin
                if (M_AXI_WVALID && M_AXI_WREADY)
                    write_state_next = WRITE_RESP;
            end
            WRITE_RESP: begin
                if (M_AXI_BVALID && M_AXI_BREADY)
                    write_state_next = WRITE_IDLE;
            end
            default: write_state_next = WRITE_IDLE;
        endcase
    end
    
    // Write Channel Outputs
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            M_AXI_AWADDR  <= {ADDR_WIDTH{1'b0}};
            M_AXI_AWVALID <= 1'b0;
            M_AXI_WDATA   <= {DATA_WIDTH{1'b0}};
            M_AXI_WSTRB   <= {STRB_WIDTH{1'b0}};
            M_AXI_WVALID  <= 1'b0;
            M_AXI_BREADY  <= 1'b0;
            write_done    <= 1'b0;
            write_resp    <= 2'b00;
        end else begin
            case (write_state)
                WRITE_IDLE: begin
                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b0;
                    M_AXI_BREADY  <= 1'b0;
                    write_done    <= 1'b0;
                    
                    if (write_req) begin
                        M_AXI_AWADDR <= write_addr;
                        M_AXI_WDATA  <= write_data;
                        M_AXI_WSTRB  <= write_strb;
                    end
                end
                WRITE_ADDR: begin
                    M_AXI_AWVALID <= 1'b1;
                end
                WRITE_DATA: begin
                    M_AXI_AWVALID <= 1'b0;
                    M_AXI_WVALID  <= 1'b1;
                end
                WRITE_RESP: begin
                    M_AXI_WVALID <= 1'b0;
                    M_AXI_BREADY <= 1'b1;
                    
                    if (M_AXI_BVALID) begin
                        write_resp <= M_AXI_BRESP;
                        write_done <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    // Read FSM Sequential Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            read_state <= READ_IDLE;
        end else begin
            read_state <= read_state_next;
        end
    end
    
    // Read FSM Combinational Logic
    always @(*) begin
        read_state_next = read_state;
        case (read_state)
            READ_IDLE: begin
                if (read_req)
                    read_state_next = READ_ADDR;
            end
            READ_ADDR: begin
                if (M_AXI_ARVALID && M_AXI_ARREADY)
                    read_state_next = READ_DATA;
            end
            READ_DATA: begin
                if (M_AXI_RVALID && M_AXI_RREADY)
                    read_state_next = READ_IDLE;
            end
            default: read_state_next = READ_IDLE;
        endcase
    end
    
    // Read Channel Outputs
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            M_AXI_ARADDR  <= {ADDR_WIDTH{1'b0}};
            M_AXI_ARVALID <= 1'b0;
            M_AXI_RREADY  <= 1'b0;
            read_data     <= {DATA_WIDTH{1'b0}};
            read_done     <= 1'b0;
            read_resp     <= 2'b00;
        end else begin
            case (read_state)
                READ_IDLE: begin
                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b0;
                    read_done     <= 1'b0;
                    
                    if (read_req) begin
                        M_AXI_ARADDR <= read_addr;
                    end
                end
                READ_ADDR: begin
                    M_AXI_ARVALID <= 1'b1;
                end
                READ_DATA: begin
                    M_AXI_ARVALID <= 1'b0;
                    M_AXI_RREADY  <= 1'b1;
                    
                    if (M_AXI_RVALID) begin
                        read_data <= M_AXI_RDATA;
                        read_resp <= M_AXI_RRESP;
                        read_done <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule

//============================================================================
// AXI4-Lite Slave Module - FIXED VERSION
//============================================================================
module axi4_lite_slave #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter STRB_WIDTH = DATA_WIDTH/8, 
    parameter MEM_SIZE = 1024 
)( 
    input wire clk, 
    input wire reset_n, 
     
    // AXI4-Lite Slave Interface 
    input wire [ADDR_WIDTH-1:0]   S_AXI_AWADDR, 
    input wire                    S_AXI_AWVALID, 
    output reg                    S_AXI_AWREADY, 
    input wire [DATA_WIDTH-1:0]   S_AXI_WDATA, 
    input wire [STRB_WIDTH-1:0]   S_AXI_WSTRB, 
    input wire                    S_AXI_WVALID, 
    output reg                    S_AXI_WREADY, 
    output reg [1:0]              S_AXI_BRESP, 
    output reg                    S_AXI_BVALID, 
    input wire                    S_AXI_BREADY, 
    input wire [ADDR_WIDTH-1:0]   S_AXI_ARADDR, 
    input wire                    S_AXI_ARVALID, 
    output reg                    S_AXI_ARREADY, 
    output reg [DATA_WIDTH-1:0]   S_AXI_RDATA, 
    output reg [1:0]              S_AXI_RRESP, 
    output reg                    S_AXI_RVALID, 
    input wire                    S_AXI_RREADY 
); 

    // Local Parameters
    localparam MEM_DEPTH = MEM_SIZE / (DATA_WIDTH/8);
    localparam ADDR_LSB = 2; // For 32-bit data (4 bytes)
    
    // Response Codes
    localparam RESP_OKAY   = 2'b00;
    localparam RESP_SLVERR = 2'b10;
    
    // Write FSM States - FIXED
    parameter W_IDLE = 3'b000;
    parameter W_ADDR = 3'b001;
    parameter W_DATA = 3'b010;
    parameter W_BOTH = 3'b011;
    parameter W_RESP = 3'b100;
    
    // Read FSM States
    parameter R_IDLE = 2'b00;
    parameter R_ADDR = 2'b01;
    parameter R_DATA = 2'b10;
    
    // Memory Array
    reg [DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
    
    reg [2:0] write_state, write_state_next;
    reg [1:0] read_state, read_state_next;
    
    // Internal Registers
    reg [ADDR_WIDTH-1:0] write_addr_reg;
    reg [DATA_WIDTH-1:0] write_data_reg;
    reg [STRB_WIDTH-1:0] write_strb_reg;
    reg [ADDR_WIDTH-1:0] read_addr_reg;
    
    // Control flags
    reg addr_received;
    reg data_received;
    
    // Initialize Memory
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            memory[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Write FSM Sequential Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_state <= W_IDLE;
            addr_received <= 1'b0;
            data_received <= 1'b0;
            write_addr_reg <= {ADDR_WIDTH{1'b0}};
            write_data_reg <= {DATA_WIDTH{1'b0}};
            write_strb_reg <= {STRB_WIDTH{1'b0}};
        end else begin
            write_state <= write_state_next;
            
            // Capture address when handshake occurs
            if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                write_addr_reg <= S_AXI_AWADDR;
                addr_received <= 1'b1;
            end
            
            // Capture data when handshake occurs
            if (S_AXI_WVALID && S_AXI_WREADY) begin
                write_data_reg <= S_AXI_WDATA;
                write_strb_reg <= S_AXI_WSTRB;
                data_received <= 1'b1;
            end
            
            // Clear flags when returning to idle
            if (write_state == W_RESP && S_AXI_BVALID && S_AXI_BREADY) begin
                addr_received <= 1'b0;
                data_received <= 1'b0;
            end
        end
    end
    
    // Write FSM Combinational Logic - FIXED
    always @(*) begin
        write_state_next = write_state;
        case (write_state)
            W_IDLE: begin
                if (S_AXI_AWVALID && S_AXI_WVALID) begin
                    write_state_next = W_BOTH;
                end else if (S_AXI_AWVALID) begin
                    write_state_next = W_ADDR;
                end else if (S_AXI_WVALID) begin
                    write_state_next = W_DATA;
                end
            end
            W_ADDR: begin
                if (S_AXI_WVALID && S_AXI_WREADY) begin
                    write_state_next = W_RESP;
                end
            end
            W_DATA: begin
                if (S_AXI_AWVALID && S_AXI_AWREADY) begin
                    write_state_next = W_RESP;
                end
            end
            W_BOTH: begin
                if (S_AXI_AWREADY && S_AXI_WREADY) begin
                    write_state_next = W_RESP;
                end
            end
            W_RESP: begin
                if (S_AXI_BVALID && S_AXI_BREADY) begin
                    write_state_next = W_IDLE;
                end
            end
            default: write_state_next = W_IDLE;
        endcase
    end
    
    // Write Channel Control - FIXED
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= RESP_OKAY;
        end else begin
            case (write_state)
                W_IDLE: begin
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY  <= 1'b1;
                    S_AXI_BVALID  <= 1'b0;
                end
                W_ADDR: begin
                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b1;
                end
                W_DATA: begin
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY  <= 1'b0;
                end
                W_BOTH: begin
                    S_AXI_AWREADY <= 1'b1;
                    S_AXI_WREADY  <= 1'b1;
                end
                W_RESP: begin
                    S_AXI_AWREADY <= 1'b0;
                    S_AXI_WREADY  <= 1'b0;
                    S_AXI_BVALID  <= 1'b1;
                    
                    // Perform write operation when both addr and data are ready
                    if (!S_AXI_BVALID || (addr_received && data_received)) begin
                        if (write_addr_reg < MEM_SIZE) begin
                            S_AXI_BRESP <= RESP_OKAY;
                            // Perform actual write to memory
                            write_to_memory(write_addr_reg, write_data_reg, write_strb_reg);
                        end else begin
                            S_AXI_BRESP <= RESP_SLVERR;
                        end
                    end
                end
            endcase
        end
    end
    
    // Write to Memory Task - FIXED
    task write_to_memory;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [STRB_WIDTH-1:0] strb;
        
        reg [ADDR_WIDTH-ADDR_LSB-1:0] mem_addr;
        integer j;
        begin
            mem_addr = addr >> ADDR_LSB;
            
            if (mem_addr < MEM_DEPTH) begin
                for (j = 0; j < STRB_WIDTH; j = j + 1) begin
                    if (strb[j]) begin
                        memory[mem_addr][(j*8) +: 8] <= data[(j*8) +: 8];
                    end
                end
            end
        end
    endtask
    
    // Read FSM Sequential Logic
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            read_state <= R_IDLE;
            read_addr_reg <= {ADDR_WIDTH{1'b0}};
        end else begin
            read_state <= read_state_next;
            
            // Capture read address
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                read_addr_reg <= S_AXI_ARADDR;
            end
        end
    end
    
    // Read FSM Combinational Logic
    always @(*) begin
        read_state_next = read_state;
        case (read_state)
            R_IDLE: begin
                if (S_AXI_ARVALID)
                    read_state_next = R_ADDR;
            end
            R_ADDR: begin
                if (S_AXI_ARVALID && S_AXI_ARREADY)
                    read_state_next = R_DATA;
            end
            R_DATA: begin
                if (S_AXI_RVALID && S_AXI_RREADY)
                    read_state_next = R_IDLE;
            end
            default: read_state_next = R_IDLE;
        endcase
    end
    
    // Read Channel Control - FIXED
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RDATA   <= {DATA_WIDTH{1'b0}};
            S_AXI_RRESP   <= RESP_OKAY;
            S_AXI_RVALID  <= 1'b0;
        end else begin
            case (read_state)
                R_IDLE: begin
                    S_AXI_ARREADY <= 1'b1;
                    S_AXI_RVALID  <= 1'b0;
                end
                R_ADDR: begin
                    S_AXI_ARREADY <= 1'b0;
                end
                R_DATA: begin
                    S_AXI_ARREADY <= 1'b0;
                    S_AXI_RVALID  <= 1'b1;
                    
                    // Generate response and data
                    if (read_addr_reg < MEM_SIZE) begin
                        S_AXI_RRESP <= RESP_OKAY;
                        S_AXI_RDATA <= read_from_memory(read_addr_reg);
                    end else begin
                        S_AXI_RRESP <= RESP_SLVERR;
                        S_AXI_RDATA <= {DATA_WIDTH{1'b0}};
                    end
                    
                    if (S_AXI_RREADY) begin
                        S_AXI_ARREADY <= 1'b1;
                    end
                end
            endcase
        end
    end
    
    // Read from Memory Function
    function [DATA_WIDTH-1:0] read_from_memory;
        input [ADDR_WIDTH-1:0] addr;
        
        reg [ADDR_WIDTH-ADDR_LSB-1:0] mem_addr;
        begin
            mem_addr = addr >> ADDR_LSB;
            
            if (mem_addr < MEM_DEPTH) begin
                read_from_memory = memory[mem_addr];
            end else begin
                read_from_memory = {DATA_WIDTH{1'b0}};
            end
        end
    endfunction
endmodule

//============================================================================
// AXI4-Lite System Top Module
//============================================================================
module axi4_lite_system_top #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter STRB_WIDTH = DATA_WIDTH/8 
)( 
    input wire clk, 
    input wire reset_n, 
     
    // User Interface for Testing 
    input wire                    write_req, 
    input wire [ADDR_WIDTH-1:0]   write_addr, 
    input wire [DATA_WIDTH-1:0]   write_data, 
    input wire [STRB_WIDTH-1:0]   write_strb, 
    output wire                   write_done, 
    output wire [1:0]             write_resp, 
     
    input wire                    read_req, 
    input wire [ADDR_WIDTH-1:0]   read_addr, 
    output wire [DATA_WIDTH-1:0]  read_data, 
    output wire                   read_done, 
    output wire [1:0]             read_resp 
); 

    // AXI4-Lite Interconnect Signals
    wire [ADDR_WIDTH-1:0] axi_awaddr;
    wire                  axi_awvalid;
    wire                  axi_awready;
    wire [DATA_WIDTH-1:0] axi_wdata;
    wire [STRB_WIDTH-1:0] axi_wstrb;
    wire                  axi_wvalid;
    wire                  axi_wready;
    wire [1:0]            axi_bresp;
    wire                  axi_bvalid;
    wire                  axi_bready;
    wire [ADDR_WIDTH-1:0] axi_araddr;
    wire                  axi_arvalid;
    wire                  axi_arready;
    wire [DATA_WIDTH-1:0] axi_rdata;
    wire [1:0]            axi_rresp;
    wire                  axi_rvalid;
    wire                  axi_rready;
    
    // AXI4-Lite Master Instance
    axi4_lite_master #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) master_inst (
        .clk(clk),
        .reset_n(reset_n),
        
        // User Interface
        .write_req(write_req),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_strb(write_strb),
        .write_done(write_done),
        .write_resp(write_resp),
        
        .read_req(read_req),
        .read_addr(read_addr),
        .read_data(read_data),
        .read_done(read_done),
        .read_resp(read_resp),
        
        // AXI4-Lite Interface
        .M_AXI_AWADDR(axi_awaddr),
        .M_AXI_AWVALID(axi_awvalid),
        .M_AXI_AWREADY(axi_awready),
        .M_AXI_WDATA(axi_wdata),
        .M_AXI_WSTRB(axi_wstrb),
        .M_AXI_WVALID(axi_wvalid),
        .M_AXI_WREADY(axi_wready),
        .M_AXI_BRESP(axi_bresp),
        .M_AXI_BVALID(axi_bvalid),
        .M_AXI_BREADY(axi_bready),
        .M_AXI_ARADDR(axi_araddr),
        .M_AXI_ARVALID(axi_arvalid),
        .M_AXI_ARREADY(axi_arready),
        .M_AXI_RDATA(axi_rdata),
        .M_AXI_RRESP(axi_rresp),
        .M_AXI_RVALID(axi_rvalid),
        .M_AXI_RREADY(axi_rready)
    );
    
    // AXI4-Lite Slave Instance
    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH),
        .MEM_SIZE(1024)
    ) slave_inst (
        .clk(clk),
        .reset_n(reset_n),
        
        // AXI4-Lite Interface
        .S_AXI_AWADDR(axi_awaddr),
        .S_AXI_AWVALID(axi_awvalid),
        .S_AXI_AWREADY(axi_awready),
        .S_AXI_WDATA(axi_wdata),
        .S_AXI_WSTRB(axi_wstrb),
        .S_AXI_WVALID(axi_wvalid),
        .S_AXI_WREADY(axi_wready),
        .S_AXI_BRESP(axi_bresp),
        .S_AXI_BVALID(axi_bvalid),
        .S_AXI_BREADY(axi_bready),
        .S_AXI_ARADDR(axi_araddr),
        .S_AXI_ARVALID(axi_arvalid),
        .S_AXI_ARREADY(axi_arready),
        .S_AXI_RDATA(axi_rdata),
        .S_AXI_RRESP(axi_rresp),
        .S_AXI_RVALID(axi_rvalid),
        .S_AXI_RREADY(axi_rready)
    );
endmodule

//============================================================================
// AXI4-Lite Testbench - ENHANCED
//============================================================================
module axi4_lite_tb; 

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter STRB_WIDTH = DATA_WIDTH/8;
    parameter CLK_PERIOD = 10; // 100MHz clock
    
    // Clock and Reset
    reg clk = 0;
    reg reset_n = 0;
    
    // Test Interface Signals
    reg                    write_req;
    reg [ADDR_WIDTH-1:0]   write_addr;
    reg [DATA_WIDTH-1:0]   write_data;
    reg [STRB_WIDTH-1:0]   write_strb;
    wire                   write_done;
    wire [1:0]             write_resp;
    
    reg                    read_req;
    reg [ADDR_WIDTH-1:0]   read_addr;
    wire [DATA_WIDTH-1:0]  read_data;
    wire                   read_done;
    wire [1:0]             read_resp;
    
    // Test Control
    integer test_case = 0;
    integer errors = 0;
    integer tests_passed = 0;
    
    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // DUT Instantiation
    axi4_lite_system_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .STRB_WIDTH(STRB_WIDTH)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .write_req(write_req),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_strb(write_strb),
        .write_done(write_done),
        .write_resp(write_resp),
        .read_req(read_req),
        .read_addr(read_addr),
        .read_data(read_data),
        .read_done(read_done),
        .read_resp(read_resp)
    );
    
    // Reset Task
    task reset_system;
        begin
            $display("=== Applying Reset ===");
            reset_n = 0;
            write_req = 0;
            read_req = 0;
            write_addr = 0;
            write_data = 0;
            write_strb = 0;
            read_addr = 0;
            
            repeat(5) @(posedge clk);
            reset_n = 1;
            repeat(2) @(posedge clk);
            $display("=== Reset Complete ===");
        end
    endtask
    
    // Write Task - Enhanced with timeout
    task axi_write;
        input [ADDR_WIDTH-1:0] addr;
        input [DATA_WIDTH-1:0] data;
        input [STRB_WIDTH-1:0] strb;
        
        integer timeout_count;
        begin
            @(posedge clk);
            write_req = 1;
            write_addr = addr;
            write_data = data;
            write_strb = strb;
            
            @(posedge clk);
            write_req = 0;
            
            // Wait for completion with timeout
            timeout_count = 0;
            while (!write_done && timeout_count < 100) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            
            if (timeout_count >= 100) begin
                $display("ERROR: Write timeout at addr 0x%08h", addr);
                errors = errors + 1;
            end else begin
                $display("Time: %0t | Write: Addr=0x%08h, Data=0x%08h, Strb=0x%01h, Resp=%0d", 
                         $time, addr, data, strb, write_resp);
            end
        end
    endtask
    
    // Read Task - Enhanced with timeout
    task axi_read;
        input [ADDR_WIDTH-1:0] addr;
        output [DATA_WIDTH-1:0] data;
        output [1:0] resp;
        
        integer timeout_count;
        begin
            @(posedge clk);
            read_req = 1;
            read_addr = addr;
            
            @(posedge clk);
            read_req = 0;
            
            // Wait for completion with timeout
            timeout_count = 0;
            while (!read_done && timeout_count < 100) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            
            if (timeout_count >= 100) begin
                $display("ERROR: Read timeout at addr 0x%08h", addr);
                errors = errors + 1;
                data = 32'h0;
                resp = 2'b11;
            end else begin
                data = read_data;
                resp = read_resp;
                $display("Time: %0t | Read: Addr=0x%08h, Data=0x%08h, Resp=%0d", 
                         $time, addr, data, resp);
            end
        end
    endtask
    
    // Data Comparison Task
    task check_data;
        input [DATA_WIDTH-1:0] expected;
        input [DATA_WIDTH-1:0] actual;
        input [255:0] test_name; // String parameter
        begin
            if (expected == actual) begin
                $display("✓ PASS: %0s - Expected: 0x%08h, Got: 0x%08h", test_name, expected, actual);
                tests_passed = tests_passed + 1;
            end else begin
                $display("✗ FAIL: %0s - Expected: 0x%08h, Got: 0x%08h", test_name, expected, actual);
                errors = errors + 1;
            end
        end
    endtask
    
    // Response Check Task
    task check_response;
        input [1:0] expected_resp;
        input [1:0] actual_resp;
        input [255:0] test_name; // String parameter
        begin
            if (expected_resp == actual_resp) begin
                $display("✓ PASS: %0s Response - Expected: %0d, Got: %0d", test_name, expected_resp, actual_resp);
                tests_passed = tests_passed + 1;
            end else begin
                $display("✗ FAIL: %0s Response - Expected: %0d, Got: %0d", test_name, expected_resp, actual_resp);
                errors = errors + 1;
            end
        end
    endtask
    
    // Test Variables
    reg [DATA_WIDTH-1:0] read_data_temp;
    reg [1:0] read_resp_temp;
    reg [DATA_WIDTH-1:0] random_data;
    reg [ADDR_WIDTH-1:0] random_addr;
    integer i;
    
    // Test Scenarios
    initial begin
        $display("=================================");
        $display("    AXI4-Lite Protocol Test");
        $display("    FIXED VERSION");
        $display("=================================");
        
        // Initialize VCD dump
        $dumpfile("axi4_lite_tb.vcd");
        $dumpvars(0, axi4_lite_tb);
        
        // Test Case 1: Basic Write Single Beat
        test_case = 1;
        $display("\n--- Test Case %0d: Basic Write Single Beat ---", test_case);
        reset_system();
        
        axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        check_response(2'b00, write_resp, "Basic Write");
        
        // Test Case 2: Basic Read Single Beat
        test_case = 2;
        $display("\n--- Test Case %0d: Basic Read Single Beat ---", test_case);
        
        axi_read(32'h0000_0000, read_data_temp, read_resp_temp);
        check_data(32'hDEAD_BEEF, read_data_temp, "Basic Read");
        check_response(2'b00, read_resp_temp, "Basic Read");
        
        // Test Case 3: Write with Byte Enables
        test_case = 3;
        $display("\n--- Test Case %0d: Write with Byte Enables ---", test_case);
        
        // First write full data
        axi_write(32'h0000_0004, 32'hFFFF_FFFF, 4'hF);
        axi_write(32'h0000_0004, 32'h1234_5678, 4'h3); // Only lower 2 bytes
        axi_read(32'h0000_0004, read_data_temp, read_resp_temp);
        check_data(32'hFFFF_5678, read_data_temp, "Byte Enable Write");
        check_response(2'b00, read_resp_temp, "Byte Enable Write");
        
        // Test Case 4: Multiple Sequential Writes
        test_case = 4;
        $display("\n--- Test Case %0d: Multiple Sequential Writes ---", test_case);
        
        for (i = 0; i < 4; i = i + 1) begin
            axi_write(32'h0000_0010 + (i*4), 32'hA000_0000 + i, 4'hF);
            check_response(2'b00, write_resp, "Sequential Write");
        end
        
        for (i = 0; i < 4; i = i + 1) begin
            axi_read(32'h0000_0010 + (i*4), read_data_temp, read_resp_temp);
            check_data(32'hA000_0000 + i, read_data_temp, "Sequential Read");
            check_response(2'b00, read_resp_temp, "Sequential Read");
        end
        
        // Test Case 5: Write-Read-Write Pattern
        test_case = 5;
        $display("\n--- Test Case %0d: Write-Read-Write Pattern ---", test_case);
        
        axi_write(32'h0000_0020, 32'hCAFE_BABE, 4'hF);
        check_response(2'b00, write_resp, "WRW Pattern First Write");
        axi_read(32'h0000_0020, read_data_temp, read_resp_temp);
        check_data(32'hCAFE_BABE, read_data_temp, "WRW Pattern Read");
        check_response(2'b00, read_resp_temp, "WRW Pattern Read");
        axi_write(32'h0000_0020, 32'hFEED_FACE, 4'hF);
        check_response(2'b00, write_resp, "WRW Pattern Second Write");
        axi_read(32'h0000_0020, read_data_temp, read_resp_temp);
        check_data(32'hFEED_FACE, read_data_temp, "WRW Pattern Final Read");
        check_response(2'b00, read_resp_temp, "WRW Pattern Final Read");
        
        // Test Case 6: Error Response Test (Invalid Address)
        test_case = 6;
        $display("\n--- Test Case %0d: Error Response Test ---", test_case);
        
        axi_write(32'hFFFF_FFFF, 32'h1111_1111, 4'hF); // Invalid address
        check_response(2'b10, write_resp, "Invalid Write Address");
        
        axi_read(32'hFFFF_FFFF, read_data_temp, read_resp_temp); // Invalid address
        check_response(2'b10, read_resp_temp, "Invalid Read Address");
        check_data(32'h0000_0000, read_data_temp, "Invalid Read Data");
        
        // Test Case 7: Boundary Address Test
        test_case = 7;
        $display("\n--- Test Case %0d: Boundary Address Test ---", test_case);
        
        axi_write(32'h0000_03FC, 32'h5A5A_A5A5, 4'hF); // Last valid address
        check_response(2'b00, write_resp, "Boundary Address Write");
        axi_read(32'h0000_03FC, read_data_temp, read_resp_temp);
        check_data(32'h5A5A_A5A5, read_data_temp, "Boundary Address Read");
        check_response(2'b00, read_resp_temp, "Boundary Address Read");
        
        // Test Case 8: Different Byte Enable Patterns
        test_case = 8;
        $display("\n--- Test Case %0d: Byte Enable Patterns ---", test_case);
        
        // Initialize with known pattern
        axi_write(32'h0000_0030, 32'h00000000, 4'hF);
        
        // Test different byte enable patterns
        axi_write(32'h0000_0030, 32'hAABBCCDD, 4'h1); // Only byte 0
        axi_read(32'h0000_0030, read_data_temp, read_resp_temp);
        check_data(32'h000000DD, read_data_temp, "Byte Enable 0x1");
        
        axi_write(32'h0000_0030, 32'hAABBCCDD, 4'h2); // Only byte 1
        axi_read(32'h0000_0030, read_data_temp, read_resp_temp);
        check_data(32'h0000CCDD, read_data_temp, "Byte Enable 0x2");
        
        axi_write(32'h0000_0030, 32'hAABBCCDD, 4'h4); // Only byte 2
        axi_read(32'h0000_0030, read_data_temp, read_resp_temp);
        check_data(32'h00BBCCDD, read_data_temp, "Byte Enable 0x4");
        
        axi_write(32'h0000_0030, 32'hAABBCCDD, 4'h8); // Only byte 3
        axi_read(32'h0000_0030, read_data_temp, read_resp_temp);
        check_data(32'hAABBCCDD, read_data_temp, "Byte Enable 0x8");
        
        // Test Case 9: Random Data Pattern Test
        test_case = 9;
        $display("\n--- Test Case %0d: Random Data Pattern Test ---", test_case);
        
        for (i = 0; i < 10; i = i + 1) begin
            random_data = $random;
            // Ensure address is within valid range (0 to 1023, 4-byte aligned)
            // Memory size is 1024 bytes, so valid addresses are 0x000 to 0x3FF
            random_addr = (($random & 32'h000000FF) << 2) & 32'h000003FC; 
            axi_write(random_addr, random_data, 4'hF);
            check_response(2'b00, write_resp, "Random Write");
            axi_read(random_addr, read_data_temp, read_resp_temp);
            check_data(random_data, read_data_temp, "Random Read");
            check_response(2'b00, read_resp_temp, "Random Read");
        end
        
        // Test Summary
        $display("\n=================================");
        $display("        Test Summary");
        $display("=================================");
        $display("Total Tests: %0d", tests_passed + errors);
        $display("Passed: %0d", tests_passed);
        $display("Failed: %0d", errors);
        
        if (errors == 0) begin
            $display("✓ ALL TESTS PASSED!");
        end else begin
            $display("✗ %0d TESTS FAILED!", errors);
        end
        
        $display("=================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout Watchdog
    initial begin
        #2000000; // 2ms timeout (increased for more tests)
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    // Protocol violation checker
    initial begin
        forever begin
            @(posedge clk);
            
            // Check for protocol violations
            if (dut.axi_awvalid && !reset_n) begin
                $display("WARNING: AWVALID asserted during reset");
            end
            
            if (dut.axi_wvalid && !reset_n) begin
                $display("WARNING: WVALID asserted during reset");
            end
            
            if (dut.axi_arvalid && !reset_n) begin
                $display("WARNING: ARVALID asserted during reset");
            end
        end
    end
endmodule