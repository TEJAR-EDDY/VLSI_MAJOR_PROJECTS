//=========================================================================== 
// AHB Response Multiplexer 
// Multiplexes slave responses back to master 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_mux #( 
    parameter DATA_WIDTH = 32, 
    parameter SLAVE_COUNT = 4 
)( 
    input  wire [SLAVE_COUNT-1:0]           HSEL, 
    input  wire [SLAVE_COUNT*DATA_WIDTH-1:0] HRDATA_slaves, 
    input  wire [SLAVE_COUNT-1:0]           HREADY_slaves, 
    input  wire [SLAVE_COUNT*2-1:0]         HRESP_slaves, 
     
    output reg  [DATA_WIDTH-1:0]            HRDATA, 
    output reg                              HREADY, 
 
 
    output reg  [1:0]                       HRESP 
); 
 
    integer i; 
     
    always @(*) begin 
        // Default values 
        HRDATA = {DATA_WIDTH{1'b0}}; 
        HREADY = 1'b1; 
        HRESP = 2'b00; 
         
        // Multiplex based on slave selection 
        for (i = 0; i < SLAVE_COUNT; i = i + 1) begin 
            if (HSEL[i]) begin 
                HRDATA = HRDATA_slaves[i*DATA_WIDTH +: DATA_WIDTH]; 
                HREADY = HREADY_slaves[i]; 
                HRESP = HRESP_slaves[i*2 +: 2]; 
            end 
        end 
    end 
endmodule 
