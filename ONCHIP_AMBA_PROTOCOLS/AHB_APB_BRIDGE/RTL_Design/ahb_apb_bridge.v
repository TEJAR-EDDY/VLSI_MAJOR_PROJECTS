//================================================================ 
// AHB to APB Bridge - Main RTL Module 
//  Author: Teja Reddy
//================================================================ 
 
module ahb_apb_bridge #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter NUM_SLAVES = 3 
)( 
    // Global signals 
    input  wire                    HCLK, 
    input  wire                    HRESETn, 
     
    // AHB Interface (Slave) 
    input  wire [ADDR_WIDTH-1:0]   HADDR, 
    input  wire [1:0]              HTRANS, 
    input  wire                    HWRITE, 
    input  wire [2:0]              HSIZE, 
    input  wire [DATA_WIDTH-1:0]   HWDATA, 
    output reg  [DATA_WIDTH-1:0]   HRDATA, 
    output reg                     HREADY, 
    output reg  [1:0]              HRESP, 
     
    // APB Interface (Master) 
    output reg  [ADDR_WIDTH-1:0]   PADDR, 
    output reg  [NUM_SLAVES-1:0]   PSEL, 
    output reg                     PENABLE, 
    output reg                     PWRITE, 
    output reg  [DATA_WIDTH-1:0]   PWDATA, 
 
    input  wire [DATA_WIDTH-1:0]   PRDATA, 
    input  wire                    PREADY, 
    input  wire                    PSLVERR 
); 
 
    //================================================================ 
    // FSM States 
    //================================================================ 
    typedef enum reg [1:0] { 
        IDLE   = 2'b00, 
        SETUP  = 2'b01, 
        ENABLE = 2'b10 
    } state_t; 
     
    state_t current_state, next_state; 
     
    //================================================================ 
    // Internal Registers 
    //================================================================ 
    reg [ADDR_WIDTH-1:0]  addr_reg; 
    reg                   write_reg; 
    reg [2:0]             size_reg; 
    reg [DATA_WIDTH-1:0]  wdata_reg; 
     
    //================================================================ 
    // Address Decoding Logic 
    //================================================================ 
    function [NUM_SLAVES-1:0] decode_address; 
        input [ADDR_WIDTH-1:0] address; 
        begin 
            case(address[19:16])  // Using bits [19:16] for slave select 
                4'h0: decode_address = 3'b001;  // Slave 0: 0x4000_xxxx 
                4'h1: decode_address = 3'b010;  // Slave 1: 0x4001_xxxx   
                4'h2: decode_address = 3'b100;  // Slave 2: 0x4002_xxxx 
                default: decode_address = 3'b000; 
            endcase 
        end 
    endfunction 
     
    //================================================================ 
    // FSM Sequential Logic 
    //================================================================ 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            current_state <= IDLE; 
        end else begin 
            current_state <= next_state; 
        end 
    end 
     
 
 
    //================================================================ 
    // FSM Combinational Logic 
    //================================================================ 
    always @(*) begin 
        next_state = current_state; 
         
        case (current_state) 
            IDLE: begin 
                if (HTRANS == 2'b10 || HTRANS == 2'b11) begin // NONSEQ or SEQ 
                    next_state = SETUP; 
                end 
            end 
             
            SETUP: begin 
                next_state = ENABLE; 
            end 
             
            ENABLE: begin 
                if (PREADY) begin 
                    if (HTRANS == 2'b10 || HTRANS == 2'b11) begin 
                        next_state = SETUP;  // Back-to-back transfers 
                    end else begin 
                        next_state = IDLE; 
                    end 
                end 
            end 
             
            default: next_state = IDLE; 
        endcase 
    end 
     
    //================================================================ 
    // Capture AHB Transfer Information 
    //================================================================ 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            addr_reg  <= 0; 
            write_reg <= 0; 
            size_reg  <= 0; 
        end else if (current_state == IDLE && next_state == SETUP) begin 
            addr_reg  <= HADDR; 
            write_reg <= HWRITE; 
            size_reg  <= HSIZE; 
        end 
    end 
     
    // Capture write data (delayed by one cycle in AHB) 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            wdata_reg <= 0; 
 
 
        end else if (current_state == SETUP) begin 
            wdata_reg <= HWDATA; 
        end 
    end 
     
    //================================================================ 
    // APB Output Generation 
    //================================================================ 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            PADDR   <= 0; 
            PSEL    <= 0; 
            PENABLE <= 0; 
            PWRITE  <= 0; 
            PWDATA  <= 0; 
        end else begin 
            case (current_state) 
                IDLE: begin 
                    PSEL    <= 0; 
                    PENABLE <= 0; 
                end 
                 
                SETUP: begin 
                    PADDR   <= addr_reg; 
                    PSEL    <= decode_address(addr_reg); 
                    PENABLE <= 0; 
                    PWRITE  <= write_reg; 
                    if (write_reg) begin 
                        PWDATA <= wdata_reg; 
                    end 
                end 
                 
                ENABLE: begin 
                    PENABLE <= 1; 
                    if (PREADY) begin 
                        if (next_state == SETUP) begin 
                            // Back-to-back transfer 
                            PADDR   <= HADDR; 
                            PSEL    <= decode_address(HADDR); 
                            PENABLE <= 0; 
                            PWRITE  <= HWRITE; 
                        end else begin 
                            PSEL    <= 0; 
                            PENABLE <= 0; 
                        end 
                    end 
                end 
            endcase 
        end 
    end 
 
 
     
    //================================================================ 
    // AHB Response Generation 
    //================================================================ 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            HREADY <= 1; 
            HRESP  <= 2'b00; // OKAY 
            HRDATA <= 0; 
        end else begin 
            case (current_state) 
                IDLE: begin 
                    HREADY <= 1; 
                    HRESP  <= 2'b00; 
                end 
                 
                SETUP: begin 
                    HREADY <= 0;  // AHB transfer in progress 
                    HRESP  <= 2'b00; 
                end 
                 
                ENABLE: begin 
                    if (PREADY) begin 
                        HREADY <= 1; 
                        HRESP  <= PSLVERR ? 2'b01 : 2'b00; // ERROR or OKAY 
                        if (!write_reg) begin 
                            HRDATA <= PRDATA; 
                        end 
                    end else begin 
                        HREADY <= 0;  // Wait for APB slave 
                    end 
                end 
            endcase 
        end 
    end 
endmodule 
