//=========================================================================== 
// AHB Arbiter - Round Robin Arbitration for Multiple Masters 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_arbiter #( 
    parameter MASTER_COUNT = 2 
)( 
    // Clock and Reset 
    input  wire                       HCLK, 
    input  wire                       HRESETn, 
     
    // Bus Request/Grant 
    input  wire [MASTER_COUNT-1:0]    HBUSREQ, 
    output reg  [MASTER_COUNT-1:0]    HGRANT, 
     
    // Master selection 
    output reg  [$clog2(MASTER_COUNT)-1:0] HMASTER 
); 
 
    // FSM States   
    localparam GRANT_M0 = 2'b00, 
               GRANT_M1 = 2'b01; 
     
    reg [1:0] current_state, next_state; 
     
    //----------------------------------------------------------------------- 
    // FSM Sequential Logic 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            current_state <= GRANT_M0; 
        end else begin 
            current_state <= next_state; 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // FSM Combinational Logic - Round Robin 
    //----------------------------------------------------------------------- 
    always @(*) begin 
        // Default values 
        next_state = current_state; 
        HGRANT = {MASTER_COUNT{1'b0}}; 
        HMASTER = 0; 
         
        case (current_state) 
            GRANT_M0: begin 
                if (HBUSREQ[0]) begin 
                    HGRANT[0] = 1'b1; 
                    HMASTER = 0; 
                    if (HBUSREQ[1]) begin 
 
 
                        next_state = GRANT_M1; 
                    end 
                end else if (HBUSREQ[1]) begin 
                    next_state = GRANT_M1; 
                end 
            end 
             
            GRANT_M1: begin 
                if (HBUSREQ[1]) begin 
                    HGRANT[1] = 1'b1; 
                    HMASTER = 1; 
                    if (HBUSREQ[0]) begin 
                        next_state = GRANT_M0; 
                    end 
                end else if (HBUSREQ[0]) begin 
                    next_state = GRANT_M0; 
                end 
            end 
             
            default: next_state = GRANT_M0; 
        endcase 
    end 
 
endmodule
