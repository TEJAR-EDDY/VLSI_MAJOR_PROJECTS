//=========================================================================== 
// AHB Interconnect - Connects Master to Multiple Slaves 
//  Author: Teja Reddy
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
 
    //----------------------------------------------------------------------- 
    // Address Decoder Instance 
    //----------------------------------------------------------------------- 
    ahb_decoder #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .SLAVE_COUNT(SLAVE_COUNT) 
    ) decoder_inst ( 
        .HADDR(HADDR), 
        .HSEL(HSEL_slaves) 
    ); 
     
    //----------------------------------------------------------------------- 
    // Response Multiplexer Instance 
    //----------------------------------------------------------------------- 
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
     
    //----------------------------------------------------------------------- 
    // Connect Master signals to all Slaves 
    //----------------------------------------------------------------------- 
    assign HADDR_slaves = HADDR; 
    assign HTRANS_slaves = HTRANS; 
    assign HWRITE_slaves = HWRITE; 
    assign HSIZE_slaves = HSIZE; 
    assign HBURST_slaves = HBURST; 
    assign HPROT_slaves = HPROT; 
    assign HWDATA_slaves = HWDATA; 
 
endmodule 
