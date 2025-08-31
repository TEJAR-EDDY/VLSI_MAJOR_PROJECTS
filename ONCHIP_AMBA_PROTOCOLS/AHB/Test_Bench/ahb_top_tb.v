//=========================================================================== 
// AHB System Testbench 
// Comprehensive verification environment with multiple test scenarios 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_system_tb; 
 
    // Parameters 
    parameter ADDR_WIDTH = 32; 
    parameter DATA_WIDTH = 32; 
    parameter SLAVE_COUNT = 4; 
    parameter CLK_PERIOD = 10; // 100MHz clock 
     
    // Clock and Reset 
    reg HCLK; 
    reg HRESETn; 
     
    // Master Control Interface 
    reg                    start_transfer; 
    reg [ADDR_WIDTH-1:0]   start_addr; 
    reg [DATA_WIDTH-1:0]   write_data; 
    reg                    rw_mode; 
    reg [2:0]              transfer_size; 
    reg [2:0]              burst_type; 
    reg [7:0]              burst_length; 
    wire                   transfer_done; 
    wire [DATA_WIDTH-1:0]  read_data; 
    wire                   transfer_error; 
     
    // AHB Bus Signals 
    wire [ADDR_WIDTH-1:0]  HADDR; 
    wire [1:0]             HTRANS; 
    wire                   HWRITE; 
    wire [2:0]             HSIZE; 
    wire [2:0]             HBURST; 
    wire [3:0]             HPROT; 
    wire [DATA_WIDTH-1:0]  HWDATA; 
    wire [DATA_WIDTH-1:0]  HRDATA; 
    wire                   HREADY; 
    wire [1:0]             HRESP; 
     
    // Slave Interface Signals 
    wire [ADDR_WIDTH-1:0]          HADDR_slaves; 
    wire [1:0]                     HTRANS_slaves; 
    wire                           HWRITE_slaves; 
    wire [2:0]                     HSIZE_slaves; 
    wire [2:0]                     HBURST_slaves; 
    wire [3:0]                     HPROT_slaves; 
    wire [DATA_WIDTH-1:0]          HWDATA_slaves; 
    wire [SLAVE_COUNT-1:0]         HSEL_slaves; 
    wire [SLAVE_COUNT*DATA_WIDTH-1:0] HRDATA_slaves; 
    wire [SLAVE_COUNT-1:0]         HREADY_slaves; 
    wire [SLAVE_COUNT*2-1:0]       HRESP_slaves; 
     
    // Test Control Variables 
    integer test_count = 0; 
    integer pass_count = 0; 
    integer fail_count = 0; 
    reg [DATA_WIDTH-1:0] expected_data; 
     
    //----------------------------------------------------------------------- 
    // Clock Generation 
    //----------------------------------------------------------------------- 
    initial begin 
        HCLK = 0; 
        forever #(CLK_PERIOD/2) HCLK = ~HCLK; 
    end 
     
    //----------------------------------------------------------------------- 
    // Reset Generation 
    //----------------------------------------------------------------------- 
    initial begin 
        HRESETn = 0; 
        #(CLK_PERIOD * 3); 
        HRESETn = 1; 
        $display("=== AHB System Reset Released ==="); 
    end 
     
    //----------------------------------------------------------------------- 
    // DUT Instantiation - AHB Master 
    //----------------------------------------------------------------------- 
    ahb_master #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_PERIOD(CLK_PERIOD) 
    ) master_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR), 
        .HTRANS(HTRANS), 
        .HWRITE(HWRITE), 
        .HSIZE(HSIZE), 
        .HBURST(HBURST), 
        .HPROT(HPROT), 
        .HWDATA(HWDATA), 
        .HRDATA(HRDATA), 
        .HREADY(HREADY), 
        .HRESP(HRESP), 
        .start_transfer(start_transfer), 
        .start_addr(start_addr), 
        .write_data(write_data), 
        .rw_mode(rw_mode), 
        .transfer_size(transfer_size), 
        .burst_type(burst_type), 
        .burst_length(burst_length), 
        .transfer_done(transfer_done), 
        .read_data(read_data), 
        .transfer_error(transfer_error) 
    ); 
     
    //----------------------------------------------------------------------- 
    // DUT Instantiation - AHB Interconnect 
    //----------------------------------------------------------------------- 
    ahb_interconnect #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .SLAVE_COUNT(SLAVE_COUNT) 
    ) interconnect_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR), 
        .HTRANS(HTRANS), 
        .HWRITE(HWRITE), 
        .HSIZE(HSIZE), 
        .HBURST(HBURST), 
        .HPROT(HPROT), 
        .HWDATA(HWDATA), 
        .HRDATA(HRDATA), 
        .HREADY(HREADY), 
        .HRESP(HRESP), 
        .HADDR_slaves(HADDR_slaves), 
        .HTRANS_slaves(HTRANS_slaves), 
        .HWRITE_slaves(HWRITE_slaves), 
        .HSIZE_slaves(HSIZE_slaves), 
        .HBURST_slaves(HBURST_slaves), 
        .HPROT_slaves(HPROT_slaves), 
        .HWDATA_slaves(HWDATA_slaves), 
        .HSEL_slaves(HSEL_slaves), 
        .HRDATA_slaves(HRDATA_slaves), 
        .HREADY_slaves(HREADY_slaves), 
        .HRESP_slaves(HRESP_slaves) 
    ); 
     
    //----------------------------------------------------------------------- 
    // Slave Instantiations 
    //----------------------------------------------------------------------- 
    // Slave 0 - Fast Memory (No wait states) 
    ahb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .MEMORY_DEPTH(1024), 
        .WAIT_STATES(0) 
    ) slave0_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR_slaves), 
        .HTRANS(HTRANS_slaves), 
        .HWRITE(HWRITE_slaves), 
        .HSIZE(HSIZE_slaves), 
        .HBURST(HBURST_slaves), 
        .HPROT(HPROT_slaves), 
        .HWDATA(HWDATA_slaves), 
        .HSEL(HSEL_slaves[0]), 
        .HRDATA(HRDATA_slaves[DATA_WIDTH-1:0]), 
        .HREADY(HREADY_slaves[0]), 
        .HRESP(HRESP_slaves[1:0]) 
    ); 
     
    // Slave 1 - Slow Timer (2 wait states) 
    ahb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .MEMORY_DEPTH(256), 
        .WAIT_STATES(2) 
    ) slave1_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR_slaves), 
        .HTRANS(HTRANS_slaves), 
        .HWRITE(HWRITE_slaves), 
        .HSIZE(HSIZE_slaves), 
        .HBURST(HBURST_slaves), 
        .HPROT(HPROT_slaves), 
        .HWDATA(HWDATA_slaves), 
        .HSEL(HSEL_slaves[1]), 
        .HRDATA(HRDATA_slaves[2*DATA_WIDTH-1:DATA_WIDTH]), 
        .HREADY(HREADY_slaves[1]), 
        .HRESP(HRESP_slaves[3:2]) 
    ); 
     
    // Slave 2 - UART (1 wait state) 
    ahb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .MEMORY_DEPTH(64), 
        .WAIT_STATES(1) 
    ) slave2_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR_slaves), 
        .HTRANS(HTRANS_slaves), 
        .HWRITE(HWRITE_slaves), 
        .HSIZE(HSIZE_slaves), 
        .HBURST(HBURST_slaves), 
        .HPROT(HPROT_slaves), 
        .HWDATA(HWDATA_slaves), 
        .HSEL(HSEL_slaves[2]), 
        .HRDATA(HRDATA_slaves[3*DATA_WIDTH-1:2*DATA_WIDTH]), 
        .HREADY(HREADY_slaves[2]), 
        .HRESP(HRESP_slaves[5:4]) 
    ); 
     
    // Slave 3 - GPIO (No wait states) 
    ahb_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .MEMORY_DEPTH(32), 
        .WAIT_STATES(0) 
    ) slave3_inst ( 
        .HCLK(HCLK), 
        .HRESETn(HRESETn), 
        .HADDR(HADDR_slaves), 
        .HTRANS(HTRANS_slaves), 
        .HWRITE(HWRITE_slaves), 
        .HSIZE(HSIZE_slaves), 
        .HBURST(HBURST_slaves), 
        .HPROT(HPROT_slaves), 
        .HWDATA(HWDATA_slaves), 
        .HSEL(HSEL_slaves[3]), 
        .HRDATA(HRDATA_slaves[4*DATA_WIDTH-1:3*DATA_WIDTH]), 
        .HREADY(HREADY_slaves[3]), 
        .HRESP(HRESP_slaves[7:6]) 
    ); 
     
    //----------------------------------------------------------------------- 
    // Test Tasks 
    //----------------------------------------------------------------------- 
     
    // Task: Single Write Transfer 
    task single_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data); 
        begin 
            $display("TEST %0d: Single Write to 0x%08h = 0x%08h", test_count, addr, data); 
            test_count = test_count + 1; 
             
            start_addr = addr; 
            write_data = data; 
            rw_mode = 1'b1; // Write 
            transfer_size = 3'b010; // 32-bit 
            burst_type = 3'b000; // SINGLE 
            burst_length = 8'h01; 
             
            start_transfer = 1'b1; 
            @(posedge HCLK); 
            start_transfer = 1'b0; 
             
            // Wait for completion 
            wait(transfer_done || transfer_error); 
             
            if (transfer_error) begin 
                $display("  FAIL: Transfer error occurred"); 
                fail_count = fail_count + 1; 
            end else begin 
                $display("  PASS: Write completed successfully"); 
                pass_count = pass_count + 1; 
            end 
             
            repeat(2) @(posedge HCLK); 
        end 
    endtask 
     
    // Task: Single Read Transfer 
    task single_read(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] expected); 
        begin 
            $display("TEST %0d: Single Read from 0x%08h (expect 0x%08h)", test_count, addr, expected); 
            test_count = test_count + 1; 
             
            start_addr = addr; 
            write_data = 32'h0; 
            rw_mode = 1'b0; // Read 
            transfer_size = 3'b010; // 32-bit 
            burst_type = 3'b000; // SINGLE 
            burst_length = 8'h01; 
             
            start_transfer = 1'b1; 
            @(posedge HCLK); 
            start_transfer = 1'b0; 
             
            // Wait for completion 
            wait(transfer_done || transfer_error); 
             
            if (transfer_error) begin 
                $display("  FAIL: Transfer error occurred"); 
                fail_count = fail_count + 1; 
            end else if (read_data == expected) begin 
                $display("  PASS: Read data 0x%08h matches expected", read_data); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("  FAIL: Read data 0x%08h != expected 0x%08h", read_data, expected); 
                fail_count = fail_count + 1; 
            end 
             
            repeat(2) @(posedge HCLK); 
        end 
    endtask 
     
    // Task: Burst Write Transfer 
    task burst_write(input [ADDR_WIDTH-1:0] addr, input [2:0] btype, input [7:0] length); 
        begin 
            $display("TEST %0d: Burst Write to 0x%08h, type=%0d, length=%0d", test_count, addr, btype, length); 
            test_count = test_count + 1; 
             
            start_addr = addr; 
            write_data = 32'hDEADBEEF; 
            rw_mode = 1'b1; // Write 
            transfer_size = 3'b010; // 32-bit 
            burst_type = btype; 
            burst_length = length; 
             
            start_transfer = 1'b1; 
            @(posedge HCLK); 
            start_transfer = 1'b0; 
             
            // Wait for completion 
            wait(transfer_done || transfer_error); 
             
            if (transfer_error) begin 
                $display("  FAIL: Burst write error occurred"); 
                fail_count = fail_count + 1; 
            end else begin 
                $display("  PASS: Burst write completed successfully"); 
                pass_count = pass_count + 1; 
            end 
             
            repeat(2) @(posedge HCLK); 
        end 
    endtask 
     
    // Task: Test Error Response 
    task test_error_response(); 
        begin 
            $display("TEST %0d: Error Response Test (Invalid Address)", test_count); 
            test_count = test_count + 1; 
             
            start_addr = 32'hFFFFFFFF; // Invalid address 
            write_data = 32'h12345678; 
            rw_mode = 1'b1; // Write 
            transfer_size = 3'b010; // 32-bit 
            burst_type = 3'b000; // SINGLE 
            burst_length = 8'h01; 
             
            start_transfer = 1'b1; 
            @(posedge HCLK); 
            start_transfer = 1'b0; 
             
            // Wait for completion 
            wait(transfer_done || transfer_error); 
             
            if (transfer_error) begin 
                $display("  PASS: Error correctly detected for invalid address"); 
                pass_count = pass_count + 1; 
            end else begin 
                $display("  FAIL: Expected error not detected"); 
                fail_count = fail_count + 1; 
            end 
             
            repeat(2) @(posedge HCLK); 
        end 
    endtask 
     
    //----------------------------------------------------------------------- 
    // Main Test Sequence 
    //----------------------------------------------------------------------- 
    initial begin 
        // Initialize signals 
        start_transfer = 1'b0; 
        start_addr = 32'h0; 
        write_data = 32'h0; 
        rw_mode = 1'b0; 
        transfer_size = 3'b010; 
        burst_type = 3'b000; 
        burst_length = 8'h01; 
         
        // Wait for reset 
        wait(HRESETn); 
        repeat(5) @(posedge HCLK); 
         
        $display("\n=== Starting AHB Protocol Verification ===\n"); 
         
        // Test Case 1: Basic Single Transfers to Different Slaves 
        single_write(32'h00000000, 32'h12345678); // Memory 
        single_read(32'h00000000, 32'h12345678); 
         
        single_write(32'h10000004, 32'hAABBCCDD); // Timer 
        single_read(32'h10000004, 32'hAABBCCDD); 
         
        single_write(32'h20000008, 32'h55AA55AA); // UART   
        single_read(32'h20000008, 32'h55AA55AA); 
         
        single_write(32'h3000000C, 32'hF0F0F0F0); // GPIO 
        single_read(32'h3000000C, 32'hF0F0F0F0); 
         
        // Test Case 2: Burst Transfers 
        burst_write(32'h00000010, 3'b011, 8'h04); // INCR4 to Memory 
        burst_write(32'h00000020, 3'b101, 8'h08); // INCR8 to Memory 
        burst_write(32'h00000100, 3'b010, 8'h04); // WRAP4 to Memory 
         
        // Test Case 3: Wait State Testing (Timer has 2 wait states) 
        single_write(32'h10000010, 32'h57414954); // Fixed: removed invalid hex literals 
        single_read(32'h10000010, 32'h57414954); 
         
        // Test Case 4: Error Response Testing 
        test_error_response(); 
         
        // Test Case 5: Address Boundary Testing 
        single_write(32'h0FFFFFFC, 32'h424F554E); // Fixed: removed invalid hex literals 
        single_read(32'h0FFFFFFC, 32'h424F554E); 
         
        // Final Results 
        repeat(10) @(posedge HCLK); 
         
        $display("\n=== Test Results Summary ==="); 
        $display("Total Tests: %0d", test_count); 
        $display("Passed: %0d", pass_count); 
        $display("Failed: %0d", fail_count); 
        $display("Success Rate: %0.1f%%", (pass_count * 100.0) / test_count); 
         
        if (fail_count == 0) begin 
            $display("\n ALL TESTS PASSED! AHB Protocol Implementation Verified Successfully! "); 
        end else begin 
            $display("\n SOME TESTS FAILED. Please review the implementation."); 
        end 
         
        $finish; 
    end 
     
    //----------------------------------------------------------------------- 
    // Waveform Dump 
    //----------------------------------------------------------------------- 
    initial begin 
        $dumpfile("ahb_system.vcd"); 
        $dumpvars(0, ahb_system_tb); 
    end 
     
endmodule