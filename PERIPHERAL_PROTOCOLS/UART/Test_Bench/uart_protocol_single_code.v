//------------------------------------------------------------------------------
// UART TOP MODULE
// Author: Teja Reddy
//------------------------------------------------------------------------------
module uart_top #(
    // Parameters matching your testbench
    parameter CLK_FREQ = 50_000_000,     // System clock frequency (Hz)
    parameter BAUD_RATE = 9600,          // Baud rate for testbench compatibility
    parameter DATA_BITS = 8,             // Data width for testbench compatibility
    parameter PARITY_EN = 1'b0,          // Parity enable for testbench compatibility
    parameter PARITY_TYPE = 1'b0,        // Parity type for testbench compatibility
    parameter STOP_BITS = 2'd1,          // Stop bits for testbench compatibility
    parameter DEFAULT_BAUD = 9600,       // Default baud rate
    parameter DATA_WIDTH = 8,            // Data width (5–8 bits)
    parameter DEFAULT_PARITY_EN = 1'b0,  // Default: parity disabled
    parameter DEFAULT_PARITY_ODD = 1'b0, // Default: even parity
    parameter DEFAULT_STOP_BITS = 2'd1   // Default: 1 stop bit
)(
    // System Interface
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    enable,
    // Configuration
    input  wire [15:0]             baud_divisor,
    input  wire                    parity_en,
    input  wire                    parity_odd,
    input  wire [1:0]              stop_bits,
    // Transmitter Interface
    input  wire [DATA_WIDTH-1:0]   tx_data,
    input  wire                    tx_start,
    output wire                    tx_busy,
    output wire                    tx_done,
    // Receiver Interface
    output wire [DATA_WIDTH-1:0]   rx_data,
    output wire                    rx_valid,
    output wire                    rx_busy,
    // Error Flags
    output wire                    parity_error,
    output wire                    frame_error,
    output wire                    overrun_error,
    // Physical UART I/O
    output wire                    uart_tx,
    input  wire                    uart_rx
);

    // Internal Signals
    wire baud_tick;
    wire baud_x16_tick;

    //=================================================================
    // Baud Rate Generator
    //=================================================================
    baud_gen #(
        .CLK_FREQ    (CLK_FREQ),
        .DEFAULT_BAUD(DEFAULT_BAUD)
    ) u_baud_gen (
        .clk         (clk),
        .reset       (reset),
        .baud_divisor(baud_divisor),
        .enable      (enable),
        .baud_tick   (baud_tick),
        .baud_x16_tick(baud_x16_tick)
    );

    //=================================================================
    // Transmitter
    //=================================================================
    uart_tx #(
        .DATA_WIDTH (DATA_WIDTH),
        .PARITY_EN  (DEFAULT_PARITY_EN),
        .PARITY_ODD (DEFAULT_PARITY_ODD),
        .STOP_BITS  (DEFAULT_STOP_BITS)
    ) u_uart_tx (
        .clk        (clk),
        .reset      (reset),
        .baud_tick  (baud_tick),
        .enable     (enable),
        .parity_en  (parity_en),
        .parity_odd (parity_odd),
        .stop_bits  (stop_bits),
        .tx_data    (tx_data),
        .tx_start   (tx_start),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .uart_tx    (uart_tx)
    );

    //=================================================================
    // Receiver
    //=================================================================
    uart_rx #(
        .DATA_WIDTH (DATA_WIDTH),
        .PARITY_EN  (DEFAULT_PARITY_EN),
        .PARITY_ODD (DEFAULT_PARITY_ODD),
        .STOP_BITS  (DEFAULT_STOP_BITS)
    ) u_uart_rx (
        .clk          (clk),
        .reset        (reset),
        .baud_x16_tick(baud_x16_tick),
        .enable       (enable),
        .parity_en    (parity_en),
        .parity_odd   (parity_odd),
        .stop_bits    (stop_bits),
        .uart_rx      (uart_rx),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_busy      (rx_busy),
        .parity_error (parity_error),
        .frame_error  (frame_error),
        .overrun_error(overrun_error)
    );

endmodule

//------------------------------------------------------------------------------
// 5. COMPREHENSIVE TESTBENCH
//------------------------------------------------------------------------------
module uart_tb;

    // Testbench Parameters
    parameter CLK_PERIOD = 20;           // 50MHz clock
    parameter BAUD_RATE = 115200;        // High speed for faster simulation
    parameter DATA_BITS = 8;
    parameter PARITY_EN = 1'b0;
    parameter PARITY_TYPE = 1'b0;
    parameter STOP_BITS = 2'd1;
    
    // Calculate baud divisor
    localparam BAUD_DIVISOR = 50_000_000 / BAUD_RATE;

    // Testbench Signals
    reg                    clk;
    reg                    reset;
    reg                    enable;
    reg [15:0]             baud_divisor;
    reg                    parity_en;
    reg                    parity_odd;
    reg [1:0]              stop_bits;
    reg [DATA_BITS-1:0]    tx_data;
    reg                    tx_start;
    wire                   tx_busy;
    wire                   tx_done;
    wire [DATA_BITS-1:0]   rx_data;
    wire                   rx_valid;
    wire                   rx_busy;
    wire                   parity_error;
    wire                   frame_error;
    wire                   overrun_error;
    wire                   uart_tx;
    reg                    uart_rx;

    // Test variables
    reg [DATA_BITS-1:0] test_data;
    reg [DATA_BITS-1:0] received_data;
    integer test_count;
    integer pass_count;
    integer fail_count;

    //=================================================================
    // DUT Instantiation
    //=================================================================
    uart_top #(
        .CLK_FREQ    (50_000_000),
        .BAUD_RATE   (BAUD_RATE),
        .DATA_BITS   (DATA_BITS),
        .PARITY_EN   (PARITY_EN),
        .PARITY_TYPE (PARITY_TYPE),
        .STOP_BITS   (STOP_BITS),
        .DEFAULT_BAUD(BAUD_RATE),
        .DATA_WIDTH  (DATA_BITS)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .enable       (enable),
        .baud_divisor (baud_divisor),
        .parity_en    (parity_en),
        .parity_odd   (parity_odd),
        .stop_bits    (stop_bits),
        .tx_data      (tx_data),
        .tx_start     (tx_start),
        .tx_busy      (tx_busy),
        .tx_done      (tx_done),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .rx_busy      (rx_busy),
        .parity_error (parity_error),
        .frame_error  (frame_error),
        .overrun_error(overrun_error),
        .uart_tx      (uart_tx),
        .uart_rx      (uart_rx)
    );

    //=================================================================
    // Clock Generation
    //=================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //=================================================================
    // Test Stimulus
    //=================================================================
    initial begin
        // Initialize signals
        reset        = 1;
        enable       = 0;
        baud_divisor = BAUD_DIVISOR;
        parity_en    = 0;
        parity_odd   = 0;
        stop_bits    = 1;
        tx_data      = 0;
        tx_start     = 0;
        uart_rx      = 1; // Idle high
        test_count   = 0;
        pass_count   = 0;
        fail_count   = 0;

        // Reset sequence
        #(CLK_PERIOD * 10);
        reset = 0;
        #(CLK_PERIOD * 5);
        enable = 1;
        
        $display("=== UART Testbench Started ===");
        $display("Clock Frequency: %0d Hz", 50_000_000);
        $display("Baud Rate: %0d bps", BAUD_RATE);
        $display("Baud Divisor: %0d", BAUD_DIVISOR);

        // Test 1: Basic transmission without parity
        $display("\n--- Test 1: Basic Transmission (No Parity) ---");
        test_transmission(8'h55, 0, 0, 1);
        
        // Test 2: Transmission with even parity
        $display("\n--- Test 2: Even Parity Transmission ---");
        test_transmission(8'hAA, 1, 0, 1);
        
        // Test 3: Transmission with odd parity
        $display("\n--- Test 3: Odd Parity Transmission ---");
        test_transmission(8'h0F, 1, 1, 1);
        
        // Test 4: Two stop bits
        $display("\n--- Test 4: Two Stop Bits ---");
        test_transmission(8'hCC, 0, 0, 2);
        
        // Test 5: Loopback test
        $display("\n--- Test 5: Loopback Test ---");
        loopback_test();
        
        // Test 6: Error injection tests
        $display("\n--- Test 6: Error Detection Tests ---");
        error_injection_tests();

        // Final results
        $display("\n=== Test Summary ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", fail_count);
        end

        #(CLK_PERIOD * 100);
        $finish;
    end

    //=================================================================
    // Test Tasks
    //=================================================================
    
    // Task to test transmission with various configurations
    task test_transmission(
        input [7:0] data,
        input parity_enable,
        input parity_type,
        input [1:0] stop_bit_count
    );
        begin
            test_count = test_count + 1;
            
            // Configure UART
            parity_en = parity_enable;
            parity_odd = parity_type;
            stop_bits = stop_bit_count;
            
            // Start transmission
            tx_data = data;
            #(CLK_PERIOD);
            tx_start = 1;
            #(CLK_PERIOD);
            tx_start = 0;
            
            // Wait for transmission to complete
            wait(tx_done);
            #(CLK_PERIOD * 10);
            
            $display("Transmitted: 0x%02h, Parity: %s, Stop Bits: %0d", 
                    data, 
                    parity_enable ? (parity_type ? "Odd" : "Even") : "None",
                    stop_bit_count);
            
            pass_count = pass_count + 1;
        end
    endtask
    
    // Loopback test task
    task loopback_test();
        begin
            test_count = test_count + 1;
            
            // Connect TX to RX for loopback
            force uart_rx = uart_tx;
            
            // Configure for no parity, 1 stop bit
            parity_en = 0;
            parity_odd = 0;
            stop_bits = 1;
            
            // Test data
            test_data = 8'h96;
            tx_data = test_data;
            
            // Start transmission
            #(CLK_PERIOD);
            tx_start = 1;
            #(CLK_PERIOD);
            tx_start = 0;
            
            // Wait for reception
            wait(rx_valid);
            received_data = rx_data;
            
            // Release loopback connection
            release uart_rx;
            uart_rx = 1;
            
            // Check results
            if (received_data == test_data) begin
                $display("Loopback Test PASSED: Sent=0x%02h, Received=0x%02h", 
                        test_data, received_data);
                pass_count = pass_count + 1;
            end else begin
                $display("Loopback Test FAILED: Sent=0x%02h, Received=0x%02h", 
                        test_data, received_data);
                fail_count = fail_count + 1;
            end
        end
    endtask
    
    // Error injection tests
    task error_injection_tests();
        begin
            // Frame error test
            test_count = test_count + 1;
            $display("Testing Frame Error Detection...");
            
            parity_en = 0;
            stop_bits = 1;
            
            // Manually create a frame with wrong stop bit
            uart_rx = 1; // Idle
            #(CLK_PERIOD * 100);
            
            // Start bit
            uart_rx = 0;
            #(CLK_PERIOD * BAUD_DIVISOR);
            
            // Data bits (0x55 = 01010101)
            uart_rx = 1; #(CLK_PERIOD * BAUD_DIVISOR); // bit 0
            uart_rx = 0; #(CLK_PERIOD * BAUD_DIVISOR); // bit 1
            uart_rx = 1; #(CLK_PERIOD * BAUD_DIVISOR); // bit 2
            uart_rx = 0; #(CLK_PERIOD * BAUD_DIVISOR); // bit 3
            uart_rx = 1; #(CLK_PERIOD * BAUD_DIVISOR); // bit 4
            uart_rx = 0; #(CLK_PERIOD * BAUD_DIVISOR); // bit 5
            uart_rx = 1; #(CLK_PERIOD * BAUD_DIVISOR); // bit 6
            uart_rx = 0; #(CLK_PERIOD * BAUD_DIVISOR); // bit 7
            
            // Wrong stop bit (should be 1, but we send 0)
            uart_rx = 0; #(CLK_PERIOD * BAUD_DIVISOR);
            
            // Return to idle
            uart_rx = 1;
            #(CLK_PERIOD * 100);
            
            if (frame_error) begin
                $display("Frame Error Test PASSED - Error detected");
                pass_count = pass_count + 1;
            end else begin
                $display("Frame Error Test FAILED - Error not detected");
                fail_count = fail_count + 1;
            end
        end
    endtask

    //=================================================================
    // Waveform Generation
    //=================================================================
    initial begin
        $dumpfile("uart_test.vcd");
        $dumpvars(0, uart_tb);
    end

    //=================================================================
    // Monitoring
    //=================================================================
    always @(posedge clk) begin
        if (tx_done) begin
            $display("Time %0t: Transmission completed", $time);
        end
        
        if (rx_valid) begin
            $display("Time %0t: Received data: 0x%02h", $time, rx_data);
        end
        
        if (parity_error) begin
            $display("Time %0t: PARITY ERROR detected", $time);
        end
        
        if (frame_error) begin
            $display("Time %0t: FRAME ERROR detected", $time);
        end
        
        if (overrun_error) begin
            $display("Time %0t: OVERRUN ERROR detected", $time);
        end
    end

endmodule//==============================================================================
// UART Protocol Implementation - Complete Verilog RTL Design
// Author: [Your Name]
// Date: August 2025
// Description: Full-featured UART with configurable parameters
//==============================================================================

//------------------------------------------------------------------------------
// 1. BAUD RATE GENERATOR MODULE
//------------------------------------------------------------------------------
module baud_gen #(
    parameter CLK_FREQ = 50_000_000,  // System clock frequency
    parameter DEFAULT_BAUD = 9600     // Default baud rate
)(
    input  wire        clk,           // System clock
    input  wire        reset,         // Active high reset
    input  wire [15:0] baud_divisor,  // Baud divisor input
    input  wire        enable,        // Enable signal
    output reg         baud_tick,     // Baud rate tick output
    output reg         baud_x16_tick  // 16x baud rate tick for RX
);

    reg [15:0] counter;
    reg [15:0] counter_x16;
    
    always @(posedge clk) begin
        if (reset || !enable) begin
            counter     <= 0;
            counter_x16 <= 0;
            baud_tick   <= 1'b0;
            baud_x16_tick <= 1'b0;
        end else begin
            // Baud tick generation
            if (counter >= baud_divisor - 1) begin
                counter   <= 0;
                baud_tick <= 1'b1;
            end else begin
                counter   <= counter + 1;
                baud_tick <= 1'b0;
            end
            
            // 16x baud tick generation for receiver
            if (counter_x16 >= (baud_divisor >> 4) - 1) begin
                counter_x16   <= 0;
                baud_x16_tick <= 1'b1;
            end else begin
                counter_x16   <= counter_x16 + 1;
                baud_x16_tick <= 1'b0;
            end
        end
    end

endmodule

//------------------------------------------------------------------------------
// 2. UART TRANSMITTER MODULE
//------------------------------------------------------------------------------
module uart_tx #(
    parameter DATA_WIDTH = 8,        // Data width (5-8 bits)
    parameter PARITY_EN = 1'b0,      // Default: parity disabled
    parameter PARITY_ODD = 1'b0,     // Default: even parity
    parameter STOP_BITS = 2'd1       // Default: 1 stop bit
)(
    input  wire                    clk,         // System clock
    input  wire                    reset,       // Active high reset
    input  wire                    baud_tick,   // Baud rate tick
    input  wire                    enable,      // Enable signal
    input  wire                    parity_en,   // Enable parity (runtime)
    input  wire                    parity_odd,  // Parity type (runtime)
    input  wire [1:0]              stop_bits,   // Stop bits (runtime)
    input  wire [DATA_WIDTH-1:0]   tx_data,     // Data to transmit
    input  wire                    tx_start,    // Start transmission
    output reg                     tx_busy,     // Transmitter busy flag
    output reg                     tx_done,     // Transmission complete
    output reg                     uart_tx      // Serial output
);

    // FSM States
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP   = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] bit_counter;              // Bit counter
    reg [DATA_WIDTH-1:0] shift_reg;     // Data shift register
    reg parity_bit;                     // Calculated parity bit
    reg [1:0] stop_counter;             // Stop bit counter

    // Parity calculation
    always @(*) begin
        parity_bit = ^shift_reg; // XOR reduction for even parity
        if (parity_odd) // Odd parity
            parity_bit = ~parity_bit;
    end

    // FSM Sequential Logic
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Combinational Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (tx_start && enable)
                    next_state = START;
            end
            
            START: begin
                if (baud_tick)
                    next_state = DATA;
            end
            
            DATA: begin
                if (baud_tick && bit_counter == DATA_WIDTH - 1) begin
                    if (parity_en)
                        next_state = PARITY;
                    else
                        next_state = STOP;
                end
            end
            
            PARITY: begin
                if (baud_tick)
                    next_state = STOP;
            end
            
            STOP: begin
                if (baud_tick) begin
                    if (stop_bits == 2'd2 && stop_counter == 0)
                        next_state = STOP; // Stay for 2nd stop bit
                    else
                        next_state = IDLE;
                end
            end
        endcase
    end

    // Output Logic and Registers
    always @(posedge clk) begin
        if (reset) begin
            uart_tx      <= 1'b1;  // Idle high
            tx_busy      <= 1'b0;
            tx_done      <= 1'b0;
            bit_counter  <= 0;
            shift_reg    <= 0;
            stop_counter <= 0;
        end else begin
            tx_done <= 1'b0; // Pulse signal
            
            case (state)
                IDLE: begin
                    uart_tx  <= 1'b1;
                    tx_busy  <= 1'b0;
                    if (tx_start && enable) begin
                        tx_busy      <= 1'b1;
                        shift_reg    <= tx_data;
                        bit_counter  <= 0;
                        stop_counter <= 0;
                    end
                end
                
                START: begin
                    uart_tx <= 1'b0; // Start bit
                end
                
                DATA: begin
                    uart_tx <= shift_reg[0];
                    if (baud_tick) begin
                        shift_reg   <= {1'b0, shift_reg[DATA_WIDTH-1:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                
                PARITY: begin
                    uart_tx <= parity_bit;
                end
                
                STOP: begin
                    uart_tx <= 1'b1; // Stop bit
                    if (baud_tick) begin
                        if (stop_bits == 2'd2 && stop_counter == 0) begin
                            stop_counter <= stop_counter + 1;
                        end else begin
                            tx_busy <= 1'b0;
                            tx_done <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule

//------------------------------------------------------------------------------
// 3. UART RECEIVER MODULE
//------------------------------------------------------------------------------
module uart_rx #(
    parameter DATA_WIDTH = 8,        // Data width (5-8 bits)
    parameter PARITY_EN = 1'b0,      // Default: parity disabled
    parameter PARITY_ODD = 1'b0,     // Default: even parity
    parameter STOP_BITS = 2'd1       // Default: 1 stop bit
)(
    input  wire                    clk,           // System clock
    input  wire                    reset,         // Active high reset
    input  wire                    baud_x16_tick, // 16x baud rate tick
    input  wire                    enable,        // Enable signal
    input  wire                    parity_en,     // Enable parity (runtime)
    input  wire                    parity_odd,    // Parity type (runtime)
    input  wire [1:0]              stop_bits,     // Stop bits (runtime)
    input  wire                    uart_rx,       // Serial input
    output reg  [DATA_WIDTH-1:0]   rx_data,       // Received data
    output reg                     rx_valid,      // Data valid flag
    output reg                     rx_busy,       // Receiver busy flag
    output reg                     parity_error,  // Parity error flag
    output reg                     frame_error,   // Frame error flag
    output reg                     overrun_error  // Overrun error flag
);

    // FSM States
    localparam IDLE   = 3'b000;
    localparam START  = 3'b001;
    localparam DATA   = 3'b010;
    localparam PARITY = 3'b011;
    localparam STOP   = 3'b100;

    reg [2:0] state, next_state;
    reg [4:0] sample_counter;           // Sampling counter (0-15)
    reg [3:0] bit_counter;              // Bit counter
    reg [DATA_WIDTH-1:0] shift_reg;     // Data shift register
    reg expected_parity;                // Expected parity
    reg [1:0] stop_counter;             // Stop bit counter
    reg rx_sync1, rx_sync2;             // RX synchronizers
    reg start_detected;                 // Start bit detection flag

    // Input synchronization
    always @(posedge clk) begin
        if (reset) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= uart_rx;
            rx_sync2 <= rx_sync1;
        end
    end

    // Start bit detection
    always @(posedge clk) begin
        if (reset) begin
            start_detected <= 1'b0;
        end else begin
            if (state == IDLE && !rx_sync2)
                start_detected <= 1'b1;
            else if (state != IDLE)
                start_detected <= 1'b0;
        end
    end

    // Expected parity calculation
    always @(*) begin
        expected_parity = ^shift_reg; // XOR reduction for even parity
        if (parity_odd) // Odd parity
            expected_parity = ~expected_parity;
    end

    // FSM Sequential Logic
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Combinational Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_detected && enable)
                    next_state = START;
            end
            
            START: begin
                if (baud_x16_tick && sample_counter == 7) begin // Sample at middle
                    if (!rx_sync2) // Valid start bit
                        next_state = DATA;
                    else
                        next_state = IDLE; // False start
                end
            end
            
            DATA: begin
                if (baud_x16_tick && sample_counter == 15 && 
                    bit_counter == DATA_WIDTH - 1) begin
                    if (parity_en)
                        next_state = PARITY;
                    else
                        next_state = STOP;
                end
            end
            
            PARITY: begin
                if (baud_x16_tick && sample_counter == 15)
                    next_state = STOP;
            end
            
            STOP: begin
                if (baud_x16_tick && sample_counter == 15) begin
                    if (stop_bits == 2'd2 && stop_counter == 0)
                        next_state = STOP; // Stay for 2nd stop bit
                    else
                        next_state = IDLE;
                end
            end
        endcase
    end

    // Output Logic and Registers
    always @(posedge clk) begin
        if (reset) begin
            rx_data       <= 0;
            rx_valid      <= 1'b0;
            rx_busy       <= 1'b0;
            parity_error  <= 1'b0;
            frame_error   <= 1'b0;
            overrun_error <= 1'b0;
            sample_counter <= 0;
            bit_counter   <= 0;
            shift_reg     <= 0;
            stop_counter  <= 0;
        end else begin
            // Clear pulse signals
            rx_valid     <= 1'b0;
            parity_error <= 1'b0;
            frame_error  <= 1'b0;
            
            // Check for overrun
            if (rx_valid && state != IDLE) begin
                overrun_error <= 1'b1;
            end else begin
                overrun_error <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    rx_busy        <= 1'b0;
                    sample_counter <= 0;
                    bit_counter    <= 0;
                    stop_counter   <= 0;
                    if (start_detected && enable) begin
                        rx_busy <= 1'b1;
                    end
                end
                
                START: begin
                    if (baud_x16_tick) begin
                        if (sample_counter == 15) begin
                            sample_counter <= 0;
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                end
                
                DATA: begin
                    if (baud_x16_tick) begin
                        if (sample_counter == 7) begin // Sample at middle
                            shift_reg <= {rx_sync2, shift_reg[DATA_WIDTH-1:1]};
                        end
                        
                        if (sample_counter == 15) begin
                            sample_counter <= 0;
                            bit_counter <= bit_counter + 1;
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                end
                
                PARITY: begin
                    if (baud_x16_tick) begin
                        if (sample_counter == 7) begin // Check parity at middle
                            if (rx_sync2 != expected_parity)
                                parity_error <= 1'b1;
                        end
                        
                        if (sample_counter == 15) begin
                            sample_counter <= 0;
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                end
                
                STOP: begin
                    if (baud_x16_tick) begin
                        if (sample_counter == 7) begin // Check stop bit
                            if (!rx_sync2)
                                frame_error <= 1'b1;
                        end
                        
                        if (sample_counter == 15) begin
                            sample_counter <= 0;
                            if (stop_bits == 2'd2 && stop_counter == 0) begin
                                stop_counter <= stop_counter + 1;
                            end else begin
                                rx_busy  <= 1'b0;
                                rx_valid <= 1'b1;
                                rx_data  <= shift_reg;
                            end
                        end else begin
                            sample_counter <= sample_counter + 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule