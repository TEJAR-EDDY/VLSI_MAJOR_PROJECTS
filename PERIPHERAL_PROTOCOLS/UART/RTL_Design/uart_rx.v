//============================================================================
// Module: uart_rx.v 
// Description: UART Receiver with oversampling and error detection 
// Author: Teja Reddy
// Date: [Current Date] 
//============================================================================
 
 
module uart_rx #( 
    parameter DATA_BITS = 8,            // Data width (5-8 bits) 
    parameter PARITY_EN = 1,            // Parity enable 
    parameter PARITY_TYPE = 0,          // Parity type (0=even, 1=odd) 
    parameter STOP_BITS = 1             // Number of stop bits 
)( 
    input  wire clk,                    // System clock 
    input  wire reset,                  // Active high reset 
    input  wire baud_x16_tick,          // 16x baud rate tick 
 
 
    input  wire uart_rx,                // UART RX input line 
    input  wire parity_en,              // Runtime parity enable 
    input  wire parity_type,            // Runtime parity type 
    input  wire [1:0] stop_bits,        // Runtime stop bits 
    output reg  [DATA_BITS-1:0] rx_data,// Received data 
    output reg  rx_valid,               // Data valid signal 
    output reg  parity_error,           // Parity error flag 
    output reg  frame_error,            // Frame error flag 
    output reg  overrun_error           // Overrun error flag 
); 
 
    // FSM States 
    localparam IDLE       = 3'b000; 
    localparam START      = 3'b001; 
    localparam DATA       = 3'b010; 
    localparam PARITY     = 3'b011; 
    localparam STOP       = 3'b100; 
    localparam DATA_VALID = 3'b101; 
 
    // Internal registers 
    reg [2:0] state, next_state; 
    reg [DATA_BITS-1:0] shift_reg;      // Data shift register 
    reg [3:0] sample_counter;           // 16x oversampling counter 
    reg [3:0] bit_counter;              // Data bit counter 
    reg [1:0] stop_counter;             // Stop bit counter 
    reg [2:0] rx_sync;                  // Synchronizer for RX input 
    reg calculated_parity;              // Expected parity 
    reg received_parity;                // Received parity bit 
     
    // Input synchronization 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            rx_sync <= 3'b111; 
        end 
        else begin 
            rx_sync <= {rx_sync[1:0], uart_rx}; 
        end 
    end 
     
    wire rx_negedge = (rx_sync[2:1] == 2'b10);  // Falling edge detection 
     
    // Parity calculation 
    always @(*) begin 
        if (parity_type == 0) begin 
            // Even parity 
            calculated_parity = ^shift_reg; 
        end 
        else begin 
            // Odd parity 
            calculated_parity = ~(^shift_reg); 
 
 
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
                if (rx_negedge) 
                    next_state = START; 
                else 
                    next_state = IDLE; 
            end 
             
            START: begin 
                if (baud_x16_tick && (sample_counter >= 7)) begin 
                    if (rx_sync[0] == 1'b0)  // Valid start bit 
                        next_state = DATA; 
                    else 
                        next_state = IDLE;   // False start 
                end 
                else 
                    next_state = START; 
            end 
             
            DATA: begin 
                if (baud_x16_tick && (sample_counter >= 15) &&  
                    (bit_counter >= DATA_BITS - 1)) begin 
                    if (parity_en) 
                        next_state = PARITY; 
                    else 
                        next_state = STOP; 
                end 
                else 
                    next_state = DATA; 
            end 
             
            PARITY: begin 
                if (baud_x16_tick && (sample_counter >= 15)) 
                    next_state = STOP; 
                else 
 
 
                    next_state = PARITY; 
            end 
             
            STOP: begin 
                if (baud_x16_tick && (sample_counter >= 15) &&  
                    (stop_counter >= stop_bits - 1)) 
                    next_state = DATA_VALID; 
                else 
                    next_state = STOP; 
            end 
             
            DATA_VALID: begin 
                next_state = IDLE; 
            end 
             
            default: next_state = IDLE; 
        endcase 
    end 
 
    // FSM Output Logic and Data Handling 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            rx_data       <= 0; 
            rx_valid      <= 1'b0; 
            parity_error  <= 1'b0; 
            frame_error   <= 1'b0; 
            overrun_error <= 1'b0; 
            shift_reg     <= 0; 
            sample_counter<= 0; 
            bit_counter   <= 0; 
            stop_counter  <= 0; 
            received_parity <= 1'b0; 
        end 
        else begin 
            // Clear single-cycle signals 
            rx_valid <= 1'b0; 
             
            case (state) 
                IDLE: begin 
                    sample_counter <= 0; 
                    bit_counter <= 0; 
                    stop_counter <= 0; 
                    parity_error <= 1'b0; 
                    frame_error <= 1'b0; 
                     
                    if (rx_valid && !rx_sync[0]) begin 
                        overrun_error <= 1'b1;  // Data not read before new frame 
                    end 
                    else begin 
                        overrun_error <= 1'b0; 
 
 
                    end 
                end 
                 
                START: begin 
                    if (baud_x16_tick) begin 
                        sample_counter <= sample_counter + 1; 
                    end 
                end 
                 
                DATA: begin 
                    if (baud_x16_tick) begin 
                        if (sample_counter >= 15) begin 
                            // Sample at center of bit period 
                            shift_reg <= {rx_sync[0], shift_reg[DATA_BITS-1:1]}; 
                            bit_counter <= bit_counter + 1; 
                            sample_counter <= 0; 
                        end 
                        else begin 
                            sample_counter <= sample_counter + 1; 
                        end 
                    end 
                end 
                 
                PARITY: begin 
                    if (baud_x16_tick) begin 
                        if (sample_counter >= 15) begin 
                            received_parity <= rx_sync[0]; 
                            sample_counter <= 0; 
                            if (received_parity != calculated_parity) 
                                parity_error <= 1'b1; 
                        end 
                        else begin 
                            sample_counter <= sample_counter + 1; 
                        end 
                    end 
                end 
                 
                STOP: begin 
                    if (baud_x16_tick) begin 
                        if (sample_counter >= 15) begin 
                            if (rx_sync[0] != 1'b1) 
                                frame_error <= 1'b1; 
                            stop_counter <= stop_counter + 1; 
                            sample_counter <= 0; 
                        end 
                        else begin 
                            sample_counter <= sample_counter + 1; 
                        end 
                    end 
                end 
 
 
                 
                DATA_VALID: begin 
                    rx_data  <= shift_reg; 
                    rx_valid <= 1'b1; 
                end 
            endcase 
        end 
    end 
endmodule
