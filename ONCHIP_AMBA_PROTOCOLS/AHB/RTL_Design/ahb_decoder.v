//=========================================================================== 
// AHB Address Decoder 
// Generates slave select signals based on address ranges 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_decoder #( 
    parameter ADDR_WIDTH = 32, 
    parameter SLAVE_COUNT = 4 
)( 
    input  wire [ADDR_WIDTH-1:0]   HADDR, 
    output reg  [SLAVE_COUNT-1:0]  HSEL 
); 
 
    // Address Map Configuration 
    // Slave 0: 0x0000_0000 - 0x0FFF_FFFF (Memory) 
    // Slave 1: 0x1000_0000 - 0x1FFF_FFFF (Timer)   
    // Slave 2: 0x2000_0000 - 0x2FFF_FFFF (UART) 
    // Slave 3: 0x3000_0000 - 0x3FFF_FFFF (GPIO) 
     
    always @(*) begin 
        HSEL = {SLAVE_COUNT{1'b0}}; 
         
        case (HADDR[31:28]) 
            4'h0: HSEL[0] = 1'b1; // Slave 0 - Memory 
            4'h1: HSEL[1] = 1'b1; // Slave 1 - Timer 
            4'h2: HSEL[2] = 1'b1; // Slave 2 - UART   
            4'h3: HSEL[3] = 1'b1; // Slave 3 - GPIO 
            default: HSEL = {SLAVE_COUNT{1'b0}}; 
        endcase 
    end 
 
endmodule
