//  Author: Teja Reddy
// Top-level APB system connecting master, decoder, and slaves 
 
module apb_system_top #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter NUM_SLAVES = 3 
)( 
    // System signals 
    input  wire                    pclk, 
    input  wire                    presetn, 
     
    // Control interface (from external controller/AHB bridge) 
    input  wire                    transfer_req, 
    input  wire [ADDR_WIDTH-1:0]   transfer_addr, 
 
 
    input  wire [DATA_WIDTH-1:0]   transfer_wdata, 
    input  wire                    transfer_write, 
    output wire                    transfer_ready, 
    output wire [DATA_WIDTH-1:0]   transfer_rdata, 
    output wire                    transfer_error 
); 
 
    // Internal APB signals 
    wire [ADDR_WIDTH-1:0]   paddr; 
    wire [DATA_WIDTH-1:0]   pwdata; 
    wire [DATA_WIDTH-1:0]   prdata; 
    wire                    pwrite; 
    wire                    psel_master; 
    wire                    penable; 
    wire                    pready; 
    wire                    pslverr; 
    wire [2:0]              pprot; 
    wire [3:0]              pstrb; 
     
    // Decoder signals 
    wire [NUM_SLAVES-1:0]   psel_slaves; 
    wire                    decode_error; 
     
    // Individual slave signals 
    wire [DATA_WIDTH-1:0]   prdata_slaves [NUM_SLAVES-1:0]; 
    wire [NUM_SLAVES-1:0]   pready_slaves; 
    wire [NUM_SLAVES-1:0]   pslverr_slaves; 
 
    // APB Master instance 
    apb_master #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .DATA_WIDTH(DATA_WIDTH) 
    ) u_apb_master ( 
        .pclk           (pclk), 
        .presetn        (presetn), 
        .transfer_req   (transfer_req), 
        .transfer_addr  (transfer_addr), 
        .transfer_wdata (transfer_wdata), 
        .transfer_write (transfer_write), 
        .transfer_ready (transfer_ready), 
        .transfer_rdata (transfer_rdata), 
        .transfer_error (transfer_error), 
        .paddr          (paddr), 
        .pwdata         (pwdata), 
        .prdata         (prdata), 
        .pwrite         (pwrite), 
        .psel           (psel_master), 
        .penable        (penable), 
        .pready         (pready), 
        .pslverr        (pslverr), 
        .pprot          (pprot), 
        .pstrb          (pstrb) 
    ); 
     
    // APB Decoder instance 
    apb_decoder #( 
        .ADDR_WIDTH(ADDR_WIDTH), 
        .NUM_SLAVES(NUM_SLAVES) 
    ) u_apb_decoder ( 
        .paddr        (paddr), 
        .psel_master  (psel_master), 
        .psel_slaves  (psel_slaves), 
        .decode_error (decode_error) 
    ); 
     
    // Generate slaves 
    genvar i; 
    generate 
        for (i = 0; i < NUM_SLAVES; i++) begin : gen_slaves 
            apb_slave #( 
                .ADDR_WIDTH(ADDR_WIDTH), 
                .DATA_WIDTH(DATA_WIDTH), 
                .SLAVE_ID(i), 
                .WAIT_CYCLES(i) // Different wait cycles per slave 
            ) u_apb_slave ( 
                .pclk    (pclk), 
                .presetn (presetn), 
                .paddr   (paddr), 
                .pwdata  (pwdata), 
                .prdata  (prdata_slaves[i]), 
                .pwrite  (pwrite), 
                .psel    (psel_slaves[i]), 
                .penable (penable), 
                .pready  (pready_slaves[i]), 
                .pslverr (pslverr_slaves[i]), 
                .pprot   (pprot), 
                .pstrb   (pstrb) 
            ); 
        end 
    endgenerate 
     
    // Output multiplexing 
    always_comb begin 
        prdata = '0; 
        pready = 1'b0; 
        pslverr = decode_error; // Set error if decode fails 
         
        for (int j = 0; j < NUM_SLAVES; j++) begin 
            if (psel_slaves[j]) begin 
                prdata = prdata_slaves[j]; 
 
 
                pready = pready_slaves[j]; 
                pslverr = pslverr_slaves[j] | decode_error; 
            end 
        end 
    end 
 
endmodule 
