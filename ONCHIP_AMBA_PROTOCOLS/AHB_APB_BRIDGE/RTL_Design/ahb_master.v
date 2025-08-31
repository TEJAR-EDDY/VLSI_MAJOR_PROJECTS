//================================================================ 
// AHB Master Model - For Verification 
// Author: Teja Reddy
//================================================================ 
 
module ahb_master #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32 
)( 
    input  wire                    HCLK, 
    input  wire                    HRESETn, 
    output reg  [ADDR_WIDTH-1:0]   HADDR, 
    output reg  [1:0]              HTRANS, 
    output reg                     HWRITE, 
    output reg  [2:0]              HSIZE, 
    output reg  [DATA_WIDTH-1:0]   HWDATA, 
    input  wire [DATA_WIDTH-1:0]   HRDATA, 
    input  wire                    HREADY, 
    input  wire [1:0]              HRESP 
); 
 
    // Task to perform AHB write 
    task ahb_write; 
        input [ADDR_WIDTH-1:0] addr; 
        input [DATA_WIDTH-1:0] data; 
        begin 
            @(posedge HCLK); 
            while (!HREADY) @(posedge HCLK); 
             
            // Address Phase 
            HADDR  <= addr; 
            HTRANS <= 2'b10; // NONSEQ 
            HWRITE <= 1; 
            HSIZE  <= 3'b010; // 32-bit word 
 
 
             
            @(posedge HCLK); 
             
            // Data Phase   
            HWDATA <= data; 
            HTRANS <= 2'b00; // IDLE 
             
            // Wait for completion 
            while (!HREADY) @(posedge HCLK); 
             
            $display("AHB Master Write: Addr=0x%h, Data=0x%h, Resp=0x%h",  
                   addr, data, HRESP); 
        end 
    endtask 
     
    // Task to perform AHB read 
    task ahb_read; 
        input  [ADDR_WIDTH-1:0] addr; 
        output [DATA_WIDTH-1:0] data; 
        begin 
            @(posedge HCLK); 
            while (!HREADY) @(posedge HCLK); 
             
            // Address Phase 
            HADDR  <= addr; 
            HTRANS <= 2'b10; // NONSEQ   
            HWRITE <= 0; 
            HSIZE  <= 3'b010; // 32-bit word 
             
            @(posedge HCLK); 
            HTRANS <= 2'b00; // IDLE 
             
            // Wait for completion and capture data 
            while (!HREADY) @(posedge HCLK); 
            data = HRDATA; 
             
            $display("AHB Master Read: Addr=0x%h, Data=0x%h, Resp=0x%h",  
                   addr, data, HRESP); 
        end 
    endtask 
    // Initialize outputs 
    initial begin 
        HADDR  = 0; 
        HTRANS = 2'b00; // IDLE 
        HWRITE = 0; 
        HSIZE  = 3'b010; 
        HWDATA = 0; 
    end 
endmodule 
