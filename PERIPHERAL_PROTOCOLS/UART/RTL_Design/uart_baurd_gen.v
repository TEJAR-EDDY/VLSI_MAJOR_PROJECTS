//============================================================================

// Module: baud_gen.v 
// Description: Configurable baud rate generator for UART 
// Author: Teja Reddy 

//============================================================================
 
 
module baud_gen #( 
    parameter CLK_FREQ = 50_000_000,    // System clock frequency in Hz 
    parameter BAUD_RATE = 9600          // Desired baud rate 
)( 
    input  wire clk,                    // System clock 
    input  wire reset,                  // Active high reset 
    input  wire [15:0] baud_divisor,    // Configurable divisor 
    output reg  baud_tick,              // Baud rate tick (for TX) 
    output reg  baud_x16_tick           // 16x baud rate tick (for RX) 
); 
 
    // Calculate default divisor for 16x oversampling 
    localparam DIVISOR_16X = CLK_FREQ / (BAUD_RATE * 16); 
     
    // Internal counter 
    reg [15:0] counter; 
    reg [3:0]  baud_counter;  // Counter for baud_tick generation 
     
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            counter       <= 0; 
            baud_counter  <= 0; 
            baud_tick     <= 1'b0; 
            baud_x16_tick <= 1'b0; 
        end 
        else begin 
            // Generate 16x baud rate tick 
            if (counter >= baud_divisor - 1) begin 
                counter <= 0; 
                baud_x16_tick <= 1'b1; 
                 
                // Generate baud rate tick (1/16 of baud_x16_tick) 
                if (baud_counter >= 15) begin 
                    baud_counter <= 0; 
                    baud_tick <= 1'b1; 
                end 
                else begin 
 
 
                    baud_counter <= baud_counter + 1; 
                    baud_tick <= 1'b0; 
                end 
            end 
            else begin 
                counter <= counter + 1; 
                baud_tick <= 1'b0; 
                baud_x16_tick <= 1'b0; 
            end 
        end 
    end 
     
endmodule 
