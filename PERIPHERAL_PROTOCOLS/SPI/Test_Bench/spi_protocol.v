//=====================================================
// SPI Master (Verilog-2001)
// - Parameterized DATA_WIDTH
// - 3-slave ready (slave_sel is 2 bits)
// - Runs all 4 modes via CPOL/CPHA inputs
// - Author: Teja Reddy
//=====================================================
module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLOCK_DIV  = 4   // must be even and >=2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // control
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [1:0]            slave_sel,
    input  wire                  CPOL,
    input  wire                  CPHA,

    // status/data
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   done,

    // SPI bus
    output reg                   sclk,
    output reg                   mosi,
    input  wire                  miso,
    output reg  [2:0]            cs_n
);

    // prescaler
    reg [15:0] div_cnt;
    wire tick = (div_cnt == (CLOCK_DIV-1));
    reg active;

    // shifting
    reg [DATA_WIDTH-1:0] sh_tx;
    reg [DATA_WIDTH-1:0] sh_rx;
    reg [3:0]            sample_cnt; // up to 16 bits

    // prescale & SCLK toggle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 0;
            sclk    <= 1'b0;
        end else if (active) begin
            if (div_cnt == (CLOCK_DIV-1)) begin
                div_cnt <= 0;
                sclk    <= ~sclk;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt <= 0;
            sclk    <= CPOL; // idle level
        end
    end

    // main control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active     <= 1'b0;
            done       <= 1'b0;
            cs_n       <= 3'b111;
            mosi       <= 1'b0;
            rx_data    <= {DATA_WIDTH{1'b0}};
            sh_tx      <= {DATA_WIDTH{1'b0}};
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
        end else begin
            done <= 1'b0;

            // start of a new transaction
            if (start && !active) begin
                active     <= 1'b1;
                cs_n       <= 3'b111;
                cs_n[slave_sel] <= 1'b0;  // select slave
                sh_tx      <= tx_data;
                sh_rx      <= {DATA_WIDTH{1'b0}};
                sample_cnt <= 4'd0;
                mosi       <= (CPHA == 1'b0) ? tx_data[DATA_WIDTH-1] : mosi; // preload for CPHA=0
            end

            if (active && tick) begin
                // Decide which edge we are about to produce:
                // before toggle, if sclk == CPOL, next edge is leading; else trailing
                // (since we flip sclk after this block)
                if (sclk == CPOL) begin
                    // LEADING edge next
                    if (CPHA == 1'b0) begin
                        // CPHA=0: sample on leading
                        sh_rx      <= {sh_rx[DATA_WIDTH-2:0], miso};
                        sample_cnt <= sample_cnt + 1'b1;

                        if (sample_cnt == (DATA_WIDTH-1)) begin
                            // last sample completes the frame
                            rx_data <= {sh_rx[DATA_WIDTH-2:0], miso};
                            active  <= 1'b0;
                            cs_n    <= 3'b111;
                            done    <= 1'b1;
                        end
                    end else begin
                        // CPHA=1: drive on leading
                        mosi  <= sh_tx[DATA_WIDTH-1];
                        sh_tx <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                    end
                end else begin
                    // TRAILING edge next
                    if (CPHA == 1'b0) begin
                        // CPHA=0: drive on trailing
                        mosi  <= sh_tx[DATA_WIDTH-2]; // next bit after shift below
                        sh_tx <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                    end else begin
                        // CPHA=1: sample on trailing
                        sh_rx      <= {sh_rx[DATA_WIDTH-2:0], miso};
                        sample_cnt <= sample_cnt + 1'b1;

                        if (sample_cnt == (DATA_WIDTH-1)) begin
                            rx_data <= {sh_rx[DATA_WIDTH-2:0], miso};
                            active  <= 1'b0;
                            cs_n    <= 3'b111;
                            done    <= 1'b1;
                        end
                    end
                end
            end
        end
    end
endmodule

//=====================================================
// SPI Slave (Verilog-2001)
// - Echo slave: drives back its tx_data
// - Tri-states MISO when CS_n=1
// - Correct CPOL/CPHA handling
// - Author: Teja Reddy
//=====================================================
module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    output wire                  miso,      // tri-stated when not selected
    input  wire [DATA_WIDTH-1:0] tx_data,
    output reg  [DATA_WIDTH-1:0] rx_data,
    input  wire                  CPOL,
    input  wire                  CPHA
);

    reg [DATA_WIDTH-1:0] sh_tx;
    reg [DATA_WIDTH-1:0] sh_rx;
    reg [3:0]            sample_cnt;
    reg                  miso_drv;

    assign miso = cs_n ? 1'bz : miso_drv;

    // Load/prepare on select
    always @(negedge cs_n or posedge cs_n) begin
        if (cs_n) begin
            // deselect
            sh_tx      <= {DATA_WIDTH{1'b0}};
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
            miso_drv   <= 1'b0;
        end else begin
            // select
            sh_tx      <= tx_data;
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
            // For CPHA=0, the first output bit must be present before first leading edge
            if (CPHA == 1'b0) begin
                miso_drv <= tx_data[DATA_WIDTH-1];
            end
        end
    end

    // At SCLK positive edge
    always @(posedge sclk) begin
        if (!cs_n) begin
            // Which kind of edge is this?
            if (CPOL == 1'b0) begin
                // posedge is LEADING
                if (CPHA == 1'b0) begin
                    // sample on leading
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end else begin
                    // CPHA=1: drive on leading
                    miso_drv <= sh_tx[DATA_WIDTH-1];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end
            end else begin
                // CPOL=1: posedge is TRAILING
                if (CPHA == 1'b0) begin
                    // CPHA=0: drive on trailing
                    miso_drv <= sh_tx[DATA_WIDTH-2];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end else begin
                    // CPHA=1: sample on trailing
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end
            end
        end
    end

    // At SCLK negative edge
    always @(negedge sclk) begin
        if (!cs_n) begin
            if (CPOL == 1'b0) begin
                // negedge is TRAILING
                if (CPHA == 1'b0) begin
                    // CPHA=0: drive on trailing
                    miso_drv <= sh_tx[DATA_WIDTH-2];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end else begin
                    // CPHA=1: sample on trailing
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end
            end else begin
                // CPOL=1: negedge is LEADING
                if (CPHA == 1'b0) begin
                    // CPHA=0: sample on leading
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end else begin
                    // CPHA=1: drive on leading
                    miso_drv <= sh_tx[DATA_WIDTH-1];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end
            end
        end
    end

endmodule

//=====================================================
// SPI Top (Verilog-2001)
// - 3 slaves
// - Slaves echo master's TX byte (wired)
// - Author: Teja Reddy
//=====================================================
module spi_top #(
    parameter DATA_WIDTH = 8,
    parameter CLOCK_DIV  = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [1:0]            slave_sel,
    input  wire                  CPOL,
    input  wire                  CPHA,
    output wire [DATA_WIDTH-1:0] rx_data,
    output wire                  done
);

    wire sclk, mosi;
    wire [2:0] cs_n;
    wire [2:0] miso_w;
    wire miso;

    // Only active slave drives MISO; else high-Z
    assign miso = (cs_n[0] == 1'b0) ? miso_w[0] :
                  (cs_n[1] == 1'b0) ? miso_w[1] :
                  (cs_n[2] == 1'b0) ? miso_w[2] : 1'bz;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_DIV (CLOCK_DIV)
    ) u_spi_master (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .tx_data  (tx_data),
        .slave_sel(slave_sel),
        .CPOL     (CPOL),
        .CPHA     (CPHA),
        .rx_data  (rx_data),
        .done     (done),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso),
        .cs_n     (cs_n)
    );

    // All slaves get same tx_data (echo design)
    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s0 (
        .sclk(sclk), .cs_n(cs_n[0]), .mosi(mosi),
        .miso(miso_w[0]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s1 (
        .sclk(sclk), .cs_n(cs_n[1]), .mosi(mosi),
        .miso(miso_w[1]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s2 (
        .sclk(sclk), .cs_n(cs_n[2]), .mosi(mosi),
        .miso(miso_w[2]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

endmodule

//=====================================================
// Enhanced SPI Testbench (Verilog-2001)
// - Tests all SPI modes, slaves, and data patterns
// - Includes edge cases and random data
// - Comprehensive error checking and reporting
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

    // Test counters
    integer total_tests;
    integer pass_count;
    integer fail_count;
    integer i, j, k;

    // Test patterns
    reg [7:0] test_patterns [0:7];
    integer num_patterns = 8;

    // Wave dump
    initial begin
        $dumpfile("spi.vcd");
        $dumpvars(0, spi_tb);
    end

    // Initialize test patterns
    initial begin
        test_patterns[0] = 8'h00;       // All zeros
        test_patterns[1] = 8'hFF;       // All ones
        test_patterns[2] = 8'h55;       // Alternating 01
        test_patterns[3] = 8'hAA;       // Alternating 10
        test_patterns[4] = 8'hF0;       // Upper half ones
        test_patterns[5] = 8'h0F;       // Lower half ones
        test_patterns[6] = 8'hC3;       // Mixed pattern 1
        test_patterns[7] = 8'h3C;       // Mixed pattern 2
    end

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
        #10;

        // Sweep all modes, slaves, and patterns
        for (i = 0; i < 2; i = i + 1) begin       // CPOL
            for (j = 0; j < 2; j = j + 1) begin   // CPHA
                cpol = i;
                cpha = j;
                
                $display("\n==============================");
                $display("Testing CPOL=%0d, CPHA=%0d", cpol, cpha);
                $display("==============================");
                
                for (k = 0; k < 3; k = k + 1) begin // Slaves
                    slave_sel = k;
                    test_slave_patterns(k);
                end
            end
        end

        // Test random data patterns
        $display("\n==============================");
        $display("Testing Random Data Patterns");
        $display("==============================");
        test_random_patterns(20); // Test 20 random patterns

        // Final report
        $display("\n======================================");
        $display(" Test Summary: Total=%0d, Pass=%0d, Fail=%0d",
                  total_tests, pass_count, fail_count);
        $display("======================================\n");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        #50 $finish;
    end

    // Task: test all patterns for a specific slave
    task test_slave_patterns;
        input [1:0] slave;
        integer p;
        begin
            for (p = 0; p < num_patterns; p = p + 1) begin
                tx_data = test_patterns[p];
                run_transaction(slave, tx_data);
            end
        end
    endtask

    // Task: test random patterns
    task test_random_patterns;
        input integer num_rand;
        integer r;
        begin
            for (r = 0; r < num_rand; r = r + 1) begin
                // Test each slave with random data
                for (k = 0; k < 3; k = k + 1) begin
                    tx_data = $random;
                    run_transaction(k, tx_data);
                end
            end
        end
    endtask

    // Task: run a single transaction and check result
    task run_transaction;
        input [1:0] slave;
        input [7:0] data;
        integer timeout;
        begin
            slave_sel = slave;
            tx_data = data;
            
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            // Wait for done with timeout
            timeout = 0;
            while (!done && timeout < 1000) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            
            if (timeout >= 1000) begin
                $display("ERROR: Transaction timeout for slave %0d, data 0x%02h", slave, data);
                fail_count = fail_count + 1;
                total_tests = total_tests + 1;
            end else begin
                total_tests = total_tests + 1;
                
                if (rx_data === data) begin
                    pass_count = pass_count + 1;
                    $display("PASS: Slave%0d TX=0x%02h, RX=0x%02h",
                              slave, data, rx_data);
                end else begin
                    fail_count = fail_count + 1;
                    $display("FAIL: Slave%0d TX=0x%02h, RX=0x%02h",
                              slave, data, rx_data);
                end
            end
            
            // Small gap between transactions
            repeat (10) @(posedge clk);
        end
    endtask

endmodule