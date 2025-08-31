
// APB Master with FSM-based control 
//  Author: Teja Reddy

module apb_master #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32 
)( 
    // System signals 
    input  wire                    pclk, 
    input  wire                    presetn, 
     
    // Control interface (from AHB bridge) 
    input  wire                    transfer_req, 
    input  wire [ADDR_WIDTH-1:0]   transfer_addr, 
    input  wire [DATA_WIDTH-1:0]   transfer_wdata, 
    input  wire                    transfer_write, 
    output reg                     transfer_ready, 
    output reg  [DATA_WIDTH-1:0]   transfer_rdata, 
    output reg                     transfer_error, 
     
    // APB Master interface 
    output reg  [ADDR_WIDTH-1:0]   paddr, 
    output reg  [DATA_WIDTH-1:0]   pwdata, 
    input  wire [DATA_WIDTH-1:0]   prdata, 
    output reg                     pwrite, 
    output reg                     psel, 
    output reg                     penable, 
    input  wire                    pready, 
    input  wire                    pslverr, 
    output reg  [2:0]              pprot, 
    output reg  [3:0]              pstrb 
 
 
); 
 
    // FSM States 
    typedef enum logic [1:0] { 
        IDLE   = 2'b00, 
        SETUP  = 2'b01, 
        ACCESS = 2'b10 
    } apb_state_t; 
     
    apb_state_t current_state, next_state; 
     
    // FSM Sequential Logic 
    always_ff @(posedge pclk or negedge presetn) begin 
        if (!presetn) 
            current_state <= IDLE; 
        else 
            current_state <= next_state; 
    end 
     
    // FSM Combinational Logic 
    always_comb begin 
        case (current_state) 
            IDLE: begin 
                if (transfer_req) 
                    next_state = SETUP; 
                else 
                    next_state = IDLE; 
            end 
             
            SETUP: begin 
                next_state = ACCESS; 
            end 
             
            ACCESS: begin 
                if (pready) 
                    next_state = IDLE; 
                else 
                    next_state = ACCESS; 
            end 
             
            default: next_state = IDLE; 
        endcase 
    end 
     
    // APB Signal Generation 
    always_ff @(posedge pclk or negedge presetn) begin 
        if (!presetn) begin 
            paddr         <= '0; 
            pwdata        <= '0; 
            pwrite        <= 1'b0; 
 
 
            psel          <= 1'b0; 
            penable       <= 1'b0; 
            pprot         <= 3'b000; 
            pstrb         <= 4'b0000; 
            transfer_ready <= 1'b1; 
            transfer_rdata <= '0; 
            transfer_error <= 1'b0; 
        end else begin 
            case (current_state) 
                IDLE: begin 
                    psel          <= 1'b0; 
                    penable       <= 1'b0; 
                    transfer_ready <= 1'b1; 
                     
                    if (transfer_req) begin 
                        paddr         <= transfer_addr; 
                        pwdata        <= transfer_wdata; 
                        pwrite        <= transfer_write; 
                        pprot         <= 3'b000; // Normal access 
                        pstrb         <= 4'b1111; // All bytes enabled 
                        transfer_ready <= 1'b0; 
                    end 
                end 
                 
                SETUP: begin 
                    psel    <= 1'b1; 
                    penable <= 1'b0; 
                end 
                 
                ACCESS: begin 
                    psel    <= 1'b1; 
                    penable <= 1'b1; 
                     
                    if (pready) begin 
                        if (!pwrite) begin 
                            transfer_rdata <= prdata; 
                        end 
                        transfer_error <= pslverr; 
                    end 
                end 
            endcase 
        end 
    end 
 
endmodule 
 // Task: Display final results
    task display_results;
        real success_rate;
    begin
        $display("\n=== Test Results Summary ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        success_rate = (pass_count * 100.0) / test_count;
        $display("Success Rate: %0.1f%%", success_rate);
        
        if (fail_count == 0) begin
            $display("🎉 ALL TESTS PASSED!");
        end else begin
            $display("❌ Some tests failed. Check logs above.");
        end
    end
    endtask
    
    // Waveform dumping
    initial begin
        $dumpfile("apb_system.vcd");
        $dumpvars(0, apb_system_tb);
    end

endmodule