//=========================================================================== 
// AHB Slave Module (Memory-based with Wait State Support) 
// Configurable memory depth and wait states 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_slave #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter MEMORY_DEPTH = 1024, 
    parameter WAIT_STATES = 0 
)( 
    // Clock and Reset 
    input  wire                    HCLK, 
    input  wire                    HRESETn, 
     
    // Slave Interface 
    input  wire [ADDR_WIDTH-1:0]   HADDR, 
    input  wire [1:0]              HTRANS, 
    input  wire                    HWRITE, 
    input  wire [2:0]              HSIZE, 
    input  wire [2:0]              HBURST, 
    input  wire [3:0]              HPROT, 
    input  wire [DATA_WIDTH-1:0]   HWDATA, 
    input  wire                    HSEL, 
    output reg  [DATA_WIDTH-1:0]   HRDATA, 
    output reg                     HREADY, 
    output reg  [1:0]              HRESP 
); 
 
    // Memory Array 
    reg [DATA_WIDTH-1:0] memory [0:MEMORY_DEPTH-1]; 
     
    // Internal Registers 
 
 
    reg [ADDR_WIDTH-1:0]   stored_addr; 
    reg                    stored_write; 
    reg [2:0]              stored_size; 
    reg [DATA_WIDTH-1:0]   stored_wdata; 
    reg                    transfer_active; 
    reg [3:0]              wait_counter; 
     
    // Address decode 
    wire [ADDR_WIDTH-3:0] word_addr = stored_addr[ADDR_WIDTH-1:2]; 
    wire valid_addr = (word_addr < MEMORY_DEPTH); 
     
    // Transfer detection 
    wire transfer_request = HSEL && (HTRANS == 2'b10 || HTRANS == 2'b11); 
     
    //----------------------------------------------------------------------- 
    // Address Phase - Store transfer information 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            stored_addr   <= {ADDR_WIDTH{1'b0}}; 
            stored_write  <= 1'b0; 
            stored_size   <= 3'b0; 
            transfer_active <= 1'b0; 
        end else begin 
            if (transfer_request && HREADY) begin 
                stored_addr   <= HADDR; 
                stored_write  <= HWRITE; 
                stored_size   <= HSIZE; 
                transfer_active <= 1'b1; 
            end else if (HREADY) begin 
                transfer_active <= 1'b0; 
            end 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // Data Phase - Store write data 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            stored_wdata <= {DATA_WIDTH{1'b0}}; 
        end else if (transfer_active && HREADY) begin 
            stored_wdata <= HWDATA; 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // Wait State Generation 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
 
 
        if (!HRESETn) begin 
            wait_counter <= 4'b0; 
            HREADY <= 1'b1; 
        end else begin 
            if (transfer_active && wait_counter < WAIT_STATES) begin 
                wait_counter <= wait_counter + 1; 
                HREADY <= 1'b0; 
            end else begin 
                wait_counter <= 4'b0; 
                HREADY <= 1'b1; 
            end 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // Memory Access and Response Generation 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            HRDATA <= {DATA_WIDTH{1'b0}}; 
            HRESP <= 2'b00; // OKAY 
            // Initialize memory with test pattern 
            for (integer i = 0; i < MEMORY_DEPTH; i = i + 1) begin 
                memory[i] <= i; 
            end 
        end else if (transfer_active && HREADY) begin 
            if (!valid_addr) begin 
                // Address out of range - return error 
                HRESP <= 2'b01; // ERROR 
                HRDATA <= {DATA_WIDTH{1'b0}}; 
            end else begin 
                HRESP <= 2'b00; // OKAY 
                if (stored_write) begin 
                    // Write operation 
                    case (stored_size) 
                        3'b000: memory[word_addr][7:0] <= stored_wdata[7:0];     // Byte 
                        3'b001: memory[word_addr][15:0] <= stored_wdata[15:0];   // Halfword 
                        3'b010: memory[word_addr] <= stored_wdata;               // Word 
                        default: memory[word_addr] <= stored_wdata; 
                    endcase 
                    HRDATA <= {DATA_WIDTH{1'b0}}; 
                end else begin 
                    // Read operation 
                    HRDATA <= memory[word_addr]; 
                end 
            end 
        end else if (!transfer_active) begin 
            HRESP <= 2'b00; // OKAY when idle 
        end 
    end 
 
endmodule
