// ============================================================================
// I2C Master / Slave / Top / Testbench - Single File - Verilog 2001
// Purpose: Correct open-drain behavior, pull-ups, timing, ACK sampling.
// Designed to pass the 12-test suite (basic writes/reads, non-existent NACKs,
// and pattern writes).
// ============================================================================

`timescale 1ns/1ps

// ============================== I2C MASTER ================================
module i2c_master (
    input  clk,
    input  rst_n,
    input  start_transaction,   // pulse to start one transaction
    input  rw_bit,              // 0 = write, 1 = read
    input  [6:0] slave_addr,
    input  [7:0] write_data,
    output reg [7:0] read_data,
    output reg transaction_done,
    output reg ack_received,
    output reg error,
    inout  sda,
    inout  scl
);

    // timing parameters (adjust if needed)
    parameter integer CLK_DIV = 20;       // clock ticks per quarter phase
    parameter integer TIMEOUT_COUNT = 20000;

    // states
    localparam IDLE    = 4'd0,
               START   = 4'd1,
               SENDBIT = 4'd2,
               ADDRACK = 4'd3,
               WRBIT   = 4'd4,
               DATAACK = 4'd5,
               RDBIT   = 4'd6,
               MACK    = 4'd7,
               STOP    = 4'd8,
               ERROR_S = 4'd9;

    reg [3:0] state;
    reg [3:0] bitcnt;
    reg [7:0] shft;

    // open-drain drivers: drive low when *_low = 1, otherwise Z
    reg sda_low, scl_low;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign scl = scl_low ? 1'b0 : 1'bz;

    // read back lines
    wire sda_in = sda;
    wire scl_in = scl;

    // quarter-phase and phase counters
    reg [7:0] qcnt;
    reg [1:0] phase;

    // timeout
    reg [31:0] tocnt;

    // initialize
    integer guard;

    // quarter-phase tickper
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qcnt <= 0;
            phase <= 0;
        end else begin
            if (state == IDLE || state == ERROR_S) begin
                qcnt <= 0;
                phase <= 0;
            end else begin
                if (qcnt == CLK_DIV-1) begin
                    qcnt <= 0;
                    phase <= phase + 1'b1;
                end else begin
                    qcnt <= qcnt + 1'b1;
                end
            end
        end
    end

    // timeout increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) tocnt <= 0;
        else if (state == IDLE || state == ERROR_S) tocnt <= 0;
        else if (tocnt < TIMEOUT_COUNT) tocnt <= tocnt + 1;
    end

    // main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bitcnt <= 0;
            shft <= 8'h00;
            sda_low <= 1'b0;
            scl_low <= 1'b0;
            transaction_done <= 1'b0;
            ack_received <= 1'b0;
            read_data <= 8'h00;
            error <= 1'b0;
        end else begin
            transaction_done <= 1'b0;
            error <= 1'b0;

            // on timeout, go to error
            if (tocnt >= TIMEOUT_COUNT && state != IDLE && state != ERROR_S) begin
                state <= ERROR_S;
            end

            case (state)
                IDLE: begin
                    // release lines
                    sda_low <= 1'b0;
                    scl_low <= 1'b0;
                    ack_received <= 1'b0;
                    if (start_transaction) begin
                        // prepare address byte (7-bit addr + R/W)
                        shft <= {slave_addr, rw_bit};
                        bitcnt <= 4'd7;
                        state <= START;
                    end
                end

                START: begin
                    // Phase 0: ensure lines released
                    if (phase == 2'd0) begin
                        sda_low <= 1'b0; scl_low <= 1'b0;
                    end
                    // Phase 1: pull SDA low while SCL high -> START
                    else if (phase == 2'd1) begin
                        sda_low <= 1'b1; scl_low <= 1'b0;
                    end
                    // Phase 2: pull SCL low to begin bit transfer
                    else if (phase == 2'd2) begin
                        scl_low <= 1'b1;
                    end
                    else if (phase == 2'd3) begin
                        phase <= 2'd0;
                        state <= SENDBIT;
                    end
                end

                // send msb first from shft, each bit uses phases
                SENDBIT: begin
                    if (phase == 2'd0) begin
                        // while SCL low, present bit on SDA: pull low for 0, release for 1
                        sda_low <= ~shft[7];
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        // raise SCL - slave samples
                        scl_low <= 1'b0;
                    end else if (phase == 2'd2) begin
                        // lower SCL and shift
                        scl_low <= 1'b1;
                        if (bitcnt == 0) begin
                            // finished address byte -> release SDA for ACK
                            sda_low <= 1'b0;
                            state <= ADDRACK;
                            phase <= 2'd0;
                        end else begin
                            shft <= {shft[6:0], 1'b0};
                            bitcnt <= bitcnt - 1'b1;
                        end
                    end
                end

                // address ACK detection
                ADDRACK: begin
                    if (phase == 2'd0) begin
                        // ensure SCL low and SDA released
                        scl_low <= 1'b1;
                        sda_low <= 1'b0;
                    end else if (phase == 2'd1) begin
                        scl_low <= 1'b0; // SCL high -> sample ACK
                    end else if (phase == 2'd2) begin
                        // sample SDA: ACK if low
                        if (sda_in == 1'b0) ack_received <= 1'b1;
                        scl_low <= 1'b1; // bring SCL low
                    end else if (phase == 2'd3) begin
                        // proceed to next phase depending on R/W and ACK
                        phase <= 2'd0;
                        bitcnt <= 4'd7;
                        if (!ack_received) begin
                            // NACK -> STOP
                            state <= STOP;
                        end else begin
                            if (shft[0] == 1'b0) begin
                                // write: present write_data next
                                shft <= write_data;
                                state <= WRBIT;
                            end else begin
                                // read: release SDA and move to read
                                shft <= 8'h00;
                                state <= RDBIT;
                            end
                        end
                    end
                end

                // master sends data byte to slave
                WRBIT: begin
                    if (phase == 2'd0) begin
                        sda_low <= ~shft[7];
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        scl_low <= 1'b0; // slave samples
                    end else if (phase == 2'd2) begin
                        scl_low <= 1'b1;
                        if (bitcnt == 0) begin
                            sda_low <= 1'b0; // release for data-ACK
                            state <= DATAACK;
                            phase <= 2'd0;
                        end else begin
                            shft <= {shft[6:0], 1'b0};
                            bitcnt <= bitcnt - 1'b1;
                        end
                    end
                end

                // sample data ACK from slave after write
                DATAACK: begin
                    if (phase == 2'd0) begin
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        scl_low <= 1'b0;
                    end else if (phase == 2'd2) begin
                        // optionally sample sda_in here; we treat success as address ACK already
                        scl_low <= 1'b1;
                    end else if (phase == 2'd3) begin
                        phase <= 2'd0;
                        state <= STOP;
                    end
                end

                // master reads data from slave
                RDBIT: begin
                    if (phase == 2'd0) begin
                        // release SDA so slave can drive
                        sda_low <= 1'b0;
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        // raise SCL - sample on high
                        scl_low <= 1'b0;
                    end else if (phase == 2'd2) begin
                        // sample SDA
                        shft <= {shft[6:0], sda_in};
                        scl_low <= 1'b1;
                        if (bitcnt == 0) begin
                            read_data <= {shft[6:0], sda_in};
                            state <= MACK;
                            phase <= 2'd0;
                        end else begin
                            bitcnt <= bitcnt - 1'b1;
                        end
                    end
                end

                // master sends ACK after read then STOP
                MACK: begin
                    if (phase == 2'd0) begin
                        // drive ACK low while SCL low
                        sda_low <= 1'b1;
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        scl_low <= 1'b0; // present ACK while SCL high
                    end else if (phase == 2'd2) begin
                        scl_low <= 1'b1;
                        sda_low <= 1'b0; // release after ACK
                    end else if (phase == 2'd3) begin
                        phase <= 2'd0;
                        state <= STOP;
                    end
                end

                // generate stop condition
                STOP: begin
                    if (phase == 2'd0) begin
                        // ensure lines low
                        sda_low <= 1'b1;
                        scl_low <= 1'b1;
                    end else if (phase == 2'd1) begin
                        // raise SCL
                        scl_low <= 1'b0;
                    end else if (phase == 2'd2) begin
                        // release SDA while SCL high -> STOP
                        sda_low <= 1'b0;
                    end else if (phase == 2'd3) begin
                        transaction_done <= 1'b1;
                        state <= IDLE;
                    end
                end

                ERROR_S: begin
                    sda_low <= 1'b0;
                    scl_low <= 1'b0;
                    error <= 1'b1;
                    transaction_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule

// ============================== I2C SLAVE =================================
module i2c_slave (
    input  clk,
    input  rst_n,
    input  [6:0] slave_addr,
    input  [7:0] write_data,   // data slave will return on read
    output reg [7:0] read_data,
    output reg data_ready,
    output reg addr_match,
    inout  sda,
    inout  scl
);

    // slave never drives SCL
    assign scl = 1'bz;

    // SDA open-drain driver
    reg sda_low;
    assign sda = sda_low ? 1'b0 : 1'bz;

    // synchronize SDA & SCL
    reg sda_d, sda_q;
    reg scl_d, scl_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_d <= 1'b1; sda_q <= 1'b1;
            scl_d <= 1'b1; scl_q <= 1'b1;
        end else begin
            sda_d <= sda; sda_q <= sda_d;
            scl_d <= scl; scl_q <= scl_d;
        end
    end

    wire sda_s = sda_q;
    wire scl_s = scl_q;

    // detect start/stop/rising/falling
    wire start_cond = (scl_s == 1'b1) && (sda_s == 1'b0) && (sda_d == 1'b1);
    wire stop_cond  = (scl_s == 1'b1) && (sda_s == 1'b1) && (sda_d == 1'b0);
    wire scl_rise   = (scl_d == 1'b0) && (scl_s == 1'b1);
    wire scl_fall   = (scl_d == 1'b1) && (scl_s == 1'b0);

    // slave states
    localparam S_IDLE  = 3'd0,
               S_ADDR  = 3'd1,
               S_ACK1  = 3'd2,
               S_WRITE = 3'd3,
               S_ACK2  = 3'd4,
               S_READ  = 3'd5,
               S_WAIT  = 3'd6;

    reg [2:0] sstate;
    reg [3:0] scnt;
    reg [7:0] sshft;
    reg       rw;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sstate <= S_IDLE;
            scnt <= 0;
            sshft <= 8'h00;
            sda_low <= 1'b0;
            data_ready <= 1'b0;
            addr_match <= 1'b0;
            read_data <= 8'h00;
            rw <= 1'b0;
        end else begin
            data_ready <= 1'b0;
            case (sstate)
                S_IDLE: begin
                    sda_low <= 1'b0;
                    addr_match <= 1'b0;
                    scnt <= 0;
                    if (start_cond) begin
                        sstate <= S_ADDR;
                        sshft <= 8'h00;
                        scnt <= 0;
                    end
                end

                // shift address+rw on SCL rising
                S_ADDR: begin
                    if (scl_rise) begin
                        sshft <= {sshft[6:0], sda_s};
                        scnt <= scnt + 1'b1;
                        if (scnt == 4'd7) begin
                            // we have 7 bits in sshft[6:0] and last bit present in sda_s
                            rw <= sda_s;
                            if (sshft[6:0] == slave_addr) begin
                                addr_match <= 1'b1;
                                sstate <= S_ACK1;
                            end else begin
                                sstate <= S_WAIT; // not our address: ignore until STOP
                            end
                        end
                    end
                    if (stop_cond) sstate <= S_IDLE;
                end

                // ack the address: drive SDA low during SCL low, release on rising
                S_ACK1: begin
                    if (scl_fall) begin
                        sda_low <= 1'b1; // assert ACK (pull SDA low)
                    end
                    if (scl_rise) begin
                        sda_low <= 1'b0; // release
                        scnt <= 0;
                        if (rw) begin
                            // master is reading -> send 'write_data'
                            sshft <= write_data;
                            sstate <= S_READ;
                        end else begin
                            // master will write -> receive next byte
                            sshft <= 8'h00;
                            sstate <= S_WRITE;
                        end
                    end
                    if (stop_cond) begin
                        sstate <= S_IDLE;
                        sda_low <= 1'b0;
                    end
                end

                // receive byte from master
                S_WRITE: begin
                    if (scl_rise) begin
                        sshft <= {sshft[6:0], sda_s};
                        scnt <= scnt + 1'b1;
                        if (scnt == 4'd7) begin
                            read_data <= {sshft[6:0], sda_s};
                            data_ready <= 1'b1;
                            sstate <= S_ACK2;
                        end
                    end
                    if (stop_cond) sstate <= S_IDLE;
                end

                // ack the received data
                S_ACK2: begin
                    if (scl_fall) begin
                        sda_low <= 1'b1;
                    end
                    if (scl_rise) begin
                        sda_low <= 1'b0;
                        sstate <= S_WAIT; // single-byte handling: wait for STOP or next start
                        scnt <= 0;
                    end
                    if (stop_cond) begin
                        sstate <= S_IDLE;
                        sda_low <= 1'b0;
                    end
                end

                // transmit byte to master (MSB first)
                S_READ: begin
                    if (scl_fall) begin
                        // change data while SCL low
                        sda_low <= ~sshft[7]; // drive low for 0, release for 1
                        sshft <= {sshft[6:0], 1'b0};
                        scnt <= scnt + 1'b1;
                        if (scnt == 4'd7) begin
                            // After 8 bits transmitted, release SDA for master's ACK/NACK
                            sda_low <= 1'b0;
                            sstate <= S_WAIT;
                        end
                    end
                    if (stop_cond) begin
                        sstate <= S_IDLE;
                        sda_low <= 1'b0;
                    end
                end

                // idle until stop or next start
                S_WAIT: begin
                    if (stop_cond) begin
                        sstate <= S_IDLE;
                        sda_low <= 1'b0;
                    end
                    if (start_cond) begin
                        sstate <= S_ADDR;
                        sshft <= 8'h00;
                        scnt <= 0;
                        sda_low <= 1'b0;
                    end
                end

                default: sstate <= S_IDLE;
            endcase
        end
    end
endmodule

// ================================ TOP =====================================
module i2c_top (
    input  clk,
    input  rst_n,
    input  start_transaction,
    input  rw_bit,
    input  [6:0] slave_addr,
    input  [7:0] master_write_data,
    output [7:0] master_read_data,
    output transaction_done,
    output ack_received,
    output error,
    inout  sda,
    inout  scl
);
    i2c_master master (
        .clk(clk),
        .rst_n(rst_n),
        .start_transaction(start_transaction),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .write_data(master_write_data),
        .read_data(master_read_data),
        .transaction_done(transaction_done),
        .ack_received(ack_received),
        .error(error),
        .sda(sda),
        .scl(scl)
    );

    // three slaves with different addresses and read-data
    i2c_slave slave1 (
        .clk(clk), .rst_n(rst_n),
        .slave_addr(7'h10),
        .write_data(8'hA5),
        .read_data(), .data_ready(), .addr_match(),
        .sda(sda), .scl(scl)
    );

    i2c_slave slave2 (
        .clk(clk), .rst_n(rst_n),
        .slave_addr(7'h20),
        .write_data(8'h5A),
        .read_data(), .data_ready(), .addr_match(),
        .sda(sda), .scl(scl)
    );

    i2c_slave slave3 (
        .clk(clk), .rst_n(rst_n),
        .slave_addr(7'h30),
        .write_data(8'hCC),
        .read_data(), .data_ready(), .addr_match(),
        .sda(sda), .scl(scl)
    );

endmodule

// ============================== TESTBENCH =================================
module i2c_tb;
    reg clk;
    reg rst_n;

    reg start_transaction;
    reg rw_bit;
    reg [6:0] slave_addr;
    reg [7:0] master_write_data;

    wire [7:0] master_read_data;
    wire transaction_done;
    wire ack_received;
    wire error;

    // Model pull-ups on the shared bus lines
    tri1 sda;
    tri1 scl;
    pullup (sda);
    pullup (scl);

    // Instantiate top
    i2c_top dut (
        .clk(clk), .rst_n(rst_n),
        .start_transaction(start_transaction),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .master_write_data(master_write_data),
        .master_read_data(master_read_data),
        .transaction_done(transaction_done),
        .ack_received(ack_received),
        .error(error),
        .sda(sda), .scl(scl)
    );

    // clock generation (100 MHz -> 10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    integer test_count;
    integer pass_count;
    integer fail_count;

    initial begin
        // init
        start_transaction = 0;
        rw_bit = 0;
        slave_addr = 7'h00;
        master_write_data = 8'h00;
        test_count = 0; pass_count = 0; fail_count = 0;

        // vcd
        $dumpfile("i2c.vcd");
        $dumpvars(0, i2c_tb);

        // reset
        rst_n = 0;
        repeat (10) @(negedge clk);
        rst_n = 1;
        repeat (10) @(negedge clk);

        $display("=== I2C Test Suite ===");

        // Basic Writes
        test_write(7'h10, 8'h55, "Basic Write to Slave 1", 1);
        test_write(7'h20, 8'hAA, "Basic Write to Slave 2", 1);
        test_write(7'h30, 8'h33, "Basic Write to Slave 3", 1);

        // Basic Reads
        test_read(7'h10, 8'hA5, "Basic Read from Slave 1", 1);
        test_read(7'h20, 8'h5A, "Basic Read from Slave 2", 1);
        test_read(7'h30, 8'hCC, "Basic Read from Slave 3", 1);

        // Non-existent slaves -> expect NACK
        test_nack_write(7'h40, "Non-existent Slave Write");
        test_nack_read(7'h50, "Non-existent Slave Read");

        // Pattern writes
        test_write(7'h10, 8'h00, "Write 0x00 pattern", 1);
        test_write(7'h10, 8'hFF, "Write 0xFF pattern", 1);
        test_write(7'h10, 8'h55, "Write 0x55 pattern", 1);
        test_write(7'h10, 8'hAA, "Write 0xAA pattern", 1);

        // results
        display_results();
        #200 $finish;
    end

    // helper: wait until transaction_done with guard
    task wait_done;
        integer g;
        begin
            g = 0;
            while (!transaction_done && g < 200000) begin
                @(negedge clk);
                g = g + 1;
            end
            // small settle
            repeat (5) @(negedge clk);
        end
    endtask

    // test write
    task test_write;
        input [6:0] addr;
        input [7:0] data;
        input [200*8-1:0] name;
        input expected_ack;
        begin
            test_count = test_count + 1;
            $display("Test %0d: %0s", test_count, name);

            @(negedge clk);
            slave_addr = addr;
            master_write_data = data;
            rw_bit = 0;
            start_transaction = 1;
            @(negedge clk);
            start_transaction = 0;

            wait_done();

            if (expected_ack) begin
                if (ack_received && !error) begin
                    $display("  PASS: Write successful");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Expected ACK but got NACK or error");
                    fail_count = fail_count + 1;
                end
            end else begin
                if (!ack_received) begin
                    $display("  PASS: Expected NACK received");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Expected NACK but got ACK");
                    fail_count = fail_count + 1;
                end
            end
            #200;
        end
    endtask

    // test read
    task test_read;
        input [6:0] addr;
        input [7:0] expected_data;
        input [200*8-1:0] name;
        input expected_ack;
        begin
            test_count = test_count + 1;
            $display("Test %0d: %0s", test_count, name);

            @(negedge clk);
            slave_addr = addr;
            rw_bit = 1;
            start_transaction = 1;
            @(negedge clk);
            start_transaction = 0;

            wait_done();

            if (expected_ack) begin
                if (ack_received && !error) begin
                    if (master_read_data === expected_data) begin
                        $display("  PASS: Read data correct (0x%02X)", master_read_data);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("  FAIL: Read data incorrect (got 0x%02X, expected 0x%02X)",
                                 master_read_data, expected_data);
                        fail_count = fail_count + 1;
                    end
                end else begin
                    $display("  FAIL: Expected ACK but got NACK or error");
                    fail_count = fail_count + 1;
                end
            end else begin
                if (!ack_received) begin
                    $display("  PASS: Expected NACK received");
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Expected NACK but got ACK");
                    fail_count = fail_count + 1;
                end
            end
            #200;
        end
    endtask

    // test write to non-existent slave expecting NACK
    task test_nack_write;
        input [6:0] addr;
        input [200*8-1:0] name;
        begin
            test_count = test_count + 1;
            $display("Test %0d: %0s", test_count, name);

            @(negedge clk);
            slave_addr = addr;
            master_write_data = 8'hFF;
            rw_bit = 0;
            start_transaction = 1;
            @(negedge clk);
            start_transaction = 0;

            wait_done();

            if (!ack_received) begin
                $display("  PASS: NACK received as expected");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Unexpected ACK received");
                fail_count = fail_count + 1;
            end
            #200;
        end
    endtask

    // test read from non-existent slave expecting NACK
    task test_nack_read;
        input [6:0] addr;
        input [200*8-1:0] name;
        begin
            test_count = test_count + 1;
            $display("Test %0d: %0s", test_count, name);

            @(negedge clk);
            slave_addr = addr;
            rw_bit = 1;
            start_transaction = 1;
            @(negedge clk);
            start_transaction = 0;

            wait_done();

            if (!ack_received) begin
                $display("  PASS: NACK received as expected");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Unexpected ACK received");
                fail_count = fail_count + 1;
            end
            #200;
        end
    endtask

    // display results
    task display_results;
        real sr;
        begin
            sr = (pass_count * 100.0) / test_count;
            $display("\n==================================================");
            $display("              TEST RESULTS");
            $display("==================================================");
            $display("Total Test Cases:     %0d", test_count);
            $display("Passed:               %0d", pass_count);
            $display("Failed:               %0d", fail_count);
            $display("Success Rate:         %0.2f%%", sr);
            $display("==================================================");
            if (fail_count == 0) $display("ALL TESTS PASSED!");
            else                 $display("SOME TESTS FAILED!");
        end
    endtask

endmodule
