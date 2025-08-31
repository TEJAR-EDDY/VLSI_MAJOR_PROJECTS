// ============================================================================
// I2C Master Module
// Author: Teja Reddy
// ============================================================================
module i2c_master (
    input clk,                // System clock
    input rst_n,              // Active low reset
    input start_transaction,  // Signal to start I2C transaction
    input rw_bit,             // 0: Write, 1: Read
    input [6:0] slave_addr,   // 7-bit slave address
    input [7:0] write_data,   // Data to write to slave
    output reg [7:0] read_data, // Data read from slave
    output reg transaction_done, // High when transaction completed
    output reg ack_received,  // High if ACK received from slave
    inout sda,                // I2C data line (open-drain)
    inout scl                 // I2C clock line (open-drain)
);

    // I2C timing parameters (for simulation - very short)
    parameter CLK_DIV = 10;   // Clock divider for I2C speed

    // FSM states
    parameter [3:0]
        IDLE      = 4'd0,
        START     = 4'd1,
        ADDR      = 4'd2,
        ACK1      = 4'd3,
        WRITE     = 4'd4,
        ACK2      = 4'd5,
        READ      = 4'd6,
        ACK3      = 4'd7,
        NACK      = 4'd8,
        STOP      = 4'd9;

    reg [3:0] state;          // Current state
    reg [3:0] bit_count;      // Bit counter for data/address
    reg [7:0] shift_reg;      // Shift register for data
    reg sda_oen;              // SDA output enable (0=drive, 1=high-Z)
    reg scl_oen;              // SCL output enable (0=drive, 1=high-Z)
    reg [7:0] clk_counter;    // Clock divider counter

    // Internal signals
    reg sda_out;              // SDA output value
    reg scl_out;              // SCL output value

    // Open-drain implementation
    assign sda = sda_oen ? 1'bz : sda_out;
    assign scl = scl_oen ? 1'bz : scl_out;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_count <= 0;
            shift_reg <= 0;
            sda_oen <= 1;
            scl_oen <= 1;
            sda_out <= 1;
            scl_out <= 1;
            clk_counter <= 0;
            transaction_done <= 0;
            ack_received <= 0;
            read_data <= 0;
        end else begin
            // Default values
            transaction_done <= 0;
            
            // Clock divider for I2C speed
            clk_counter <= clk_counter + 1;
            if (clk_counter == CLK_DIV-1) begin
                clk_counter <= 0;
            end
            
            case (state)
                IDLE: begin
                    sda_oen <= 1;  // Release SDA
                    scl_oen <= 1;  // Release SCL
                    bit_count <= 0;
                    ack_received <= 0;
                    
                    if (start_transaction) begin
                        state <= START;
                        clk_counter <= 0;
                    end
                end
                
                START: begin
                    if (clk_counter == 0) begin
                        sda_oen <= 0;  // Drive SDA low
                        scl_oen <= 1;  // Keep SCL high
                    end else if (clk_counter == CLK_DIV-1) begin
                        state <= ADDR;
                        // Prepare address + R/W bit
                        shift_reg <= {slave_addr, rw_bit};
                        bit_count <= 7;
                    end
                end
                
                ADDR: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV/2) begin
                        // Set SDA to next bit
                        sda_out <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        
                        if (bit_count == 0) begin
                            state <= ACK1;
                            sda_oen <= 1;  // Release SDA for ACK
                        end else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                end
                
                ACK1: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        
                        // Check for ACK (SDA low)
                        if (!sda) begin
                            ack_received <= 1;
                            if (rw_bit) begin
                                state <= READ;
                                bit_count <= 7;
                                sda_oen <= 1;  // Release SDA for reading
                            end else begin
                                state <= WRITE;
                                shift_reg <= write_data;
                                bit_count <= 7;
                                sda_oen <= 0;  // Drive SDA for writing
                            end
                        end else begin
                            // NACK received
                            state <= NACK;
                        end
                    end
                end
                
                WRITE: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV/2) begin
                        // Set SDA to next bit
                        sda_out <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        
                        if (bit_count == 0) begin
                            state <= ACK2;
                            sda_oen <= 1;  // Release SDA for ACK
                        end else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                end
                
                ACK2: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        
                        // Check for ACK (SDA low)
                        if (!sda) begin
                            state <= STOP;
                        end else begin
                            // NACK received
                            state <= NACK;
                        end
                    end
                end
                
                READ: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        
                        // Sample SDA on rising edge
                        shift_reg <= {shift_reg[6:0], sda};
                        
                        if (bit_count == 0) begin
                            state <= ACK3;
                            sda_oen <= 0;  // Drive SDA for ACK/NACK
                            read_data <= {shift_reg[6:0], sda}; // Save read data
                        end else begin
                            bit_count <= bit_count - 1;
                        end
                    end
                end
                
                ACK3: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                        sda_out <= 0;  // Send ACK (low)
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        state <= STOP;
                    end
                end
                
                NACK: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                    end else if (clk_counter == CLK_DIV-1) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                        state <= STOP;
                    end
                end
                
                STOP: begin
                    if (clk_counter == 0) begin
                        scl_oen <= 0;  // Drive SCL low
                        sda_oen <= 0;  // Drive SDA low
                    end else if (clk_counter == CLK_DIV/2) begin
                        scl_oen <= 1;  // Release SCL (rising edge)
                    end else if (clk_counter == CLK_DIV-1) begin
                        sda_oen <= 1;  // Release SDA (rising edge = STOP)
                        transaction_done <= 1;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ============================================================================
// I2C Slave Module (Fixed)
// ============================================================================
module i2c_slave (
    input clk,                // System clock
    input rst_n,              // Active low reset
    input [6:0] slave_addr,   // This slave's address
    input [7:0] write_data,   // Data to send when master reads
    output reg [7:0] read_data, // Data received from master
    output reg data_ready,    // High when new data received
    inout sda,                // I2C data line (open-drain)
    inout scl                 // I2C clock line (open-drain)
);

    // FSM states
    parameter [3:0]
        IDLE      = 4'd0,
        ADDR      = 4'd1,
        ACK1      = 4'd2,
        READ      = 4'd3,
        WRITE     = 4'd4,
        ACK2      = 4'd5,
        STOP      = 4'd6;

    reg [3:0] state;          // Current state
    reg [3:0] bit_count;      // Bit counter
    reg [7:0] shift_reg;      // Shift register for data
    reg sda_oen;              // SDA output enable (0=drive, 1=high-Z)
    reg scl_oen;              // SCL output enable (0=drive, 1=high-Z)
    reg address_match;        // High when address matches
    reg rw_bit;               // Stored R/W bit from address
    reg sda_in;               // Synchronized SDA input
    reg scl_in;               // Synchronized SCL input
    reg sda_prev;             // Previous SDA value for edge detection
    reg scl_prev;             // Previous SCL value for edge detection

    // Internal signals
    reg sda_out;              // SDA output value
    reg scl_out;              // SCL output value

    // Open-drain implementation
    assign sda = sda_oen ? 1'bz : sda_out;
    assign scl = scl_oen ? 1'bz : scl_out;

    // Synchronize external signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_in <= 1;
            scl_in <= 1;
            sda_prev <= 1;
            scl_prev <= 1;
        end else begin
            sda_in <= sda;
            scl_in <= scl;
            sda_prev <= sda_in;
            scl_prev <= scl_in;
        end
    end

    // Detect START condition (SDA falls while SCL is high)
    wire start_condition = scl_in && !sda_in && sda_prev;
    
    // Detect STOP condition (SDA rises while SCL is high)
    wire stop_condition = scl_in && sda_in && !sda_prev;
    
    // Detect SCL rising edge
    wire scl_rising = scl_in && !scl_prev;
    
    // Detect SCL falling edge
    wire scl_falling = !scl_in && scl_prev;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_count <= 0;
            shift_reg <= 0;
            sda_oen <= 1;
            scl_oen <= 1;
            sda_out <= 1;
            scl_out <= 1;
            data_ready <= 0;
            address_match <= 0;
            rw_bit <= 0;
        end else begin
            // Default values
            data_ready <= 0;
            
            case (state)
                IDLE: begin
                    sda_oen <= 1;  // Release SDA
                    scl_oen <= 1;  // Release SCL
                    bit_count <= 0;
                    
                    if (start_condition) begin
                        state <= ADDR;
                        shift_reg <= 0;
                    end
                end
                
                ADDR: begin
                    if (scl_rising) begin
                        // Sample SDA on SCL rising edge
                        shift_reg <= {shift_reg[6:0], sda_in};
                        bit_count <= bit_count + 1;
                        
                        if (bit_count == 7) begin
                            // Check if address matches (first 7 bits)
                            address_match <= (shift_reg[6:0] == slave_addr);
                            rw_bit <= sda_in;  // Save R/W bit
                            state <= ACK1;
                        end
                    end
                    
                    if (stop_condition) begin
                        state <= IDLE;
                    end
                end
                
                ACK1: begin
                    if (scl_falling) begin
                        // Drive ACK on SCL falling edge
                        if (address_match) begin
                            sda_oen <= 0;  // Drive SDA low (ACK)
                        end
                    end else if (scl_rising) begin
                        // Prepare for next state on SCL rising edge
                        sda_oen <= 1;  // Release SDA
                        
                        if (address_match) begin
                            if (rw_bit) begin
                                state <= READ;
                                shift_reg <= write_data;  // Load data to send
                                bit_count <= 0;
                            end else begin
                                state <= WRITE;
                                shift_reg <= 0;
                                bit_count <= 0;
                            end
                        end else begin
                            state <= IDLE;
                        end
                    end
                    
                    if (stop_condition) begin
                        state <= IDLE;
                        sda_oen <= 1;  // Release SDA
                    end
                end
                
                WRITE: begin
                    if (scl_falling) begin
                        // Set SDA on SCL falling edge
                        if (bit_count < 8) begin
                            sda_oen <= 0;  // Drive SDA
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end else begin
                            sda_oen <= 1;  // Release SDA for ACK
                        end
                    end else if (scl_rising) begin
                        // Sample on SCL rising edge
                        if (bit_count < 8) begin
                            bit_count <= bit_count + 1;
                        end else begin
                            // Wait for master ACK
                            state <= ACK2;
                            bit_count <= 0;
                        end
                    end
                    
                    if (stop_condition) begin
                        state <= IDLE;
                        sda_oen <= 1;  // Release SDA
                    end
                end
                
                ACK2: begin
                    if (scl_falling) begin
                        // Check ACK on SCL falling edge
                        if (!sda_in) begin
                            // ACK received, continue
                            state <= WRITE;
                            shift_reg <= 0;
                            bit_count <= 0;
                        end else begin
                            // NACK received, stop
                            state <= IDLE;
                        end
                    end
                    
                    if (stop_condition) begin
                        state <= IDLE;
                        sda_oen <= 1;  // Release SDA
                    end
                end
                
                READ: begin
                    if (scl_rising) begin
                        // Sample SDA on SCL rising edge
                        shift_reg <= {shift_reg[6:0], sda_in};
                        bit_count <= bit_count + 1;
                        
                        if (bit_count == 7) begin
                            read_data <= {shift_reg[6:0], sda_in};
                            data_ready <= 1;
                            state <= ACK2;
                        end
                    end
                    
                    if (scl_falling) begin
                        // Set SDA on SCL falling edge
                        if (bit_count < 8) begin
                            sda_oen <= 0;  // Drive SDA
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end else begin
                            sda_oen <= 1;  // Release SDA for ACK
                        end
                    end
                    
                    if (stop_condition) begin
                        state <= IDLE;
                        sda_oen <= 1;  // Release SDA
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// ============================================================================
// Top Module: Connects 1 Master and 3 Slaves
// ============================================================================
module i2c_top (
    input clk,
    input rst_n,
    // Master control interface
    input start_transaction,
    input rw_bit,
    input [6:0] slave_addr,
    input [7:0] master_write_data,
    output [7:0] master_read_data,
    output transaction_done,
    output ack_received,
    // Shared I2C bus
    inout sda,
    inout scl
);

    // Instantiate master
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
        .sda(sda),
        .scl(scl)
    );

    // Slave signals
    wire [7:0] slave1_read_data, slave2_read_data, slave3_read_data;
    wire slave1_data_ready, slave2_data_ready, slave3_data_ready;
    
    // Slave write data (hardcoded for simplicity)
    wire [7:0] slave1_write_data = 8'hA5; // Example data
    wire [7:0] slave2_write_data = 8'h5A; // Example data
    wire [7:0] slave3_write_data = 8'hAA; // Example data

    // Instantiate slaves with different addresses
    i2c_slave slave1 (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(7'h10),  // Address 0x10
        .write_data(slave1_write_data),
        .read_data(slave1_read_data),
        .data_ready(slave1_data_ready),
        .sda(sda),
        .scl(scl)
    );

    i2c_slave slave2 (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(7'h20),  // Address 0x20
        .write_data(slave2_write_data),
        .read_data(slave2_read_data),
        .data_ready(slave2_data_ready),
        .sda(sda),
        .scl(scl)
    );

    i2c_slave slave3 (
        .clk(clk),
        .rst_n(rst_n),
        .slave_addr(7'h30),  // Address 0x30
        .write_data(slave3_write_data),
        .read_data(slave3_read_data),
        .data_ready(slave3_data_ready),
        .sda(sda),
        .scl(scl)
    );

endmodule

// ============================================================================
// Testbench
// ============================================================================
module i2c_top_tb;

    // Test parameters
    reg clk;
    reg rst_n;
    reg start_transaction;
    reg rw_bit;
    reg [6:0] slave_addr;
    reg [7:0] master_write_data;
    wire [7:0] master_read_data;
    wire transaction_done;
    wire ack_received;
    
    // I2C bus
    wire sda;
    wire scl;
    
    // Test counters
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // Instantiate top module
    i2c_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_transaction(start_transaction),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .master_write_data(master_write_data),
        .master_read_data(master_read_data),
        .transaction_done(transaction_done),
        .ack_received(ack_received),
        .sda(sda),
        .scl(scl)
    );
    
    // Clock generation
    always #5 clk = ~clk;  // 100MHz clock
    
    // Initialize simulation
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        start_transaction = 0;
        rw_bit = 0;
        slave_addr = 0;
        master_write_data = 0;
        
        // Generate waveform file for GTKWave
        $dumpfile("i2c_top.vcd");
        $dumpvars(0, i2c_top_tb);
        
        // Reset system
        #20 rst_n = 1;
        
        // Run tests
        $display("Starting I2C tests...");
        
        // Test 1: Write to slave 1
        test_write(7'h10, 8'h55, "Slave 1");
        
        // Test 2: Read from slave 1
        test_read(7'h10, 8'hA5, "Slave 1"); // Should read 0xA5
        
        // Test 3: Write to slave 2
        test_write(7'h20, 8'hAA, "Slave 2");
        
        // Test 4: Read from slave 2
        test_read(7'h20, 8'h5A, "Slave 2"); // Should read 0x5A
        
        // Test 5: Write to slave 3
        test_write(7'h30, 8'h33, "Slave 3");
        
        // Test 6: Read from slave 3
        test_read(7'h30, 8'hAA, "Slave 3"); // Should read 0xAA
        
        // Test 7: Try to access non-existent slave (should NACK)
        test_nack(7'h40, "Non-existent slave");
        
        // Display test results
        $display("========================================");
        $display("Tests completed: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        // End simulation
        #100 $finish;
    end
    
    // Task to test write operation
    task test_write;
        input [6:0] addr;
        input [7:0] data;
        input [80:0] slave_name;
        
        begin
            test_count = test_count + 1;
            $display("Test %0d: Writing 0x%02X to %s", test_count, data, slave_name);
            
            // Setup write transaction
            @(negedge clk);
            slave_addr = addr;
            master_write_data = data;
            rw_bit = 0;  // Write operation
            start_transaction = 1;
            
            // Wait for transaction to start
            @(negedge clk);
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait(transaction_done);
            
            // Check if ACK was received
            if (ack_received) begin
                $display("  PASS: ACK received from %s", slave_name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: No ACK received from %s", slave_name);
                fail_count = fail_count + 1;
            end
            
            // Small delay between tests
            #100;
        end
    endtask
    
    // Task to test read operation
    task test_read;
        input [6:0] addr;
        input [7:0] expected_data;
        input [80:0] slave_name;
        
        begin
            test_count = test_count + 1;
            $display("Test %0d: Reading from %s (expecting 0x%02X)", test_count, slave_name, expected_data);
            
            // Setup read transaction
            @(negedge clk);
            slave_addr = addr;
            rw_bit = 1;  // Read operation
            start_transaction = 1;
            
            // Wait for transaction to start
            @(negedge clk);
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait(transaction_done);
            
            // Check if ACK was received
            if (!ack_received) begin
                $display("  FAIL: No ACK received from %s", slave_name);
                fail_count = fail_count + 1;
            end else begin
                // Check if correct data was received
                if (master_read_data === expected_data) begin
                    $display("  PASS: Correct data received from %s (0x%02X)", slave_name, master_read_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  FAIL: Incorrect data received from %s (got 0x%02X, expected 0x%02X)", 
                             slave_name, master_read_data, expected_data);
                    fail_count = fail_count + 1;
                end
            end
            
            // Small delay between tests
            #100;
        end
    endtask
    
    // Task to test NACK scenario
    task test_nack;
        input [6:0] addr;
        input [80:0] slave_name;
        
        begin
            test_count = test_count + 1;
            $display("Test %0d: Accessing %s (expecting NACK)", test_count, slave_name);
            
            // Setup write transaction to non-existent slave
            @(negedge clk);
            slave_addr = addr;
            master_write_data = 8'hFF;
            rw_bit = 0;  // Write operation
            start_transaction = 1;
            
            // Wait for transaction to start
            @(negedge clk);
            start_transaction = 0;
            
            // Wait for transaction to complete
            wait(transaction_done);
            
            // Check if NACK was received (ack_received should be 0)
            if (!ack_received) begin
                $display("  PASS: NACK received from %s as expected", slave_name);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Unexpected ACK received from %s", slave_name);
                fail_count = fail_count + 1;
            end
            
            // Small delay between tests
            #100;
        end
    endtask

endmodule