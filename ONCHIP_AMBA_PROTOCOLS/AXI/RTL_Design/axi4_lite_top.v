// Axi4_lite top design using verilog HDL
// Author: Teja Reddy
module axi4_lite_system_top #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter STRB_WIDTH = DATA_WIDTH/8 
)( 
    input wire clk, 
    input wire reset_n, 
     
    // User Interface for Testing 
    input wire                    write_req, 
    input wire [ADDR_WIDTH-1:0]   write_addr, 
    input wire [DATA_WIDTH-1:0]   write_data, 
    input wire [STRB_WIDTH-1:0]   write_strb, 
    output wire                   write_done, 
    output wire [1:0]             write_resp, 
     
    input wire                    read_req, 
    input wire [ADDR_WIDTH-1:0]   read_addr, 
    output wire [DATA_WIDTH-1:0]  read_data, 
    output wire                   read_done, 
    output wire [1:0]             read_resp 
); 
 
    // AXI4-Lite Interconnect Signals 
    wire [ADDR_WIDTH-1:0] axi_awaddr; 
    wire                  axi_awvalid; 
    wire                  axi_awready; 
    wire [DATA_WIDTH-1:0] axi_wdata; 
    wire [STRB_WIDTH-1:0] axi_wstrb; 
    wire                  axi_wvalid; 
    wire                  axi_wready; 
    wire [1:0]            axi_bresp; 
    wire                  axi_bvalid; 
    wire                  axi_bready; 
    wire [ADDR_WIDTH-1:0] axi_araddr; 
    wire                  axi_arvalid; 
    wire                  axi_arready; 
    wire [DATA_WIDTH-1:0] axi_rdata; 
    wire [1:0]            axi_rresp; 
    wire                  axi_rvalid; 
 
 
    wire                  axi_rready; 
     
    // AXI4-Lite Master Instance 
    axi4_lite_master #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .STRB_WIDTH(STRB_WIDTH) 
    ) master_inst ( 
        .clk(clk), 
        .reset_n(reset_n), 
         
        // User Interface 
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
        .read_resp(read_resp), 
         
        // AXI4-Lite Interface 
        .M_AXI_AWADDR(axi_awaddr), 
        .M_AXI_AWVALID(axi_awvalid), 
        .M_AXI_AWREADY(axi_awready), 
        .M_AXI_WDATA(axi_wdata), 
        .M_AXI_WSTRB(axi_wstrb), 
        .M_AXI_WVALID(axi_wvalid), 
        .M_AXI_WREADY(axi_wready), 
        .M_AXI_BRESP(axi_bresp), 
        .M_AXI_BVALID(axi_bvalid), 
        .M_AXI_BREADY(axi_bready), 
        .M_AXI_ARADDR(axi_araddr), 
        .M_AXI_ARVALID(axi_arvalid), 
        .M_AXI_ARREADY(axi_arready), 
        .M_AXI_RDATA(axi_rdata), 
        .M_AXI_RRESP(axi_rresp), 
        .M_AXI_RVALID(axi_rvalid), 
        .M_AXI_RREADY(axi_rready) 
    ); 
     
    // AXI4-Lite Slave Instance 
    axi4_lite_slave #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH), 
        .STRB_WIDTH(STRB_WIDTH), 
 
 
        .MEM_SIZE(1024) 
    ) slave_inst ( 
        .clk(clk), 
        .reset_n(reset_n), 
         
        // AXI4-Lite Interface 
        .S_AXI_AWADDR(axi_awaddr), 
        .S_AXI_AWVALID(axi_awvalid), 
        .S_AXI_AWREADY(axi_awready), 
        .S_AXI_WDATA(axi_wdata), 
        .S_AXI_WSTRB(axi_wstrb), 
        .S_AXI_WVALID(axi_wvalid), 
        .S_AXI_WREADY(axi_wready), 
        .S_AXI_BRESP(axi_bresp), 
        .S_AXI_BVALID(axi_bvalid), 
        .S_AXI_BREADY(axi_bready), 
        .S_AXI_ARADDR(axi_araddr), 
        .S_AXI_ARVALID(axi_arvalid), 
        .S_AXI_ARREADY(axi_arready), 
        .S_AXI_RDATA(axi_rdata), 
        .S_AXI_RRESP(axi_rresp), 
        .S_AXI_RVALID(axi_rvalid), 
        .S_AXI_RREADY(axi_rready) 
    ); 
endmodule
