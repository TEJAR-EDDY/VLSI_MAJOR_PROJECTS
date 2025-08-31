// =====================================================
// AHB to APB Bridge - FIXED Version
//  Author: Teja Reddy
// =====================================================
module ahb_apb_bridge(
    input  wire        HCLK,
    input  wire        HRESETn,
    input  wire [31:0] HADDR,
    input  wire [1:0]  HTRANS,
    input  wire        HWRITE,
    input  wire [2:0]  HSIZE,
    input  wire [31:0] HWDATA,
    output reg  [31:0] HRDATA,
    output reg         HREADY,
    output reg  [1:0]  HRESP,
    // APB interface
    output wire [31:0] PADDR,
    output wire [2:0]  PSEL,
    output wire        PENABLE,
    output wire        PWRITE,
    output wire [31:0] PWDATA,
    input  wire [31:0] PRDATA,
    input  wire        PREADY,
    input  wire        PSLVERR
);
    // FSM states
    parameter IDLE   = 2'b00;
    parameter SETUP  = 2'b01;
    parameter ACCESS = 2'b10;

    reg [1:0] state, next_state;
    reg [31:0] addr_reg;
    reg        write_reg;
    reg [31:0] wdata_reg;
    reg [2:0]  sel_reg;
    reg        read_valid;

    // Detect valid AHB transfer
    wire valid_ahb = HTRANS[1];

    // Address decoding
    always @(*) begin
        case (addr_reg[19:16])
            4'h0: sel_reg = 3'b001;
            4'h1: sel_reg = 3'b010;
            4'h2: sel_reg = 3'b100;
            default: sel_reg = 3'b000;
        endcase
    end

    // State register
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) state <= IDLE;
        else          state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:   if (valid_ahb) next_state = SETUP;
            SETUP:  next_state = ACCESS;
            ACCESS: if (PREADY) next_state = valid_ahb ? SETUP : IDLE;
        endcase
    end

    // Capture AHB signals
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_reg <= 32'h0;
            write_reg <= 1'b0;
            wdata_reg <= 32'h0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_ahb) begin
                        addr_reg <= HADDR;
                        write_reg <= HWRITE;
                    end
                end
                SETUP: if (write_reg) wdata_reg <= HWDATA;
                ACCESS: begin
                    if (PREADY && valid_ahb) begin
                        addr_reg <= HADDR;
                        write_reg <= HWRITE;
                        if (HWRITE) wdata_reg <= HWDATA;
                    end
                end
            endcase
        end
    end

    // APB outputs
    assign PADDR   = addr_reg;
    assign PWRITE  = write_reg;
    assign PWDATA  = wdata_reg;
    assign PSEL    = (state == SETUP || state == ACCESS) ? sel_reg : 3'b000;
    assign PENABLE = (state == ACCESS);

    // AHB response
    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            HREADY <= 1'b1;
            HRESP  <= 2'b00;
            HRDATA <= 32'h0;
            read_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    HREADY <= ~valid_ahb;
                    HRESP  <= 2'b00;
                end
                SETUP: begin
                    HREADY <= 1'b0;
                    HRESP  <= 2'b00;
                end
                ACCESS: begin
                    if (PREADY) begin
                        HRESP <= PSLVERR ? 2'b01 : 2'b00;
                        HREADY <= 1'b1;

                        if (!write_reg) begin
                            HRDATA <= PRDATA; // latch read data
                            read_valid <= 1'b1;
                        end else begin
                            read_valid <= 1'b0;
                        end
                    end else begin
                        HREADY <= 1'b0;
                        HRESP  <= 2'b00;
                    end
                end
            endcase
        end
    end
endmodule

// =====================================================
// Dummy APB slaves with simple memory
// =====================================================
module apb_slave0(
    input  wire       PCLK,
    input  wire       PRESETn,
    input  wire [31:0] PADDR,
    input  wire       PSEL,
    input  wire       PENABLE,
    input  wire       PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire       PREADY,
    output wire       PSLVERR
);
    reg [31:0] memory [0:255];
    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) PRDATA <= 32'h0;
        else if (PSEL && PENABLE) begin
            if (PWRITE) begin
                memory[PADDR[7:2]] <= PWDATA;
                $display("[%0t] SLAVE0 WRITE Addr=0x%h Data=0x%h -> mem[%0d]", $time, PADDR, PWDATA, PADDR[7:2]);
            end else begin
                PRDATA <= memory[PADDR[7:2]];
                $display("[%0t] SLAVE0 READ  Addr=0x%h Data=0x%h <- mem[%0d]", $time, PADDR, PRDATA, PADDR[7:2]);
            end
        end
    end
endmodule

module apb_slave1(
    input  wire       PCLK,
    input  wire       PRESETn,
    input  wire [31:0] PADDR,
    input  wire       PSEL,
    input  wire       PENABLE,
    input  wire       PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire       PREADY,
    output wire       PSLVERR
);
    reg [31:0] memory [0:255];
    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) PRDATA <= 32'h0;
        else if (PSEL && PENABLE) begin
            if (PWRITE) begin
                memory[PADDR[7:2]] <= PWDATA;
                $display("[%0t] SLAVE1 WRITE Addr=0x%h Data=0x%h -> mem[%0d]", $time, PADDR, PWDATA, PADDR[7:2]);
            end else begin
                PRDATA <= memory[PADDR[7:2]] != 0 ? memory[PADDR[7:2]] : PADDR;
                $display("[%0t] SLAVE1 READ  Addr=0x%h Data=0x%h <- mem[%0d]", $time, PADDR, PRDATA, PADDR[7:2]);
            end
        end
    end
endmodule

module apb_slave2(
    input  wire       PCLK,
    input  wire       PRESETn,
    input  wire [31:0] PADDR,
    input  wire       PSEL,
    input  wire       PENABLE,
    input  wire       PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire       PREADY,
    output wire       PSLVERR
);
    reg [31:0] memory [0:255];
    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) PRDATA <= 32'h0;
        else if (PSEL && PENABLE) begin
            if (PWRITE) begin
                memory[PADDR[7:2]] <= PWDATA;
                $display("[%0t] SLAVE2 WRITE Addr=0x%h Data=0x%h -> mem[%0d]", $time, PADDR, PWDATA, PADDR[7:2]);
            end else begin
                PRDATA <= memory[PADDR[7:2]] != 0 ? memory[PADDR[7:2]] : PADDR;
                $display("[%0t] SLAVE2 READ  Addr=0x%h Data=0x%h <- mem[%0d]", $time, PADDR, PRDATA, PADDR[7:2]);
            end
        end
    end
endmodule

// =====================================================
// Testbench
// =====================================================
module tb_ahb_apb_bridge;
    reg HCLK;
    reg HRESETn;
    reg  [31:0] HADDR;
    reg  [1:0]  HTRANS;
    reg         HWRITE;
    reg  [2:0]  HSIZE;
    reg  [31:0] HWDATA;
    wire [31:0] HRDATA;
    wire        HREADY;
    wire [1:0]  HRESP;

    wire [31:0] PADDR;
    wire [2:0]  PSEL;
    wire        PENABLE;
    wire        PWRITE;
    wire [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    wire [31:0] PRDATA0, PRDATA1, PRDATA2;
    wire        PREADY0, PREADY1, PREADY2;
    wire        PSLVERR0, PSLVERR1, PSLVERR2;

    integer test_count = 0;
    integer pass_count = 0;

    // Clock
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;
    end

    // DUT
    ahb_apb_bridge dut (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE),
        .HSIZE(HSIZE), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .PADDR(PADDR), .PSEL(PSEL), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PWDATA(PWDATA),
        .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR)
    );

    // Slaves
    apb_slave0 slave0(.PCLK(HCLK), .PRESETn(HRESETn), .PADDR(PADDR), .PSEL(PSEL[0]), .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA), .PRDATA(PRDATA0), .PREADY(PREADY0), .PSLVERR(PSLVERR0));
    apb_slave1 slave1(.PCLK(HCLK), .PRESETn(HRESETn), .PADDR(PADDR), .PSEL(PSEL[1]), .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA), .PRDATA(PRDATA1), .PREADY(PREADY1), .PSLVERR(PSLVERR1));
    apb_slave2 slave2(.PCLK(HCLK), .PRESETn(HRESETn), .PADDR(PADDR), .PSEL(PSEL[2]), .PENABLE(PENABLE), .PWRITE(PWRITE), .PWDATA(PWDATA), .PRDATA(PRDATA2), .PREADY(PREADY2), .PSLVERR(PSLVERR2));

    // Response mux (fixed: use registered PSEL)
    reg [2:0] psel_reg;
    always @(posedge HCLK) psel_reg <= PSEL;
    assign PRDATA  = psel_reg[0] ? PRDATA0 : (psel_reg[1] ? PRDATA1 : (psel_reg[2] ? PRDATA2 : 32'h0));
    assign PREADY  = psel_reg[0] ? PREADY0 : (psel_reg[1] ? PREADY1 : (psel_reg[2] ? PREADY2 : 1'b1));
    assign PSLVERR = psel_reg[0] ? PSLVERR0 : (psel_reg[1] ? PSLVERR1 : (psel_reg[2] ? PSLVERR2 : 1'b0));

    // Reset
    initial begin
        HRESETn = 0;
        HADDR = 0; HTRANS = 0; HWRITE = 0; HSIZE = 3'b010; HWDATA = 0;
        #100 HRESETn = 1;
        $display("==================================================");
        $display("     AHB → APB Bridge Test Started");
        $display("==================================================");
    end

    // Tasks
    task ahb_write(input [31:0] addr, input [31:0] data);
    begin
        $display("Starting AHB Write: Addr=0x%h, Data=0x%h", addr, data);
        @(posedge HCLK); while (!HREADY) @(posedge HCLK);
        HADDR <= addr; HTRANS <= 2'b10; HWRITE <= 1;
        @(posedge HCLK); HWDATA <= data;
        @(posedge HCLK); while (!HREADY) @(posedge HCLK);
        HADDR <= 0; HTRANS <= 2'b00; HWRITE <= 0;
        $display("AHB Write completed");
    end
    endtask

    task ahb_read(input [31:0] addr, output [31:0] data);
    begin
        $display("Starting AHB Read: Addr=0x%h", addr);
        @(posedge HCLK); while (!HREADY) @(posedge HCLK);
        HADDR <= addr; HTRANS <= 2'b10; HWRITE <= 0;
        @(posedge HCLK);
        @(posedge HCLK); while (!HREADY) @(posedge HCLK);
        data = HRDATA;
        HADDR <= 0; HTRANS <= 2'b00;
        $display("AHB Read completed: Data=0x%h", data);
    end
    endtask

    // Test sequence
    reg [31:0] rdata;
    initial begin
        wait(HRESETn); repeat(10) @(posedge HCLK);

        // T1: Write Slave0
        test_count++; ahb_write(32'h00000004, 32'hDEADBEEF);
        if (slave0.memory[1] === 32'hDEADBEEF) begin $display("PASS T1"); pass_count++; end else $display("FAIL T1");

        // T2: Read Slave0
        test_count++; slave0.memory[2] = 32'hCAFEBABE;
        ahb_read(32'h00000008, rdata);
        if (rdata === 32'hCAFEBABE) begin $display("PASS T2"); pass_count++; end else $display("FAIL T2");

        // T3: Write Slave1
        test_count++; ahb_write(32'h00010000, 32'h12345678);
        if (slave1.memory[0] === 32'h12345678) begin $display("PASS T3"); pass_count++; end else $display("FAIL T3");

        // T4: Write Slave2
        test_count++; ahb_write(32'h00020000, 32'h87654321);
        if (slave2.memory[0] === 32'h87654321) begin $display("PASS T4"); pass_count++; end else $display("FAIL T4");

        // T5: Back-to-back writes
        test_count++; ahb_write(32'h00000010, 32'hAAAA5555); ahb_write(32'h00000014, 32'h5555AAAA);
        if (slave0.memory[4] === 32'hAAAA5555 && slave0.memory[5] === 32'h5555AAAA) begin $display("PASS T5"); pass_count++; end else $display("FAIL T5");

        // T6: Read verification
        test_count++; ahb_read(32'h00000004, rdata);
        if (rdata === 32'hDEADBEEF) begin $display("PASS T6"); pass_count++; end else $display("FAIL T6");

        // T7: Read Slave1
        test_count++; ahb_read(32'h00010000, rdata);
        if (rdata === 32'h12345678) begin $display("PASS T7"); pass_count++; end else $display("FAIL T7");

        // T8: Read Slave2
        test_count++; ahb_read(32'h00020000, rdata);
        if (rdata === 32'h87654321) begin $display("PASS T8"); pass_count++; end else $display("FAIL T8");

        // Results
        $display("\n==================================================");
        $display("                TEST RESULTS");
        $display("==================================================");
        $display("Total: %0d  Passed: %0d  Failed: %0d", test_count, pass_count, test_count-pass_count);
        $display("Success Rate: %0d%%", (pass_count * 100)/ test_count);
        if (pass_count == test_count) $display("🎉 *** ALL TESTS PASSED *** 🎉");
        else $display("❌ *** %0d TEST(S) FAILED ***", test_count-pass_count);
        #50 $finish;
    end

    initial begin
        $dumpfile("ahb_apb_bridge.vcd");
        $dumpvars(0, tb_ahb_apb_bridge);
    end
endmodule
