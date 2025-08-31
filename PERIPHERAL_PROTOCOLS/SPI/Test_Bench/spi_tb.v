//=====================================================
// Simplified SPI Testbench (Verilog-2001)
// - Sweeps all 4 modes
// - Talks to 3 slaves
// - Tracks Total/Pass/Fail with summary
// - Author: Teja Reddy
//=====================================================
`timescale 1ns/1ps

module spi_tb;

    // Clock & Reset
    reg clk;
    reg rst_n;

    // Control
    reg        start;
    reg [7:0]  tx_data;
    reg [1:0]  slave_sel;

    // Mode pins
    reg cpol;
    reg cpha;

    // Status/data
    wire [7:0] rx_data;
    wire       done;

    // Clock gen: 100 MHz
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // DUT
    spi_top #(.DATA_WIDTH(8), .CLOCK_DIV(4)) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .tx_data   (tx_data),
        .slave_sel (slave_sel),
        .CPOL      (cpol),
        .CPHA      (cpha),
        .rx_data   (rx_data),
        .done      (done)
    );

    // Wave dump
    initial begin
        $dumpfile("spi.vcd");
        $dumpvars(0, spi_tb);
    end

    // Test counters
    integer total_tests;
    integer pass_count;
    integer fail_count;
    integer i;

    // Test sequence
    initial begin
        // init
        rst_n     = 1'b0;
        start     = 1'b0;
        tx_data   = 8'h00;
        slave_sel = 2'b00;
        cpol      = 1'b0;
        cpha      = 1'b0;

        total_tests = 0;
        pass_count  = 0;
        fail_count  = 0;

        // release reset
        #50 rst_n = 1'b1;

        // Sweep modes
        run_mode(0, 0);
        run_mode(0, 1);
        run_mode(1, 0);
        run_mode(1, 1);

        // Final report
        $display("\n======================================");
        $display(" Test Summary: Total=%0d, Pass=%0d, Fail=%0d",
                  total_tests, pass_count, fail_count);
        $display("======================================\n");

        #50 $finish;
    end

    // Task: run transactions to all 3 slaves in a given mode
    task run_mode;
        input mode_cpol;
        input mode_cpha;
        begin
            cpol = mode_cpol;
            cpha = mode_cpha;

            // small settle
            repeat (4) @(posedge clk);

            $display("\n==============================");
            $display("  Testing CPOL=%0d, CPHA=%0d", cpol, cpha);
            $display("==============================");

            // Three slaves, echo test: expect RX == TX
            for (i = 0; i < 3; i = i + 1) begin
                slave_sel = i[1:0];
                tx_data   = 8'h55 + i; // pattern
                @(posedge clk);
                start = 1'b1;
                @(posedge clk);
                start = 1'b0;

                // wait for done
                wait (done == 1'b1);
                @(posedge clk);

                total_tests = total_tests + 1;

                if (rx_data == tx_data) begin
                    pass_count = pass_count + 1;
                    $display("PASS: Slave%0d TX=0x%02h, RX=0x%02h",
                              i, tx_data, rx_data);
                end else begin
                    fail_count = fail_count + 1;
                    $display("FAIL: Slave%0d TX=0x%02h, RX=0x%02h",
                              i, tx_data, rx_data);
                end

                // small gap
                repeat (6) @(posedge clk);
            end
        end
    endtask

endmodule
