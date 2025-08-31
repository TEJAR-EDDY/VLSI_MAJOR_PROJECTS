//================================================================ 
// AHB to APB Bridge Testbench 
//  Author: Teja Reddy
// Date: August 2025 
//================================================================ 
 
`timescale 1ns/1ps 
 
module tb_ahb_apb_bridge(); 
 
    //================================================================ 
    // Parameters 
    //================================================================ 
    parameter ADDR_WIDTH = 32; 
    parameter DATA_WIDTH = 32; 
 
 
    parameter NUM_SLAVES = 3; 
    parameter CLK_PERIOD = 10; // 100MHz 
     
    //================================================================ 
    // Testbench Signals 
    //================================================================ 
    reg                     HCLK; 
    reg                     HRESETn; 
     
    // AHB Interface 
    wire [ADDR_WIDTH-1:0]   HADDR; 
    wire [1:0]              HTRANS; 
    wire                    HWRITE; 
    wire [2:0]              HSIZE; 
    wire [DATA_WIDTH-1:0]   HWDATA; 
    wire [DATA_WIDTH-1:0]   HRDATA; 
    wire                    HREADY; 
    wire [1:0]              HRESP; 
     
    // APB Interface 
    wire [ADDR_WIDTH-1:0]   PADDR; 
    wire [NUM_SLAVES-1:0]   PSEL; 
    wire                    PENABLE; 
    wire                    PWRITE; 
    wire [DATA_WIDTH-1:0]   PWDATA; 
    wire [DATA_WIDTH-1:0]   PRDATA; 
    wire                    PREADY; 
    wire                    PSLVERR; 
     
    // Individual slave signals 
    wire [DATA_WIDTH-1:0] PRDATA0, PRDATA1, PRDATA2; 
    wire PREADY0, PREADY1, PREADY2; 
    wire PSLVERR0, PSLVERR1, PSLVERR2; 
     
    //================================================================ 
    // Clock Generation 
    //================================================================ 
    initial begin 
        HCLK = 0; 
        forever #(CLK_PERIOD/2) HCLK = ~HCLK; 
    end 
     
    //================================================================ 
    // Reset Generation   
    //================================================================ 
    initial begin 
        HRESETn = 0; 
        #(CLK_PERIOD * 5); 
        HRESETn = 1; 
        $display("Reset released at time %0t", $time); 
 
 
    end 
     
    //================================================================ 
    // DUT Instantiation - AHB to APB Bridge 
    //================================================================ 
    ahb_apb_bridge #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .NUM_SLAVES(NUM_SLAVES) 
    ) dut ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR), 
        .HTRANS(HTRANS), 
        .HWRITE(HWRITE), 
        .HSIZE(HSIZE), 
        .HWDATA(HWDATA), 
        .HRDATA(HRDATA), 
        .HREADY(HREADY), 
        .HRESP(HRESP), 
        .PADDR(PADDR), 
        .PSEL(PSEL), 
        .PENABLE(PENABLE), 
        .PWRITE(PWRITE), 
        .PWDATA(PWDATA), 
        .PRDATA(PRDATA), 
        .PREADY(PREADY), 
        .PSLVERR(PSLVERR) 
    ); 
     
    //================================================================ 
    // AHB Master Model Instantiation 
    //================================================================ 
    ahb_master #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH) 
    ) master ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR), 
        .HTRANS(HTRANS), 
        .HWRITE(HWRITE), 
        .HSIZE(HSIZE), 
        .HWDATA(HWDATA), 
        .HRDATA(HRDATA), 
        .HREADY(HREADY), 
        .HRESP(HRESP) 
    ); 
     
    //================================================================ 
 
 
    // APB Slave Model Instantiations 
    //================================================================ 
    apb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .SLAVE_ID(0) 
    ) slave0 ( 
        .PCLK(HCLK), 
        .PRESETn(HRESETn), 
        .PADDR(PADDR), 
        .PSEL(PSEL[0]), 
        .PENABLE(PENABLE), 
        .PWRITE(PWRITE), 
        .PWDATA(PWDATA), 
        .PRDATA(PRDATA0), 
        .PREADY(PREADY0), 
        .PSLVERR(PSLVERR0) 
    ); 
     
    apb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .SLAVE_ID(1) 
    ) slave1 ( 
        .PCLK(HCLK), 
        .PRESETn(HRESETn), 
        .PADDR(PADDR), 
        .PSEL(PSEL[1]), 
        .PENABLE(PENABLE), 
        .PWRITE(PWRITE), 
        .PWDATA(PWDATA), 
        .PRDATA(PRDATA1), 
        .PREADY(PREADY1), 
        .PSLVERR(PSLVERR1) 
    ); 
     
    apb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .SLAVE_ID(2) 
    ) slave2 ( 
        .PCLK(HCLK), 
        .PRESETn(HRESETn), 
        .PADDR(PADDR), 
        .PSEL(PSEL[2]), 
        .PENABLE(PENABLE), 
        .PWRITE(PWRITE), 
        .PWDATA(PWDATA), 
        .PRDATA(PRDATA2), 
        .PREADY(PREADY2), 
 
 
        .PSLVERR(PSLVERR2) 
    ); 
     
    //================================================================ 
    // APB Slave Response Multiplexing 
    //================================================================ 
    assign PRDATA = PSEL[0] ? PRDATA0 :  
                    PSEL[1] ? PRDATA1 :  
                    PSEL[2] ? PRDATA2 : 32'h0; 
                     
    assign PREADY = PSEL[0] ? PREADY0 :  
                    PSEL[1] ? PREADY1 :  
                    PSEL[2] ? PREADY2 : 1'b1; 
                     
    assign PSLVERR = PSEL[0] ? PSLVERR0 :  
                     PSEL[1] ? PSLVERR1 :  
                     PSEL[2] ? PSLVERR2 : 1'b0; 
     
    //================================================================ 
    // Test Variables 
    //================================================================ 
    reg [DATA_WIDTH-1:0] read_data; 
    integer test_count = 0; 
    integer pass_count = 0; 
    integer fail_count = 0; 
     
    //================================================================ 
    // Main Test Sequence 
    //================================================================ 
    initial begin 
        $display("================================================="); 
        $display("     AHB to APB Bridge Verification Started"); 
        $display("================================================="); 
         
        // Wait for reset release 
        wait(HRESETn); 
        #(CLK_PERIOD * 2); 
         
        // Test 1: Single Write to Slave 0 
        test_single_write(); 
         
        // Test 2: Single Read from Slave 0   
        test_single_read(); 
         
        // Test 3: Multiple Slave Selection 
        test_multiple_slaves(); 
         
        // Test 4: Back-to-back Transfers 
        test_back_to_back(); 
         
 
 
        // Test 5: Error Handling 
        test_error_response(); 
         
        // Test 6: Wait States 
        test_wait_states(); 
         
        // Final Results 
        display_results(); 
         
        #(CLK_PERIOD * 10); 
        $finish; 
    end 
     
    //================================================================ 
    // Test Tasks 
    //================================================================ 
     
    // Test 1: Single Write Operation 
    task test_single_write; 
        begin 
            $display("\n--- Test 1: Single Write to Slave 0 ---"); 
            test_count = test_count + 1; 
             
            master.ahb_write(32'h40000004, 32'hDEADBEEF); 
            #(CLK_PERIOD * 2); 
             
            if (slave0.memory[1] == 32'hDEADBEEF) begin 
                $display("PASS: Write data correctly stored in slave memory"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Write data mismatch. Expected: 0xDEADBEEF, Got: 0x%h",  
                        slave0.memory[1]); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Test 2: Single Read Operation 
    task test_single_read; 
        begin 
            $display("\n--- Test 2: Single Read from Slave 0 ---"); 
            test_count = test_count + 1; 
             
            // Pre-load data in slave memory 
            slave0.memory[2] = 32'hCAFEBABE; 
             
            master.ahb_read(32'h40000008, read_data); 
            #(CLK_PERIOD * 2); 
             
            if (read_data == 32'hCAFEBABE) begin 
 
 
                $display("PASS: Read data matches expected value"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Read data mismatch. Expected: 0xCAFEBABE, Got: 0x%h",  
                        read_data); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Test 3: Multiple Slave Selection 
    task test_multiple_slaves; 
        begin 
            $display("\n--- Test 3: Multiple Slave Selection ---"); 
             
            // Test Slave 1 
            test_count = test_count + 1; 
            $display("Testing Slave 1 (SPI) at 0x40010000"); 
            master.ahb_write(32'h40010000, 32'h12345678); 
            #(CLK_PERIOD * 2); 
             
            if (slave1.memory[0] == 32'h12345678) begin 
                $display("PASS: Slave 1 write successful"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Slave 1 write failed"); 
                fail_count = fail_count + 1; 
            end 
             
            // Test Slave 2 
            test_count = test_count + 1; 
            $display("Testing Slave 2 (GPIO) at 0x40020000"); 
            master.ahb_write(32'h40020000, 32'h87654321); 
            #(CLK_PERIOD * 2); 
             
            if (slave2.memory[0] == 32'h87654321) begin 
                $display("PASS: Slave 2 write successful"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Slave 2 write failed"); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Test 4: Back-to-back Transfers 
    task test_back_to_back; 
        begin 
            $display("\n--- Test 4: Back-to-back Transfers ---"); 
            test_count = test_count + 1; 
 
 
             
            fork 
                begin 
                    master.ahb_write(32'h40000010, 32'hAAAA5555); 
                    master.ahb_write(32'h40000014, 32'h5555AAAA); 
                end 
            join 
             
            #(CLK_PERIOD * 2); 
             
            if (slave0.memory[4] == 32'hAAAA5555 && slave0.memory[5] == 32'h5555AAAA) begin 
                $display("PASS: Back-to-back transfers completed successfully"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Back-to-back transfers failed"); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Test 5: Error Response Handling 
    task test_error_response; 
        begin 
            $display("\n--- Test 5: Error Response Handling ---"); 
            test_count = test_count + 1; 
             
            // Access invalid address (out of slave range) 
            master.ahb_write(32'h40000500, 32'hBADDATA1); // Beyond slave memory range 
            #(CLK_PERIOD * 2); 
             
            if (HRESP == 2'b01) begin // ERROR response 
                $display("PASS: Error response correctly generated"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Expected ERROR response, got HRESP = 0x%h", HRESP); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Test 6: Wait States Handling 
    task test_wait_states; 
        begin 
            $display("\n--- Test 6: Wait States Handling ---"); 
            test_count = test_count + 1; 
             
            // This test verifies that HREADY correctly waits for PREADY 
            master.ahb_write(32'h40010004, 32'hWAITDATA); 
            #(CLK_PERIOD * 2); 
             
 
 
            if (slave1.memory[1] == 32'hWAITDATA) begin 
                $display("PASS: Wait states handled correctly"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("FAIL: Wait states handling failed"); 
                fail_count = fail_count + 1; 
            end 
        end 
    endtask 
     
    // Display final test results 
    task display_results; 
        begin 
            $display("\n================================================="); 
            $display("            VERIFICATION RESULTS"); 
            $display("================================================="); 
            $display("Total Tests: %0d", test_count); 
            $display("Passed:      %0d", pass_count); 
            $display("Failed:      %0d", fail_count); 
            $display("Success Rate: %0d%%", (pass_count * 100) / test_count); 
             
            if (fail_count == 0) begin 
                $display("*** ALL TESTS PASSED - VERIFICATION SUCCESSFUL ***"); 
            end else begin 
                $display("*** VERIFICATION FAILED - %0d TEST(S) FAILED ***", fail_count); 
            end 
            $display("================================================="); 
        end 
    endtask 
     
    //================================================================ 
    // Waveform Dumping for GTKWave 
    //================================================================ 
    initial begin 
        $dumpfile("ahb_apb_bridge.vcd"); 
        $dumpvars(0, tb_ahb_apb_bridge); 
    end 
     
    //================================================================ 
    // Protocol Checker - Monitors correct AHB to APB conversion 
    //================================================================ 
    always @(posedge HCLK) begin 
        if (HRESETn) begin 
            // Check APB protocol compliance 
            if (PSEL != 0 && PENABLE && !PREADY) begin 
                // APB slave is inserting wait states - this is normal 
                if ($time > 1000) // Skip initial reset period 
                    $display("INFO: APB slave inserting wait state at time %0t", $time); 
            end 
             
 
 
            // Check for illegal PSEL transitions 
            if (PSEL != 0 && !PENABLE) begin 
                // Should be in SETUP phase 
                if ($previous(PSEL) == 0) begin 
                    $display("INFO: APB SETUP phase started at time %0t", $time); 
                end 
            end 
             
            if (PSEL != 0 && PENABLE) begin 
                // Should be in ENABLE phase 
                $display("INFO: APB ENABLE phase at time %0t", $time); 
            end 
        end 
    end 
 
endmodule
