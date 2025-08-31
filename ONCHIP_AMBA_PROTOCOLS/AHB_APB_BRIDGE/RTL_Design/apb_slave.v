//================================================================ 
// APB Slave Model - For Verification 
//  Author: Teja Reddy
//================================================================ 
 
module apb_slave #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter SLAVE_ID = 0 
)( 
    input  wire                    PCLK, 
    input  wire                    PRESETn, 
    input  wire [ADDR_WIDTH-1:0]   PADDR, 
 
 
    input  wire                    PSEL, 
    input  wire                    PENABLE, 
    input  wire                    PWRITE, 
    input  wire [DATA_WIDTH-1:0]   PWDATA, 
    output reg  [DATA_WIDTH-1:0]   PRDATA, 
    output reg                     PREADY, 
    output reg                     PSLVERR 
); 
 
    // Internal memory array (1KB per slave) 
    reg [DATA_WIDTH-1:0] memory [0:255]; 
    reg [1:0] wait_counter; 
     
    // Memory initialization 
    initial begin 
        integer i; 
        for (i = 0; i < 256; i = i + 1) begin 
            memory[i] = SLAVE_ID * 32'h1000 + i; // Unique pattern per slave 
        end 
        wait_counter = 0; 
    end 
     
    always @(posedge PCLK or negedge PRESETn) begin 
        if (!PRESETn) begin 
            PRDATA <= 0; 
            PREADY <= 1; 
            PSLVERR <= 0; 
            wait_counter <= 0; 
        end else begin 
            if (PSEL && PENABLE) begin 
                // Simulate wait states randomly 
                if (wait_counter < 2) begin 
                    PREADY <= 0; 
                    wait_counter <= wait_counter + 1; 
                end else begin 
                    PREADY <= 1; 
                    wait_counter <= 0; 
                     
                    // Address range check 
                    if (PADDR[15:0] > 16'h03FF) begin 
                        PSLVERR <= 1; // Address out of range 
                    end else begin 
                        PSLVERR <= 0; 
                         
                        if (PWRITE) begin 
                            // Write operation 
                            memory[PADDR[9:2]] <= PWDATA; 
                            $display("APB Slave %0d Write: Addr=0x%h, Data=0x%h",  
                                   SLAVE_ID, PADDR, PWDATA); 
                        end else begin 
 
 
                            // Read operation 
                            PRDATA <= memory[PADDR[9:2]]; 
                            $display("APB Slave %0d Read: Addr=0x%h, Data=0x%h",  
                                   SLAVE_ID, PADDR, memory[PADDR[9:2]]); 
                        end 
                    end 
                end 
            end else begin 
                PREADY <= 1; 
                PSLVERR <= 0; 
                wait_counter <= 0; 
            end 
        end 
    end 
endmodule 
