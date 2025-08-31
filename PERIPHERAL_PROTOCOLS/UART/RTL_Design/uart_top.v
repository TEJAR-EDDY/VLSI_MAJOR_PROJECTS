//============================================================================
// File: uart_top.v  
// Description: Top-level UART module integrating TX, RX, and baud generator  
// Features: Full-duplex, configurable interface, error detection  
// Author: Teja Reddy   
//============================================================================
 
module uart_top #(  
// Parameters  
parameter CLK_FREQ = 50_000_000, // System clock frequency (Hz)  
parameter DEFAULT_BAUD = 9600, // Default baud rate  
parameter DATA_WIDTH = 8, // Data width (5–8 bits)  
parameter DEFAULT_PARITY_EN = 1'b0, // Default: parity disabled  
parameter DEFAULT_PARITY_ODD = 1'b0, // Default: even parity  
parameter DEFAULT_STOP_BITS = 2'd1 // Default: 1 stop bit  
)(  
// System Interface  
input wire clk,  
input wire reset,  
input wire enable,  
// Configuration  
input wire [15:0] baud_divisor,  
input wire parity_en,  
input wire parity_odd,  
input wire [1:0] stop_bits,  
// Transmitter Interface  
input wire [DATA_WIDTH-1:0] tx_data,  
input wire tx_start,  
output wire tx_busy,  
output wire tx_done,  
// Receiver Interface  
output wire [DATA_WIDTH-1:0] rx_data,  
output wire rx_valid,  
output wire rx_busy,  
// Error Flags  
 
 
output wire parity_error,  
output wire frame_error,  
output wire overrun_error,  
// Physical UART I/O  
output wire uart_tx,  
input wire uart_rx  
);  
// Internal Signals  
wire baud_tick;  
wire baud_x16_tick;  
//=================================================================  
// Baud Rate Generator  
//=================================================================  
baud_gen #(  
.CLK_FREQ (CLK_FREQ),  
.DEFAULT_BAUD (DEFAULT_BAUD)  
) u_baud_gen (  
.clk (clk),  
.reset (reset),  
.baud_divisor (baud_divisor),  
.enable (enable),  
.baud_tick (baud_tick),  
.baud_x16_tick (baud_x16_tick)  
);  
//=================================================================  
// Transmitter  
//=================================================================  
uart_tx #(  
.DATA_WIDTH (DATA_WIDTH),  
.PARITY_EN (DEFAULT_PARITY_EN),  
.PARITY_ODD (DEFAULT_PARITY_ODD),  
.STOP_BITS (DEFAULT_STOP_BITS)  
) u_uart_tx (  
.clk (clk),  
.reset (reset),  
.baud_tick (baud_tick),  
.enable (enable),  
.parity_en (parity_en),  
.parity_odd (parity_odd),  
.stop_bits (stop_bits),  
.tx_data (tx_data),  
.tx_start (tx_start),  
.tx_busy (tx_busy),  
.tx_done (tx_done),  
.uart_tx (uart_tx)  
);  
//=================================================================  
// Receiver  
//=================================================================  
uart_rx #(  
 
 
.DATA_WIDTH (DATA_WIDTH),  
.PARITY_EN (DEFAULT_PARITY_EN),  
.PARITY_ODD (DEFAULT_PARITY_ODD),  
.STOP_BITS (DEFAULT_STOP_BITS)  
) u_uart_rx (  
.clk (clk),  
.reset (reset),  
.baud_x16_tick (baud_x16_tick),  
.enable (enable),  
.parity_en (parity_en),  
.parity_odd (parity_odd),  
.stop_bits (stop_bits),  
.uart_rx (uart_rx),  
.rx_data (rx_data),  
.rx_valid (rx_valid),  
.rx_busy (rx_busy),  
.parity_error (parity_error),  
.frame_error (frame_error),  
.overrun_error (overrun_error)  
);  
endmodule  
