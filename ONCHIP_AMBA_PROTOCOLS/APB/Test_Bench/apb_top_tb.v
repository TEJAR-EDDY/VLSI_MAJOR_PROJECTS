//  Author: Teja Reddy
// Comprehensive testbench for APB system 
 
`timescale 1ns/1ps 
 
module apb_system_tb; 
 
    // Parameters 
    parameter CLK_PERIOD = 10; // 100MHz 
    parameter ADDR_WIDTH = 32; 
    parameter DATA_WIDTH = 32; 
    parameter NUM_SLAVES = 3; 
     
    // System signals 
    reg                    pclk; 
    reg                    presetn; 
     
    // Control interface 
    reg                    transfer_req; 
    reg  [ADDR_WIDTH-1:0]  transfer_addr; 
    reg  [DATA_WIDTH-1:0]  transfer_wdata; 
    reg                    transfer_write; 
    wire                   transfer_ready; 
    wire [DATA_WIDTH-1:0]  transfer_rdata; 
    wire                   transfer_error; 
     
    // Test control 
    int                    test_count; 
    int                    pass_count; 
    int                    fail_count; 
 
 
     
    // Expected results 
    reg [DATA_WIDTH-1:0]   expected_rdata; 
    reg                    expected_error; 
 
    // DUT instantiation 
    apb_system_top #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .NUM_SLAVES(NUM_SLAVES) 
    ) dut ( 
        .pclk           (pclk), 
        .presetn        (presetn), 
        .transfer_req   (transfer_req), 
        .transfer_addr  (transfer_addr), 
        .transfer_wdata (transfer_wdata), 
        .transfer_write (transfer_write), 
        .transfer_ready (transfer_ready), 
        .transfer_rdata (transfer_rdata), 
        .transfer_error (transfer_error) 
    ); 
 
    // Clock generation 
    initial begin 
        pclk = 0; 
        forever #(CLK_PERIOD/2) pclk = ~pclk; 
    end 
     
    // Reset generation 
    initial begin 
        presetn = 0; 
        #(CLK_PERIOD * 5); 
        presetn = 1; 
        $display("[%0t] Reset released", $time); 
    end 
     
    // Test sequence 
    initial begin 
        // Initialize 
        initialize_signals(); 
        wait(presetn); 
        #(CLK_PERIOD * 2); 
         
        $display("\n=== APB System Verification Started ==="); 
         
        // Test Cases 
        test_basic_write(); 
        test_basic_read(); 
        test_write_read_sequence(); 
        test_multi_slave_access(); 
 
 
        test_wait_states(); 
        test_error_conditions(); 
        test_back_to_back_transfers(); 
         
        // Results summary 
        display_results(); 
         
        #(CLK_PERIOD * 10); 
        $finish; 
    end 
     
    // Task: Initialize signals 
    task initialize_signals(); 
        transfer_req   = 0; 
        transfer_addr  = 0; 
        transfer_wdata = 0; 
        transfer_write = 0; 
        test_count     = 0; 
        pass_count     = 0; 
        fail_count     = 0; 
    endtask 
     
    // Task: Basic write test 
    task test_basic_write(); 
        $display("\n[TEST 1] Basic Write Test"); 
         
        apb_write(32'h00000000, 32'hA5A5A5A5); 
        check_no_error("Basic Write"); 
         
        apb_write(32'h00000004, 32'h12345678); 
        check_no_error("Basic Write 2"); 
         
    endtask 
     
    // Task: Basic read test 
    task test_basic_read(); 
        $display("\n[TEST 2] Basic Read Test"); 
         
        // Read from slave 0 (should return initialized pattern) 
        apb_read(32'h00000000, 32'h00000000); 
        check_result("Basic Read Slave 0", 32'h00000000, 1'b0); 
         
        // Read from slave 1 
        apb_read(32'h00010000, 32'h01000000); 
        check_result("Basic Read Slave 1", 32'h01000000, 1'b0); 
         
    endtask 
     
    // Task: Write-Read sequence test 
    task test_write_read_sequence(); 
 
 
        $display("\n[TEST 3] Write-Read Sequence Test"); 
         
        // Write then read back from same location 
        apb_write(32'h00000008, 32'hDEADBEEF); 
        check_no_error("Write in sequence"); 
         
        apb_read(32'h00000008, 32'hDEADBEEF); 
        check_result("Read back", 32'hDEADBEEF, 1'b0); 
         
        // Test different slaves 
        apb_write(32'h00010004, 32'hCAFEBABE); 
        check_no_error("Write Slave 1"); 
         
        apb_read(32'h00010004, 32'hCAFEBABE); 
        check_result("Read Slave 1", 32'hCAFEBABE, 1'b0); 
         
    endtask 
     
    // Task: Multi-slave access test 
    task test_multi_slave_access(); 
        $display("\n[TEST 4] Multi-Slave Access Test"); 
         
        // Access all slaves 
        for (int i = 0; i < NUM_SLAVES; i++) begin 
            automatic reg [31:0] addr = i << 16; // 64KB spacing 
            automatic reg [31:0] data = 32'hA0000000 + i; 
             
            $display("  Accessing Slave %0d at address 0x%08X", i, addr); 
            apb_write(addr, data); 
            check_no_error($sformatf("Multi-slave write %0d", i)); 
             
            apb_read(addr, data); 
            check_result($sformatf("Multi-slave read %0d", i), data, 1'b0); 
        end 
         
    endtask 
     
    // Task: Wait states test 
    task test_wait_states(); 
        $display("\n[TEST 5] Wait States Test"); 
         
        // Slave 0 has 0 wait states 
        // Slave 1 has 1 wait state   
        // Slave 2 has 2 wait states 
         
        $display("  Testing Slave 2 (2 wait states)"); 
        apb_write(32'h00020000, 32'h55555555); 
        check_no_error("Wait states write"); 
         
        apb_read(32'h00020000, 32'h55555555); 
 
 
        check_result("Wait states read", 32'h55555555, 1'b0); 
         
    endtask 
     
    // Task: Error conditions test 
    task test_error_conditions(); 
        $display("\n[TEST 6] Error Conditions Test"); 
         
        // Test invalid address (no slave mapped) 
        apb_read(32'hFF000000, 32'h00000000); 
        check_result("Invalid address", 32'h00000000, 1'b1); 
         
        apb_write(32'h80000000, 32'h12345678); 
        check_error("Invalid write address"); 
         
    endtask 
     
    // Task: Back-to-back transfers test 
    task test_back_to_back_transfers(); 
        $display("\n[TEST 7] Back-to-Back Transfers Test"); 
         
        // Multiple consecutive transfers 
        apb_write(32'h00000010, 32'h11111111); 
        check_no_error("Back-to-back 1"); 
         
        apb_write(32'h00000014, 32'h22222222); 
        check_no_error("Back-to-back 2"); 
         
        apb_read(32'h00000010, 32'h11111111); 
        check_result("Back-to-back read 1", 32'h11111111, 1'b0); 
         
        apb_read(32'h00000014, 32'h22222222); 
        check_result("Back-to-back read 2", 32'h22222222, 1'b0); 
         
    endtask 
     
    // Task: APB Write operation 
    task apb_write(input [31:0] addr, input [31:0] data); 
        @(posedge pclk); 
        transfer_req   = 1; 
        transfer_addr  = addr; 
        transfer_wdata = data; 
        transfer_write = 1; 
         
        @(posedge pclk); 
        transfer_req = 0; 
         
        // Wait for completion 
        wait(transfer_ready); 
        @(posedge pclk); 
 
 
         
        $display("    WRITE: Addr=0x%08X, Data=0x%08X, Error=%b",  
                 addr, data, transfer_error); 
    endtask 
     
    // Task: APB Read operation 
    task apb_read(input [31:0] addr, input [31:0] expected_data); 
        expected_rdata = expected_data; 
        expected_error = 1'b0; 
         
        @(posedge pclk); 
        transfer_req   = 1; 
        transfer_addr  = addr; 
        transfer_wdata = 0; 
        transfer_write = 0; 
         
        @(posedge pclk); 
        transfer_req = 0; 
         
        // Wait for completion 
        wait(transfer_ready); 
        @(posedge pclk); 
         
        $display("    READ:  Addr=0x%08X, Data=0x%08X, Error=%b",  
                 addr, transfer_rdata, transfer_error); 
    endtask 
     
    // Task: Check results 
    task check_result(input string test_name, input [31:0] exp_data, input exp_error); 
        test_count++; 
        if (transfer_rdata == exp_data && transfer_error == exp_error) begin 
            pass_count++; 
            $display("    ✓ PASS: %s", test_name); 
        end else begin 
            fail_count++; 
            $display("    ✗ FAIL: %s - Expected: Data=0x%08X, Error=%b | Got: Data=0x%08X, Error=%b",  
                     test_name, exp_data, exp_error, transfer_rdata, transfer_error); 
        end 
    endtask 
     
    // Task: Check no error 
    task check_no_error(input string test_name); 
        test_count++; 
        if (!transfer_error) begin 
            pass_count++; 
            $display("    ✓ PASS: %s", test_name); 
        end else begin 
            fail_count++; 
            $display("    ✗ FAIL: %s - Unexpected error", test_name); 
 
 
        end 
    endtask 
     
    // Task: Check error expected 
    task check_error(input string test_name); 
        test_count++; 
        if (transfer_error) begin 
            pass_count++; 
            $display("    ✓ PASS: %s", test_name); 
        end else begin 
            fail_count++; 
            $display("    ✗ FAIL: %s - Error expected but not received", test_name); 
        end 
    endtask 
     
    // Task: Display final results 
    task display_results(); 
        $display("\n=== Test Results Summary ==="); 
        $display("Total Tests: %0d", test_count); 
        $display("Passed:      %0d", pass_count); 
        $display("Failed:      %0d", fail_count); 
        $display("Success Rate: %0.1f%%", (pass_count * 100.0) / test_count); 
         
        if (fail_count == 0) begin 
            $display (" ALL TESTS PASSED!"); 
        end else begin 
            $display (" Some tests failed. Check logs above."); 
        end 
    endtask 
     
    // Waveform dumping 
    initial begin 
        $dumpfile("apb_system.vcd"); 
        $dumpvars(0, apb_system_tb); 
    end 
 
endmodule
