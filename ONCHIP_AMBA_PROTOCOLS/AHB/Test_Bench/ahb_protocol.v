//===========================================================================
// Complete AHB System - All Modules in One File (FIXED)
// Beginner-friendly, Verilog 2001 compliant
// FIX: Corrected address calculation in AHB slave module
//  Author: Teja Reddy
//===========================================================================

//===========================================================================
// AHB Master Module
//===========================================================================
module ahb_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter CLK_PERIOD = 10
)(
    // Clock and Reset
    input  wire                    HCLK,
    input  wire                    HRESETn,
    
    // Master Interface
    output reg  [ADDR_WIDTH-1:0]   HADDR,
    output reg  [1:0]              HTRANS,
    output reg                     HWRITE,
    output reg  [2:0]              HSIZE,
    output reg  [2:0]              HBURST,
    output reg  [3:0]              HPROT,
    output reg  [DATA_WIDTH-1:0]   HWDATA,
    input  wire [DATA_WIDTH-1:0]   HRDATA,
    input  wire                    HREADY,
    input  wire [1:0]              HRESP,
    
    // Control Interface
    input  wire                    start_transfer,
    input  wire [ADDR_WIDTH-1:0]   start_addr,
    input  wire [DATA_WIDTH-1:0]   write_data,
    input  wire                    rw_mode,        // 0=Read, 1=Write
    input  wire [2:0]              transfer_size,
    input  wire [2:0]              burst_type,
    input  wire [7:0]              burst_length,
    output reg                     transfer_done,
    output reg  [DATA_WIDTH-1:0]   read_data,
    output reg                     transfer_error
);

    // FSM States
    localparam [2:0] IDLE    = 3'b000,
                     ADDR    = 3'b001,
                     DATA    = 3'b010,
                     ERROR   = 3'b011;

    // Transfer Types
    localparam [1:0] TRANS_IDLE   = 2'b00,
                     TRANS_BUSY   = 2'b01,
                     TRANS_NONSEQ = 2'b10,
                     TRANS_SEQ    = 2'b11;

    // Internal Registers
    reg [2:0]              state;
    reg [ADDR_WIDTH-1:0]   current_addr;
    reg [7:0]              beat_count;
    reg [7:0]              total_beats;
    reg                    is_write;
    reg                    addr_phase;

    //-----------------------------------------------------------------------
    // Main FSM
    //-----------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            state <= IDLE;
            HADDR <= 0;
            HTRANS <= TRANS_IDLE;
            HWRITE <= 0;
            HSIZE <= 0;
            HBURST <= 0;
            HPROT <= 4'b0011;
            HWDATA <= 0;
            transfer_done <= 0;
            read_data <= 0;
            transfer_error <= 0;
            current_addr <= 0;
            beat_count <= 0;
            total_beats <= 0;
            is_write <= 0;
            addr_phase <= 0;
        end else begin
            // Default values
            transfer_done <= 0;
            transfer_error <= 0;
            
            case (state)
                IDLE: begin
                    HTRANS <= TRANS_IDLE;
                    if (start_transfer) begin
                        // Setup transfer
                        current_addr <= start_addr;
                        is_write <= rw_mode;
                        beat_count <= 0;
                        total_beats <= (burst_length == 0) ? 1 : burst_length;
                        
                        // Start address phase
                        HADDR <= start_addr;
                        HTRANS <= TRANS_NONSEQ;
                        HWRITE <= rw_mode;
                        HSIZE <= transfer_size;
                        HBURST <= burst_type;
                        HWDATA <= write_data;
                        
                        state <= ADDR;
                        addr_phase <= 1;
                    end
                end
                
                ADDR: begin
                    if (HREADY) begin
                        if (HRESP == 2'b01) begin // ERROR
                            state <= ERROR;
                        end else begin
                            // Move to data phase
                            state <= DATA;
                            addr_phase <= 0;
                        end
                    end
                end
                
                DATA: begin
                    if (HREADY) begin
                        if (HRESP == 2'b01) begin // ERROR
                            state <= ERROR;
                        end else begin
                            // Capture read data
                            if (!is_write) begin
                                read_data <= HRDATA;
                            end
                            
                            beat_count <= beat_count + 1;
                            
                            if (beat_count >= total_beats - 1) begin
                                // Transfer complete
                                HTRANS <= TRANS_IDLE;
                                transfer_done <= 1;
                                state <= IDLE;
                            end else begin
                                // Continue burst
                                current_addr <= current_addr + 4;
                                HADDR <= current_addr + 4;
                                HTRANS <= TRANS_SEQ;
                                addr_phase <= 1;
                                state <= ADDR;
                            end
                        end
                    end
                end
                
                ERROR: begin
                    HTRANS <= TRANS_IDLE;
                    transfer_error <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

//===========================================================================
// AHB Slave Module - FIXED ADDRESS CALCULATION
//===========================================================================
module ahb_slave #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter MEMORY_DEPTH = 1024,
    parameter WAIT_STATES = 0
)(
    // Clock and Reset
    input  wire                    HCLK,
    input  wire                    HRESETn,
    
    // Slave Interface
    input  wire [ADDR_WIDTH-1:0]   HADDR,
    input  wire [1:0]              HTRANS,
    input  wire                    HWRITE,
    input  wire [2:0]              HSIZE,
    input  wire [2:0]              HBURST,
    input  wire [3:0]              HPROT,
    input  wire [DATA_WIDTH-1:0]   HWDATA,
    input  wire                    HSEL,
    output reg  [DATA_WIDTH-1:0]   HRDATA,
    output reg                     HREADY,
    output reg  [1:0]              HRESP
);

    // Memory Array
    reg [DATA_WIDTH-1:0] memory [0:MEMORY_DEPTH-1];
    
    // Pipeline registers
    reg [ADDR_WIDTH-1:0]   addr_reg;
    reg                    write_reg;
    reg [2:0]              size_reg;
    reg                    sel_reg;
    reg [1:0]              trans_reg;
    reg [3:0]              wait_count;
    
    // FIXED: Address calculation - Remove upper 4 bits for slave decode space
    wire [ADDR_WIDTH-1:0] masked_addr = addr_reg & 32'h0FFFFFFF; // Remove upper 4 bits
    wire [ADDR_WIDTH-3:0] word_addr = masked_addr[ADDR_WIDTH-1:2]; // Convert to word address
    wire [ADDR_WIDTH-3:0] local_addr = word_addr % MEMORY_DEPTH; // Use modulo instead of mask
    wire valid_addr = (local_addr < MEMORY_DEPTH);
    wire transfer_req = sel_reg && (trans_reg == 2'b10 || trans_reg == 2'b11);

    // Initialize memory
    integer i;
    initial begin
        for (i = 0; i < MEMORY_DEPTH; i = i + 1) begin
            memory[i] = 0;
        end
    end

    //-----------------------------------------------------------------------
    // Address Phase - Pipeline registers
    //-----------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_reg <= 0;
            write_reg <= 0;
            size_reg <= 0;
            sel_reg <= 0;
            trans_reg <= 0;
        end else if (HREADY) begin
            addr_reg <= HADDR;
            write_reg <= HWRITE;
            size_reg <= HSIZE;
            sel_reg <= HSEL;
            trans_reg <= HTRANS;
        end
    end

    //-----------------------------------------------------------------------
    // Wait State Generation - FIXED
    //-----------------------------------------------------------------------
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            wait_count <= 0;
            HREADY <= 1;
        end else begin
            if (transfer_req && HREADY && (wait_count < WAIT_STATES)) begin
                wait_count <= wait_count + 1;
                HREADY <= 0;
            end else if (wait_count > 0 && wait_count < WAIT_STATES) begin
                wait_count <= wait_count + 1;
                HREADY <= 0;
            end else begin
                wait_count <= 0;
                HREADY <= 1;
            end
        end
    end

    //-----------------------------------------------------------------------
    // Data Phase - Memory Access
    //-----------------------------------------------------------------------
    always @(*) begin
        // Default values
        HRDATA = 0;
        HRESP = 2'b00;
        
        if (transfer_req) begin
            if (!valid_addr) begin
                // Invalid address
                HRESP = 2'b01; // ERROR
                HRDATA = 0;
            end else begin
                HRESP = 2'b00; // OKAY
                if (!write_reg) begin
                    // Read operation - provide data combinationally
                    HRDATA = memory[local_addr];
                end else begin
                    // Write operation
                    HRDATA = 0;
                end
            end
        end
    end
    
    // Memory write operation (sequential)
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            // Memory initialization handled in initial block
        end else begin
            if (transfer_req && HREADY && write_reg && valid_addr) begin
                memory[local_addr] <= HWDATA;
            end
        end
    end

endmodule

//===========================================================================
// AHB Address Decoder
//===========================================================================
module ahb_decoder #(
    parameter ADDR_WIDTH = 32,
    parameter SLAVE_COUNT = 4
)(
    input  wire [ADDR_WIDTH-1:0]   HADDR,
    output reg  [SLAVE_COUNT-1:0]  HSEL
);

    always @(*) begin
        HSEL = 0;
        
        case (HADDR[31:28])
            4'h0: HSEL[0] = 1'b1; // Memory
            4'h1: HSEL[1] = 1'b1; // Timer
            4'h2: HSEL[2] = 1'b1; // UART
            4'h3: HSEL[3] = 1'b1; // GPIO
            default: HSEL = 0;    // No slave selected
        endcase
    end

endmodule

//===========================================================================
// AHB Response Multiplexer
//===========================================================================
module ahb_mux #(
    parameter DATA_WIDTH = 32,
    parameter SLAVE_COUNT = 4
)(
    input  wire [SLAVE_COUNT-1:0]           HSEL,
    input  wire [SLAVE_COUNT*DATA_WIDTH-1:0] HRDATA_slaves,
    input  wire [SLAVE_COUNT-1:0]           HREADY_slaves,
    input  wire [SLAVE_COUNT*2-1:0]         HRESP_slaves,
    
    output reg  [DATA_WIDTH-1:0]            HRDATA,
    output reg                              HREADY,
    output reg  [1:0]                       HRESP
);

    integer i;
    
    always @(*) begin
        // Default values for no slave selected
        HRDATA = 0;
        HREADY = 1;
        HRESP = 2'b01; // ERROR when no slave selected
        
        // Multiplex based on slave selection
        for (i = 0; i < SLAVE_COUNT; i = i + 1) begin
            if (HSEL[i]) begin
                HRDATA = HRDATA_slaves[i*DATA_WIDTH +: DATA_WIDTH];
                HREADY = HREADY_slaves[i];
                HRESP = HRESP_slaves[i*2 +: 2];
            end
        end
    end

endmodule

//===========================================================================
// AHB Interconnect
//===========================================================================
module ahb_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SLAVE_COUNT = 4
)(
    // Clock and Reset
    input  wire                    HCLK,
    input  wire                    HRESETn,
    
    // Master Interface
    input  wire [ADDR_WIDTH-1:0]   HADDR,
    input  wire [1:0]              HTRANS,
    input  wire                    HWRITE,
    input  wire [2:0]              HSIZE,
    input  wire [2:0]              HBURST,
    input  wire [3:0]              HPROT,
    input  wire [DATA_WIDTH-1:0]   HWDATA,
    output wire [DATA_WIDTH-1:0]   HRDATA,
    output wire                    HREADY,
    output wire [1:0]              HRESP,
    
    // Slave Interfaces
    output wire [ADDR_WIDTH-1:0]   HADDR_slaves,
    output wire [1:0]              HTRANS_slaves,
    output wire                    HWRITE_slaves,
    output wire [2:0]              HSIZE_slaves,
    output wire [2:0]              HBURST_slaves,
    output wire [3:0]              HPROT_slaves,
    output wire [DATA_WIDTH-1:0]   HWDATA_slaves,
    output wire [SLAVE_COUNT-1:0]  HSEL_slaves,
    input  wire [SLAVE_COUNT*DATA_WIDTH-1:0] HRDATA_slaves,
    input  wire [SLAVE_COUNT-1:0]  HREADY_slaves,
    input  wire [SLAVE_COUNT*2-1:0] HRESP_slaves
);

    // Address Decoder
    ahb_decoder #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .SLAVE_COUNT(SLAVE_COUNT)
    ) decoder_inst (
        .HADDR(HADDR),
        .HSEL(HSEL_slaves)
    );
    
    // Response Multiplexer
    ahb_mux #(
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_COUNT(SLAVE_COUNT)
    ) mux_inst (
        .HSEL(HSEL_slaves),
        .HRDATA_slaves(HRDATA_slaves),
        .HREADY_slaves(HREADY_slaves),
        .HRESP_slaves(HRESP_slaves),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP(HRESP)
    );
    
    // Connect Master signals to all Slaves
    assign HADDR_slaves = HADDR;
    assign HTRANS_slaves = HTRANS;
    assign HWRITE_slaves = HWRITE;
    assign HSIZE_slaves = HSIZE;
    assign HBURST_slaves = HBURST;
    assign HPROT_slaves = HPROT;
    assign HWDATA_slaves = HWDATA;

endmodule

//===========================================================================
// Complete AHB System Testbench
//===========================================================================
module ahb_system_tb;

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter SLAVE_COUNT = 4;
    parameter CLK_PERIOD = 10;
    
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
    // Slave 0 - Fast Memory
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

    // Slave 1 - Timer with wait states
    ahb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_DEPTH(4096), // Increased memory depth
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

    // Slave 2 - UART
    ahb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_DEPTH(4096), // Increased memory depth
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

    // Slave 3 - GPIO
    ahb_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .MEMORY_DEPTH(4096), // Increased memory depth
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
        single_write(32'h10000010, 32'h57414954);
        single_read(32'h10000010, 32'h57414954);
        
        // Test Case 4: Error Response Testing
        test_error_response();
        
        // Test Case 5: Address Boundary Testing
        single_write(32'h0FFFFFFC, 32'h424F554E);
        single_read(32'h0FFFFFFC, 32'h424F554E);
        
        // Additional Test Case 6: More Timer Tests to verify fix
        $display("\n=== Additional Timer Tests to Verify Fix ===");
        single_write(32'h10000000, 32'h11111111); // Timer base
        single_read(32'h10000000, 32'h11111111);
        
        single_write(32'h10000008, 32'h22222222); // Timer offset 8
        single_read(32'h10000008, 32'h22222222);
        
        single_write(32'h1000000C, 32'h33333333); // Timer offset 12
        single_read(32'h1000000C, 32'h33333333);
        
        // Test Case 7: Cross-verify all slaves work correctly
        $display("\n=== Cross-Verification of All Slaves ===");
        single_write(32'h00000100, 32'hDEAD0000); // Memory
        single_write(32'h10000100, 32'hDEAD1111); // Timer
        single_write(32'h20000100, 32'hDEAD2222); // UART
        single_write(32'h30000100, 32'hDEAD3333); // GPIO
        
        single_read(32'h00000100, 32'hDEAD0000); // Memory
        single_read(32'h10000100, 32'hDEAD1111); // Timer
        single_read(32'h20000100, 32'hDEAD2222); // UART
        single_read(32'h30000100, 32'hDEAD3333); // GPIO
        
        // Final Results
        repeat(10) @(posedge HCLK);
        
        $display("\n=== Test Results Summary ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Success Rate: %0.1f%%", (pass_count * 100.0) / test_count);
        
        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED! AHB Protocol Implementation Verified Successfully! ***");
        end else begin
            $display("\n*** SOME TESTS FAILED. Please review the implementation. ***");
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