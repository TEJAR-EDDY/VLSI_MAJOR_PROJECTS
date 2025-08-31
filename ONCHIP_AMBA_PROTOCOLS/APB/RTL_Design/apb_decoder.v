// Apb_decoder design using verilog_HDL
// Author: Teja Reddy
// APB Address Decoder for multi-slave support 
 
module apb_decoder #( 
    parameter ADDR_WIDTH = 32, 
    parameter NUM_SLAVES = 3     	
 
 
)( 
    // APB signals from master 
    input  wire [ADDR_WIDTH-1:0]   paddr, 
    input  wire                    psel_master, 
     
    // Slave select outputs 
    output reg  [NUM_SLAVES-1:0]   psel_slaves, 
     
    // Error indication 
    output reg                     decode_error 
); 
 
    // Address mapping parameters 
    localparam SLAVE_ADDR_BITS = 16; // 64KB per slave 
     
    // Address decode logic 
    always_comb begin 
        psel_slaves = '0; 
        decode_error = 1'b0; 
         
        if (psel_master) begin 
            case (paddr[19:16]) // Use bits [19:16] for slave selection 
                4'h0: psel_slaves[0] = 1'b1; // Slave 0: 0x00000-0x0FFFF 
                4'h1: psel_slaves[1] = 1'b1; // Slave 1: 0x10000-0x1FFFF 
                4'h2: psel_slaves[2] = 1'b1; // Slave 2: 0x20000-0x2FFFF 
                default: begin 
                    psel_slaves = '0; 
                    decode_error = 1'b1; 
                end 
            endcase 
        end 
    end 
endmodule 
 
