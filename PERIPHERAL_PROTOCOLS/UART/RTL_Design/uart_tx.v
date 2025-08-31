//============================================================================

// Module: uart_tx.v 
// Description: UART Transmitter with configurable parameters 
// Author: Teja Reddy
 
//============================================================================

module uart_tx #( 
    parameter DATA_BITS = 8,            // Data width (5-8 bits) 
    parameter PARITY_EN = 1,            // Parity enable (1=enabled, 0=disabled) 
    parameter PARITY_TYPE = 0,          // Parity type (0=even, 1=odd) 
    parameter STOP_BITS = 1             // Number of stop bits (1 or 2) 
)( 
    input  wire clk,                    // System clock 
    input  wire reset,                  // Active high reset 
    input  wire baud_tick,              // Baud rate tick from baud generator 
    input  wire [DATA_BITS-1:0] tx_data,// Data to transmit 
    input  wire tx_valid,               // Start transmission when high 
    input  wire parity_en,              // Runtime parity enable 
    input  wire parity_type,            // Runtime parity type 
    input  wire [1:0] stop_bits,        // Runtime stop bits configuration 
    output reg  tx_ready,               // Ready to accept new data 
    output reg  uart_tx                 // UART TX output line 
); 
 
    // FSM States 
    localparam IDLE   = 3'b000; 
    localparam START  = 3'b001; 
    localparam DATA   = 3'b010; 
    localparam PARITY = 3'b011; 
    localparam STOP   = 3'b100; 
 
    // Internal registers 
 
 
    reg [2:0] state, next_state; 
    reg [DATA_BITS-1:0] shift_reg;      // Data shift register 
    reg [3:0] bit_counter;              // Bit counter for data bits 
    reg [1:0] stop_counter;             // Counter for stop bits 
    reg parity_bit;                     // Calculated parity bit 
     
    // Parity calculation 
    always @(*) begin 
        if (parity_type == 0) begin 
            // Even parity: XOR all data bits 
            parity_bit = ^shift_reg; 
        end 
        else begin 
            // Odd parity: NOT of XOR all data bits 
            parity_bit = ~(^shift_reg); 
        end 
    end 
 
    // FSM State Register 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            state <= IDLE; 
        end 
        else begin 
            state <= next_state; 
        end 
    end 
 
    // FSM Next State Logic 
    always @(*) begin 
        case (state) 
            IDLE: begin 
                if (tx_valid && tx_ready) 
                    next_state = START; 
                else 
                    next_state = IDLE; 
            end 
             
            START: begin 
                if (baud_tick) 
                    next_state = DATA; 
                else 
                    next_state = START; 
            end 
             
            DATA: begin 
                if (baud_tick && (bit_counter >= DATA_BITS - 1)) begin 
                    if (parity_en) 
                        next_state = PARITY; 
                    else 
 
 
                        next_state = STOP; 
                end 
                else 
                    next_state = DATA; 
            end 
             
            PARITY: begin 
                if (baud_tick) 
                    next_state = STOP; 
                else 
                    next_state = PARITY; 
            end 
             
            STOP: begin 
                if (baud_tick && (stop_counter >= stop_bits - 1)) 
                    next_state = IDLE; 
                else 
                    next_state = STOP; 
            end 
             
            default: next_state = IDLE; 
        endcase 
    end 
 
    // FSM Output Logic and Data Handling 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            uart_tx      <= 1'b1;      // Idle high 
            tx_ready     <= 1'b1;      // Ready to accept data 
            shift_reg    <= 0; 
            bit_counter  <= 0; 
            stop_counter <= 0; 
        end 
        else begin 
            case (state) 
                IDLE: begin 
                    uart_tx <= 1'b1;          // Idle high 
                    tx_ready <= 1'b1;         // Ready for new data 
                    bit_counter <= 0; 
                    stop_counter <= 0; 
                     
                    if (tx_valid && tx_ready) begin 
                        shift_reg <= tx_data;   // Load data to transmit 
                        tx_ready <= 1'b0;      // Busy transmitting 
                    end 
                end 
                 
                START: begin 
                    uart_tx <= 1'b0;          // Send start bit 
                    tx_ready <= 1'b0;         // Still busy 
 
 
                end 
                 
                DATA: begin 
                    uart_tx <= shift_reg[0];   // Send LSB first 
                    if (baud_tick) begin 
                        shift_reg <= shift_reg >> 1;  // Shift right 
                        bit_counter <= bit_counter + 1; 
                    end 
                end 
                 
                PARITY: begin 
                    uart_tx <= parity_bit;     // Send calculated parity 
                end 
                 
                STOP: begin 
                    uart_tx <= 1'b1;          // Send stop bit(s) 
                    if (baud_tick) begin 
                        stop_counter <= stop_counter + 1; 
                    end 
                end 
                 
                default: begin 
                    uart_tx <= 1'b1; 
                    tx_ready <= 1'b1; 
                end 
            endcase 
        end 
    end 
 
endmodule
