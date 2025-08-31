// Axi4_lite testbench design using verilog_HDL
// Author: Teja Reddy
module axi4_lite_tb; 
 
    // Parameters 
    parameter ADDR_WIDTH = 32; 
    parameter DATA_WIDTH = 32; 
    parameter STRB_WIDTH = DATA_WIDTH/8; 
    parameter CLK_PERIOD = 10; // 100MHz clock 
     
    // Clock and Reset 
    reg clk = 0; 
    reg reset_n = 0; 
     
    // Test Interface Signals 
    reg                    write_req; 
    reg [ADDR_WIDTH-1:0]   write_addr; 
    reg [DATA_WIDTH-1:0]   write_data; 
    reg [STRB_WIDTH-1:0]   write_strb; 
    wire                   write_done; 
    wire [1:0]             write_resp; 
     
    reg                    read_req; 
    reg [ADDR_WIDTH-1:0]   read_addr; 
    wire [DATA_WIDTH-1:0]  read_data; 
    wire                   read_done; 
    wire [1:0]             read_resp; 
     
    // Test Control 
    integer test_case = 0; 
    integer errors = 0; 
    integer tests_passed = 0; 
     
    // Clock Generation 
    always #(CLK_PERIOD/2) clk = ~clk; 
     
    // DUT Instantiation 
    axi4_lite_system_top #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .STRB_WIDTH(STRB_WIDTH) 
 
 
    ) dut ( 
        .clk(clk), 
        .reset_n(reset_n), 
        .write_req(write_req), 
        .write_addr(write_addr), 
        .write_data(write_data), 
        .write_strb(write_strb), 
        .write_done(write_done), 
        .write_resp(write_resp), 
        .read_req(read_req), 
        .read_addr(read_addr), 
        .read_data(read_data), 
        .read_done(read_done), 
        .read_resp(read_resp) 
    ); 
     
    // Reset Task 
    task reset_system; 
        begin 
            $display("=== Applying Reset ==="); 
            reset_n = 0; 
            write_req = 0; 
            read_req = 0; 
            write_addr = 0; 
            write_data = 0; 
            write_strb = 0; 
            read_addr = 0; 
             
            repeat(5) @(posedge clk); 
            reset_n = 1; 
            repeat(2) @(posedge clk); 
            $display("=== Reset Complete ==="); 
        end 
    endtask 
     
    // Write Task 
    task axi_write( 
        input [ADDR_WIDTH-1:0] addr, 
        input [DATA_WIDTH-1:0] data, 
        input [STRB_WIDTH-1:0] strb 
    ); 
        begin 
            @(posedge clk); 
            write_req = 1; 
            write_addr = addr; 
            write_data = data; 
            write_strb = strb; 
             
            @(posedge clk); 
            write_req = 0; 
 
 
             
            // Wait for completion 
            wait(write_done); 
            @(posedge clk); 
             
            $display("Time: %0t | Write: Addr=0x%08h, Data=0x%08h, Strb=0x%01h, Resp=%0d", 
                     $time, addr, data, strb, write_resp); 
        end 
    endtask 
     
    // Read Task 
    task axi_read( 
        input [ADDR_WIDTH-1:0] addr, 
        output [DATA_WIDTH-1:0] data, 
        output [1:0] resp 
    ); 
        begin 
            @(posedge clk); 
            read_req = 1; 
            read_addr = addr; 
             
            @(posedge clk); 
            read_req = 0; 
             
            // Wait for completion 
            wait(read_done); 
            @(posedge clk); 
             
            data = read_data; 
            resp = read_resp; 
             
            $display("Time: %0t | Read: Addr=0x%08h, Data=0x%08h, Resp=%0d", 
                     $time, addr, data, resp); 
        end 
    endtask 
     
    // Data Comparison Task 
    task check_data( 
        input [DATA_WIDTH-1:0] expected, 
        input [DATA_WIDTH-1:0] actual, 
        input string test_name 
    ); 
        begin 
            if (expected == actual) begin 
                $display("✓ PASS: %s - Expected: 0x%08h, Got: 0x%08h", test_name, expected, actual); 
                tests_passed++; 
            end else begin 
                $display("✗ FAIL: %s - Expected: 0x%08h, Got: 0x%08h", test_name, expected, actual); 
                errors++; 
 
 
            end 
        end 
    endtask 
     
    // Response Check Task 
    task check_response( 
        input [1:0] expected_resp, 
        input [1:0] actual_resp, 
        input string test_name 
    ); 
        begin 
            if (expected_resp == actual_resp) begin 
                $display("✓ PASS: %s Response - Expected: %0d, Got: %0d", test_name, expected_resp, 
actual_resp); 
                tests_passed++; 
            end else begin 
                $display("✗ FAIL: %s Response - Expected: %0d, Got: %0d", test_name, expected_resp, 
actual_resp); 
                errors++; 
            end 
        end 
    endtask 
     
    // Test Scenarios 
    initial begin 
        $display("================================="); 
        $display("    AXI4-Lite Protocol Test"); 
        $display("================================="); 
         
        // Initialize VCD dump 
        $dumpfile("axi4_lite_tb.vcd"); 
        $dumpvars(0, axi4_lite_tb); 
         
        // Test Case 1: Basic Write Single Beat 
        test_case = 1; 
        $display("\n--- Test Case %0d: Basic Write Single Beat ---", test_case); 
        reset_system(); 
         
        axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF); 
        check_response(2'b00, write_resp, "Basic Write"); 
         
        // Test Case 2: Basic Read Single Beat   
        test_case = 2; 
        $display("\n--- Test Case %0d: Basic Read Single Beat ---", test_case); 
         
        reg [DATA_WIDTH-1:0] read_data_temp; 
        reg [1:0] read_resp_temp; 
        axi_read(32'h0000_0000, read_data_temp, read_resp_temp); 
        check_data(32'hDEAD_BEEF, read_data_temp, "Basic Read"); 
 
 
        check_response(2'b00, read_resp_temp, "Basic Read"); 
         
        // Test Case 3: Write with Byte Enables 
        test_case = 3; 
        $display("\n--- Test Case %0d: Write with Byte Enables ---", test_case); 
         
        axi_write(32'h0000_0004, 32'h1234_5678, 4'h3); // Only lower 2 bytes 
        axi_read(32'h0000_0004, read_data_temp, read_resp_temp); 
        check_data(32'h0000_5678, read_data_temp, "Byte Enable Write"); 
         
        // Test Case 4: Multiple Sequential Writes 
        test_case = 4; 
        $display("\n--- Test Case %0d: Multiple Sequential Writes ---", test_case); 
         
        for (int i = 0; i < 4; i++) begin 
            axi_write(32'h0000_0010 + (i*4), 32'hA000_0000 + i, 4'hF); 
        end 
         
        for (int i = 0; i < 4; i++) begin 
            axi_read(32'h0000_0010 + (i*4), read_data_temp, read_resp_temp); 
            check_data(32'hA000_0000 + i, read_data_temp, $sformatf("Sequential Write %0d", i)); 
        end 
         
        // Test Case 5: Write-Read-Write Pattern 
        test_case = 5; 
        $display("\n--- Test Case %0d: Write-Read-Write Pattern ---", test_case); 
         
        axi_write(32'h0000_0020, 32'hCAFE_BABE, 4'hF); 
        axi_read(32'h0000_0020, read_data_temp, read_resp_temp); 
        check_data(32'hCAFE_BABE, read_data_temp, "WRW Pattern Read"); 
        axi_write(32'h0000_0020, 32'hFEED_FACE, 4'hF); 
        axi_read(32'h0000_0020, read_data_temp, read_resp_temp); 
        check_data(32'hFEED_FACE, read_data_temp, "WRW Pattern Final Read"); 
         
        // Test Case 6: Error Response Test (Invalid Address) 
        test_case = 6; 
        $display("\n--- Test Case %0d: Error Response Test ---", test_case); 
         
        axi_write(32'hFFFF_FFFF, 32'h1111_1111, 4'hF); // Invalid address 
        check_response(2'b10, write_resp, "Invalid Write Address"); 
         
        axi_read(32'hFFFF_FFFF, read_data_temp, read_resp_temp); // Invalid address 
        check_response(2'b10, read_resp_temp, "Invalid Read Address"); 
         
        // Test Case 7: Boundary Address Test 
        test_case = 7; 
        $display("\n--- Test Case %0d: Boundary Address Test ---", test_case); 
         
        axi_write(32'h0000_03FC, 32'h5A5A_A5A5, 4'hF); // Last valid address 
        axi_read(32'h0000_03FC, read_data_temp, read_resp_temp); 
 
 
        check_data(32'h5A5A_A5A5, read_data_temp, "Boundary Address"); 
        check_response(2'b00, read_resp_temp, "Boundary Address"); 
         
        // Test Case 8: Random Data Pattern Test 
        test_case = 8; 
        $display("\n--- Test Case %0d: Random Data Pattern Test ---", test_case); 
         
        reg [DATA_WIDTH-1:0] random_data; 
        reg [ADDR_WIDTH-1:0] random_addr; 
         
        for (int i = 0; i < 10; i++) begin 
            random_data = $random; 
            random_addr = ($random % 256) << 2; // Ensure 4-byte aligned 
            axi_write(random_addr, random_data, 4'hF); 
            axi_read(random_addr, read_data_temp, read_resp_temp); 
            check_data(random_data, read_data_temp, $sformatf("Random Test %0d", i)); 
        end 
         
        // Test Summary 
        $display("\n================================="); 
        $display("        Test Summary"); 
        $display("================================="); 
        $display("Total Tests: %0d", tests_passed + errors); 
        $display("Passed: %0d", tests_passed); 
        $display("Failed: %0d", errors); 
         
        if (errors == 0) begin 
            $display("✓ ALL TESTS PASSED!"); 
        end else begin 
            $display("✗ %0d TESTS FAILED!", errors); 
        end 
         
        $display("================================="); 
         
        repeat(10) @(posedge clk); 
        $finish; 
    end 
     
    // Timeout Watchdog 
    initial begin 
        #1000000; // 1ms timeout 
        $display("ERROR: Simulation timeout!"); 
        $finish; 
    end 
endmodule 
