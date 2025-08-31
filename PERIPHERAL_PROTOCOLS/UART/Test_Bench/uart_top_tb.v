//============================================================================
// Module: uart_tb.v
// Description: Comprehensive testbench for UART design (Verilog-2001 only)
// Author: Teja Reddy
//============================================================================

`timescale 1ns/1ps

module uart_tb;

    //-------------------------------------------------------------------------
    // Test parameters
    //-------------------------------------------------------------------------
    parameter CLK_PERIOD = 20;                 // 50 MHz clock
    parameter CLK_FREQ   = 50_000_000;
    parameter DATA_BITS  = 8;
    parameter BAUD_RATE  = 9600;
    parameter BIT_PERIOD = 1_000_000_000 / BAUD_RATE; // ns

    //-------------------------------------------------------------------------
    // DUT signals
    //-------------------------------------------------------------------------
    reg                   clk;
    reg                   reset;
    reg      [15:0]       baud_divisor;
    reg                   parity_en;
    reg                   parity_type;         // 0=even, 1=odd
    reg      [1:0]        stop_bits;

    // TX interface
    reg      [DATA_BITS-1:0] tx_data;
    reg                      tx_valid;
    wire                     tx_ready;

    // RX interface
    wire     [DATA_BITS-1:0] rx_data;
    wire                     rx_valid;
    wire                     parity_error;
    wire                     frame_error;
    wire                     overrun_error;

    // UART lines (loopback)
    wire uart_tx;
    wire uart_rx;
    assign uart_rx = uart_tx;

    //-------------------------------------------------------------------------
    // Simple “queues” implemented with fixed arrays + pointers (Verilog-2001)
    //-------------------------------------------------------------------------
    localparam QDEPTH = 1024;

    reg [DATA_BITS-1:0] test_data_queue     [0:QDEPTH-1];
    reg [DATA_BITS-1:0] received_data_queue [0:QDEPTH-1];

    integer test_wr_ptr,  test_rd_ptr;
    integer recv_wr_ptr,  recv_rd_ptr;

    integer test_count;
    integer pass_count;
    integer fail_count;

    //-------------------------------------------------------------------------
    // DUT instantiation
    // (Make sure your uart_top ports/params match these exactly.)
    //-------------------------------------------------------------------------
    uart_top #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE),
        .DATA_BITS (DATA_BITS),
        .PARITY_EN (1),
        .PARITY_TYPE(0),
        .STOP_BITS (1)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .baud_divisor (baud_divisor),
        .parity_en    (parity_en),
        .parity_type  (parity_type),
        .stop_bits    (stop_bits),
        .tx_data      (tx_data),
        .tx_valid     (tx_valid),
        .tx_ready     (tx_ready),
        .rx_data      (rx_data),
        .rx_valid     (rx_valid),
        .parity_error (parity_error),
        .frame_error  (frame_error),
        .overrun_error(overrun_error),
        .uart_tx      (uart_tx),
        .uart_rx      (uart_rx)
    );

    //-------------------------------------------------------------------------
    // Clock
    //-------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // VCD dump
    initial begin
        $dumpfile("uart_test.vcd");
        $dumpvars(0, uart_tb);
    end

    //-------------------------------------------------------------------------
    // Reset
    //-------------------------------------------------------------------------
    initial begin
        reset = 1'b1;
        #(CLK_PERIOD*10);
        reset = 1'b0;
        $display("[%0t] Reset released", $time);
    end

    //-------------------------------------------------------------------------
    // Receive monitor: capture bytes into receive array
    //-------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rx_valid) begin
            if (recv_wr_ptr < QDEPTH) begin
                received_data_queue[recv_wr_ptr] <= rx_data;
                recv_wr_ptr <= recv_wr_ptr + 1;
            end
            $display("[%0t] Received: 0x%02h", $time, rx_data);
            if (parity_error)  $display("[%0t] PARITY ERROR detected!", $time);
            if (frame_error)   $display("[%0t] FRAME ERROR detected!", $time);
            if (overrun_error) $display("[%0t] OVERRUN ERROR detected!", $time);
        end
    end

    //-------------------------------------------------------------------------
    // Tasks (Verilog-2001)
    //-------------------------------------------------------------------------

    // Push expected byte into test-data array
    task push_expected;
        input [DATA_BITS-1:0] d;
        begin
            if (test_wr_ptr < QDEPTH) begin
                test_data_queue[test_wr_ptr] = d;
                test_wr_ptr = test_wr_ptr + 1;
            end
        end
    endtask

    // Pop expected byte (simple pointer advance)
    task pop_expected;
        output [DATA_BITS-1:0] d;
        begin
            d = test_data_queue[test_rd_ptr];
            test_rd_ptr = test_rd_ptr + 1;
        end
    endtask

    // Pop received byte
    task pop_received;
        output [DATA_BITS-1:0] d;
        begin
            d = received_data_queue[recv_rd_ptr];
            recv_rd_ptr = recv_rd_ptr + 1;
        end
    endtask

    // Send one byte over TX
    task send_byte;
        input [7:0] data;
        begin
            $display("[%0t] Sending: 0x%02h", $time, data);
            push_expected(data);

            @(posedge clk);
            tx_data  <= data;
            tx_valid <= 1'b1;

            @(posedge clk);
            // Wait for tx_ready to go low (busy)
            while (tx_ready == 1'b1) @(posedge clk);
            tx_valid <= 1'b0;

            // Wait for tx_ready to return high (idle)
            while (tx_ready == 1'b0) @(posedge clk);
            $display("[%0t] Transmission complete", $time);
        end
    endtask

    // Configure UART
    task configure_uart;
        input [15:0] divisor;
        input        parity_enable;
        input        parity_sel;
        input [1:0]  stop_bit_count;
        begin
            baud_divisor <= divisor;
            parity_en    <= parity_enable;
            parity_type  <= parity_sel;
            stop_bits    <= stop_bit_count;
            #(CLK_PERIOD*5);
            $display("[%0t] UART configured: baud_div=%0d, parity=%0b, type=%0b, stop=%0d",
                     $time, divisor, parity_enable, parity_sel, stop_bit_count);
        end
    endtask

    // Wait for a new reception with timeout (cycles)
    task wait_for_reception;
        input integer timeout_cycles;
        integer wait_count;
        integer start_recv_wr;
        begin
            wait_count     = 0;
            start_recv_wr  = recv_wr_ptr;
            while ((recv_wr_ptr == start_recv_wr) && (wait_count < timeout_cycles)) begin
                @(posedge clk);
                wait_count = wait_count + 1;
            end
            if (wait_count >= timeout_cycles) begin
                $display("[%0t] ERROR: Reception timeout!", $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Verify data (compare expected vs received)
    task verify_data;
        reg [DATA_BITS-1:0] expected_data;
        reg [DATA_BITS-1:0] actual_data;
        begin
            if ((test_rd_ptr < test_wr_ptr) && (recv_rd_ptr < recv_wr_ptr)) begin
                pop_expected(expected_data);
                pop_received(actual_data);
                test_count = test_count + 1;

                if (expected_data == actual_data) begin
                    $display("[%0t] TEST PASS: Expected=0x%02h, Actual=0x%02h",
                              $time, expected_data, actual_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("[%0t] TEST FAIL: Expected=0x%02h, Actual=0x%02h",
                              $time, expected_data, actual_data);
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Main Test Sequence
    //-------------------------------------------------------------------------
    integer i;  // classic Verilog loop variable

    initial begin
        // Initialize bookkeeping
        test_wr_ptr = 0; test_rd_ptr = 0;
        recv_wr_ptr = 0; recv_rd_ptr = 0;

        test_count  = 0;
        pass_count  = 0;
        fail_count  = 0;

        baud_divisor = CLK_FREQ / (BAUD_RATE * 16);
        parity_en    = 1'b0;
        parity_type  = 1'b0;
        stop_bits    = 2'd1;
        tx_data      = {DATA_BITS{1'b0}};
        tx_valid     = 1'b0;

        // Wait for reset to drop
        @(negedge reset);
        #(CLK_PERIOD*10);

        $display("\n========================================");
        $display("Starting UART Verification Tests");
        $display("========================================");

        //--- Test 1: Basic Transmission (No Parity, 1 Stop Bit)
        $display("\n--- Test 1: Basic Transmission ---");
        configure_uart(CLK_FREQ/(BAUD_RATE*16), 1'b0, 1'b0, 2'd1);

        send_byte(8'h55);  wait_for_reception(20000); verify_data();
        send_byte(8'hAA);  wait_for_reception(20000); verify_data();
        send_byte(8'h00);  wait_for_reception(20000); verify_data();
        send_byte(8'hFF);  wait_for_reception(20000); verify_data();

        //--- Test 2: Parity Testing (Even Parity)
        $display("\n--- Test 2: Even Parity Testing ---");
        configure_uart(CLK_FREQ/(BAUD_RATE*16), 1'b1, 1'b0, 2'd1);

        send_byte(8'h0F);  wait_for_reception(20000); verify_data();
        send_byte(8'h07);  wait_for_reception(20000); verify_data();

        //--- Test 3: Parity Testing (Odd Parity)
        $display("\n--- Test 3: Odd Parity Testing ---");
        configure_uart(CLK_FREQ/(BAUD_RATE*16), 1'b1, 1'b1, 2'd1);

        send_byte(8'h0F);  wait_for_reception(20000); verify_data();
        send_byte(8'h07);  wait_for_reception(20000); verify_data();

        //--- Test 4: Two Stop Bits
        $display("\n--- Test 4: Two Stop Bits ---");
        configure_uart(CLK_FREQ/(BAUD_RATE*16), 1'b0, 1'b0, 2'd2);

        send_byte(8'h33);  wait_for_reception(25000); verify_data();
        send_byte(8'hCC);  wait_for_reception(25000); verify_data();

        //--- Test 5: Different Baud Rates
        $display("\n--- Test 5: Different Baud Rates ---");

        // 19200
        configure_uart(CLK_FREQ/(19200*16), 1'b0, 1'b0, 2'd1);
        send_byte(8'h5A);  wait_for_reception(15000); verify_data();

        // 115200
        configure_uart(CLK_FREQ/(115200*16), 1'b0, 1'b0, 2'd1);
        send_byte(8'hA5);  wait_for_reception(5000);  verify_data();

        //--- Test 6: Burst Transmission
        $display("\n--- Test 6: Burst Transmission ---");
        configure_uart(CLK_FREQ/(BAUD_RATE*16), 1'b0, 1'b0, 2'd1);

        for (i = 0; i < 16; i = i + 1) begin
            send_byte(i[7:0]);
            wait_for_reception(20000);
            verify_data();
        end

        // Summary
        #(CLK_PERIOD*100);
        $display("\n========================================");
        $display("UART Verification Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        $display("========================================");

        $finish;
    end

    //-------------------------------------------------------------------------
    // Global simulation timeout (safety net)
    //-------------------------------------------------------------------------
    initial begin
        #10_000_000; // 10 ms
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
