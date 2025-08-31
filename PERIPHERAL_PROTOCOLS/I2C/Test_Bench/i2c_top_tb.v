//=============================================================================
// Testbench for I2C System
// Tests all functionality: write/read to all slaves, ACK/NACK detection
// Author: Teja Reddy
//=============================================================================
module i2c_top_tb;

    // Test signals
    reg clk;
    reg reset;
    
    // Master control
    reg start_transaction;
    reg rw_bit;
    reg [6:0] slave_addr;
    reg [7:0] master_write_data;
    
    // Master status
    wire [7:0] master_read_data;
    wire transaction_done;
    wire ack_received;
    
    // Slave data
    reg [7:0] slave0_write_data;
    reg [7:0] slave1_write_data;
    reg [7:0] slave2_write_data;
    wire [7:0] slave0_read_data;
    wire [7:0] slave1_read_data;
    wire [7:0] slave2_read_data;
    wire slave0_data_valid;
    wire slave1_data_valid;
    wire slave2_data_valid;
    
    // Test tracking
    integer test_count;
    integer pass_count;
    integer fail_count;
    
    // Slave addresses (must match top module)
    localparam [6:0] SLAVE0_ADDR = 7'h10;
    localparam [6:0] SLAVE1_ADDR = 7'h20;
    localparam [6:0] SLAVE2_ADDR = 7'h30;
    localparam [6:0] INVALID_ADDR = 7'h7F; // Address that doesn't exist

    // Instantiate the top module (Device Under Test)
    i2c_top dut (
        .clk(clk),
        .reset(reset),
        .start_transaction(start_transaction),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .master_write_data(master_write_data),
        .master_read_data(master_read_data),
        .transaction_done(transaction_done),
        .ack_received(ack_received),
        .slave0_write_data(slave0_write_data),
        .slave1_write_data(slave1_write_data),
        .slave2_write_data(slave2_write_data),
        .slave0_read_data(slave0_read_data),
        .slave1_read_data(slave1_read_data),
        .slave2_read_data(slave2_read_data),
        .slave0_data_valid(slave0_data_valid),
        .slave1_data_valid(slave1_data_valid),
        .slave2_data_valid(slave2_data_valid)
    );

    // Clock generation - 10ns period (100MHz)
    // This will be divided down inside the I2C master for slower I2C timing
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period clock
    end

    // Generate VCD file for GTKWave visualization
    initial begin
        $dumpfile("i2c_test.vcd");
        $dumpvars(0, i2c_top_tb);
    end

    // Main test sequence
    initial begin
        // Initialize all signals
        reset = 1;
        start_transaction = 0;
        rw_bit = 0;
        slave_addr = 7'h00;
        master_write_data = 8'h00;
        slave0_write_data = 8'hA0;  // Data slave0 will send when read
        slave1_write_data = 8'hB1;  // Data slave1 will send when read
        slave2_write_data = 8'hC2;  // Data slave2 will send when read
        
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        $display("=== I2C System Testbench Starting ===");
        $display("This testbench will test:");
        $display("1. Writing data to all three slaves");
        $display("2. Reading data from all three slaves");
        $display("3. Handling invalid slave addresses (NACK)");
        $display("4. Verifying ACK/NACK detection");
        $display("");
        
        // Reset sequence
        $display("[TIME %0t] Applying reset...", $time);
        #100;
        reset = 0;
        #100;
        
        // Test 1: Write to Slave 0
        test_write_to_slave(SLAVE0_ADDR, 8'h55, "Slave 0");
        
        // Test 2: Write to Slave 1
        test_write_to_slave(SLAVE1_ADDR, 8'hAA, "Slave 1");
        
        // Test 3: Write to Slave 2
        test_write_to_slave(SLAVE2_ADDR, 8'h33, "Slave 2");
        
        // Test 4: Read from Slave 0
        test_read_from_slave(SLAVE0_ADDR, slave0_write_data, "Slave 0");
        
        // Test 5: Read from Slave 1
        test_read_from_slave(SLAVE1_ADDR, slave1_write_data, "Slave 1");
        
        // Test 6: Read from Slave 2
        test_read_from_slave(SLAVE2_ADDR, slave2_write_data, "Slave 2");
        
        // Test 7: Write to invalid address (should get NACK)
        test_invalid_address(INVALID_ADDR, 8'h99, "Invalid Address");
        
        // Wait a bit more to see final waveforms
        #1000;
        
        // Print final results
        $display("");
        $display("=== Test Results Summary ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED! ***");
        end else begin
            $display("*** SOME TESTS FAILED! ***");
        end
        
        $display("VCD file 'i2c_test.vcd' generated for GTKWave analysis");
        $display("=== Testbench Complete ===");
        $finish;
    end

    // Task to test writing data to a slave
    task test_write_to_slave;
        input [6:0] addr;
        input [7:0] data;
        input [160:1] slave_name;  // 160 bits for string (20 chars * 8 bits)
        begin
            test_count = test_count + 1;
            $display("[TEST %0d] Writing 0x%02X to %0s (addr 0x%02X)...", 
                     test_count, data, slave_name, addr);
            
            // Setup write transaction
            slave_addr = addr;
            master_write_data = data;
            rw_bit = 1'b0;  // Write operation
            
            // Start transaction
            start_transaction = 1;
            #10;
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait_for_transaction_done();
            
            // Check if ACK was received (should be 1 for valid addresses)
            if (ack_received) begin
                $display("[PASS] Write to %0s completed with ACK", slave_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Write to %0s completed with NACK", slave_name);
                fail_count = fail_count + 1;
            end
            
            // Additional delay between tests
            #200;
        end
    endtask

    // Task to test reading data from a slave
    task test_read_from_slave;
        input [6:0] addr;
        input [7:0] expected_data;
        input [160:1] slave_name;  // 160 bits for string (20 chars * 8 bits)
        begin
            test_count = test_count + 1;
            $display("[TEST %0d] Reading from %0s (addr 0x%02X), expecting 0x%02X...", 
                     test_count, slave_name, addr, expected_data);
            
            // Setup read transaction
            slave_addr = addr;
            rw_bit = 1'b1;  // Read operation
            
            // Start transaction
            start_transaction = 1;
            #10;
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait_for_transaction_done();
            
            // Check if ACK was received and data is correct
            if (ack_received && master_read_data == expected_data) begin
                $display("[PASS] Read from %0s: got 0x%02X (expected 0x%02X)", 
                         slave_name, master_read_data, expected_data);
                pass_count = pass_count + 1;
            end else if (!ack_received) begin
                $display("[FAIL] Read from %0s: got NACK instead of ACK", slave_name);
                fail_count = fail_count + 1;
            end else begin
                $display("[FAIL] Read from %0s: got 0x%02X (expected 0x%02X)", 
                         slave_name, master_read_data, expected_data);
                fail_count = fail_count + 1;
            end
            
            // Additional delay between tests
            #200;
        end
    endtask

    // Task to test invalid address (should get NACK)
    task test_invalid_address;
        input [6:0] addr;
        input [7:0] data;
        input [160:1] test_name;  // 160 bits for string (20 chars * 8 bits)
        begin
            test_count = test_count + 1;
            $display("[TEST %0d] Testing %0s (addr 0x%02X) - should get NACK...", 
                     test_count, test_name, addr);
            
            // Setup write transaction to invalid address
            slave_addr = addr;
            master_write_data = data;
            rw_bit = 1'b0;  // Write operation
            
            // Start transaction
            start_transaction = 1;
            #10;
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait_for_transaction_done();
            
            // Check if NACK was received (should be 0 for invalid addresses)
            if (!ack_received) begin
                $display("[PASS] %0s correctly returned NACK", test_name);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s incorrectly returned ACK", test_name);
                fail_count = fail_count + 1;
            end
            
            // Additional delay between tests
            #200;
        end
    endtask

    // Task to wait for I2C transaction to complete
    // This makes the testbench easier to read and understand
    task wait_for_transaction_done;
        begin
            // Wait for transaction_done signal with timeout
            fork
                begin
                    // Wait for done signal
                    wait(transaction_done);
                    $display("[INFO] Transaction completed at time %0t", $time);
                end
                begin
                    // Timeout after reasonable time
                    #50000;  // 50us timeout
                    $display("[ERROR] Transaction timeout!");
                end
            join_any
            disable fork;  // Stop the other process
            
            // Small delay to ensure signals are stable
            #10;
        end
    endtask

    // Monitor important signals for debugging
    // This helps beginners understand what's happening during simulation
    always @(posedge transaction_done) begin
        $display("[DEBUG] Transaction done - ACK: %b, Read data: 0x%02X", 
                 ack_received, master_read_data);
    end
    
    // Monitor slave data reception
    always @(posedge slave0_data_valid) begin
        $display("[DEBUG] Slave 0 received data: 0x%02X", slave0_read_data);
    end
    
    always @(posedge slave1_data_valid) begin
        $display("[DEBUG] Slave 1 received data: 0x%02X", slave1_read_data);
    end
    
    always @(posedge slave2_data_valid) begin
        $display("[DEBUG] Slave 2 received data: 0x%02X", slave2_read_data);
    end

endmodule
