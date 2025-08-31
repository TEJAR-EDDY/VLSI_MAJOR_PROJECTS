// axi4_lite protocol RTL design using verilog HDL
// Author: Teja Reddy
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
    // Write Address Channel 
    output reg [ADDR_WIDTH-1:0]   M_AXI_AWADDR, 
    output reg                    M_AXI_AWVALID, 
    input wire                    M_AXI_AWREADY, 
     
    // Write Data Channel 
    output reg [DATA_WIDTH-1:0]   M_AXI_WDATA, 
    output reg [STRB_WIDTH-1:0]   M_AXI_WSTRB, 
 
 
    output reg                    M_AXI_WVALID, 
    input wire                    M_AXI_WREADY, 
     
    // Write Response Channel 
    input wire [1:0]              M_AXI_BRESP, 
    input wire                    M_AXI_BVALID, 
    output reg                    M_AXI_BREADY, 
     
    // Read Address Channel 
    output reg [ADDR_WIDTH-1:0]   M_AXI_ARADDR, 
    output reg                    M_AXI_ARVALID, 
    input wire                    M_AXI_ARREADY, 
     
    // Read Data Channel 
    input wire [DATA_WIDTH-1:0]   M_AXI_RDATA, 
    input wire [1:0]              M_AXI_RRESP, 
    input wire                    M_AXI_RVALID, 
    output reg                    M_AXI_RREADY 
); 
 
    // Write FSM States 
    typedef enum logic [1:0] { 
        WRITE_IDLE  = 2'b00, 
        WRITE_ADDR  = 2'b01,  
        WRITE_DATA  = 2'b10, 
        WRITE_RESP  = 2'b11 
    } write_state_t; 
     
    // Read FSM States 
    typedef enum logic [1:0] { 
        READ_IDLE   = 2'b00, 
        READ_ADDR   = 2'b01, 
        READ_DATA   = 2'b10 
    } read_state_t; 
     
    write_state_t write_state, write_state_next; 
    read_state_t read_state, read_state_next; 
     
    // Write FSM Sequential Logic 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            write_state <= WRITE_IDLE; 
        end else begin 
            write_state <= write_state_next; 
        end 
    end 
     
    // Write FSM Combinational Logic 
    always_comb begin 
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
        endcase 
    end 
     
    // Write Channel Outputs 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            M_AXI_AWADDR    <= '0; 
            M_AXI_AWVALID   <= 1'b0; 
            M_AXI_WDATA     <= '0; 
            M_AXI_WSTRB     <= '0; 
            M_AXI_WVALID    <= 1'b0; 
            M_AXI_BREADY    <= 1'b0; 
            write_done      <= 1'b0; 
            write_resp      <= 2'b00; 
        end else begin 
            case (write_state) 
                WRITE_IDLE: begin 
                    M_AXI_AWVALID <= 1'b0; 
                    M_AXI_WVALID  <= 1'b0; 
                    M_AXI_BREADY  <= 1'b0; 
                    write_done    <= 1'b0; 
                     
                    if (write_req) begin 
                        M_AXI_AWADDR  <= write_addr; 
                        M_AXI_WDATA   <= write_data; 
                        M_AXI_WSTRB   <= write_strb; 
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
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            read_state <= READ_IDLE; 
        end else begin 
            read_state <= read_state_next; 
        end 
    end 
     
    // Read FSM Combinational Logic 
    always_comb begin 
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
        endcase 
    end 
     
    // Read Channel Outputs 
    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            M_AXI_ARADDR  <= '0; 
            M_AXI_ARVALID <= 1'b0; 
            M_AXI_RREADY  <= 1'b0; 
            read_data     <= '0; 
 
 
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
