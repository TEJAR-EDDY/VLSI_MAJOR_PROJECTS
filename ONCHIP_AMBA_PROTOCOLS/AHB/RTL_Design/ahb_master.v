//=========================================================================== 
// AHB Master Module 
// Supports single and burst transfers with configurable parameters 
//  Author: Teja Reddy
//=========================================================================== 
module ahb_master #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32,
    parameter CLK_PERIOD = 10  // Add CLK_PERIOD parameter
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
    input  wire [2:0]              transfer_size,   // Same encoding as HSIZE 
    input  wire [2:0]              burst_type,     // Same encoding as HBURST 
    input  wire [7:0]              burst_length,   // Number of transfers 
    output reg                     transfer_done, 
    output reg  [DATA_WIDTH-1:0]   read_data, 
    output reg                     transfer_error 
); 

    // FSM States 
    localparam [2:0] IDLE       = 3'b000, 
                     NONSEQ     = 3'b001, 
                     SEQ        = 3'b010, 
                     WAIT       = 3'b011, 
                     ERROR      = 3'b100; 
     
    // Transfer Types 
    localparam [1:0] TRANS_IDLE   = 2'b00, 
                     TRANS_BUSY   = 2'b01, 
                     TRANS_NONSEQ = 2'b10, 
                     TRANS_SEQ    = 2'b11; 
     
    // Internal Registers 
    reg [2:0]              current_state, next_state; 
    reg [ADDR_WIDTH-1:0]   current_addr; 
    reg [DATA_WIDTH-1:0]   current_wdata; 
    reg [7:0]              beat_count; 
    reg [7:0]              total_beats; 
    reg                    is_write; 
    reg [2:0]              current_size; 
    reg [2:0]              current_burst; 
    reg                    transfer_active; 
     
    // Address increment calculation 
    wire [ADDR_WIDTH-1:0] addr_increment = (1 << transfer_size); 
    wire [ADDR_WIDTH-1:0] wrap_boundary; 
     
    // Calculate wrap boundary for wrapping bursts 
    assign wrap_boundary = start_addr & ~((burst_length * addr_increment) - 1); 
     
    //----------------------------------------------------------------------- 
    // State Machine - Current State Register 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            current_state <= IDLE; 
        end else begin 
            current_state <= next_state; 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // State Machine - Next State Logic 
    //----------------------------------------------------------------------- 
    always @(*) begin 
        next_state = current_state; 
         
        case (current_state) 
            IDLE: begin 
                if (start_transfer) 
                    next_state = NONSEQ; 
            end 
             
            NONSEQ: begin 
                if (HREADY) begin 
                    if (HRESP == 2'b01) begin // ERROR response 
                        next_state = ERROR; 
                    end else if (beat_count >= total_beats - 1) begin 
                        next_state = IDLE; 
                    end else begin 
                        next_state = SEQ; 
                    end 
                end else begin 
                    next_state = WAIT; 
                end 
            end 
             
            SEQ: begin 
                if (HREADY) begin 
                    if (HRESP == 2'b01) begin // ERROR response 
                        next_state = ERROR; 
                    end else if (beat_count >= total_beats - 1) begin 
                        next_state = IDLE; 
                    end else begin 
                        next_state = SEQ; 
                    end 
                end else begin 
                    next_state = WAIT; 
                end 
            end 
             
            WAIT: begin 
                if (HREADY) begin 
                    if (HRESP == 2'b01) begin // ERROR response 
                        next_state = ERROR; 
                    end else if (beat_count >= total_beats - 1) begin 
                        next_state = IDLE; 
                    end else begin 
                        next_state = SEQ; 
                    end 
                end 
            end 
             
            ERROR: begin 
                next_state = IDLE; 
            end 
             
            default: begin 
                next_state = IDLE; 
            end 
        endcase 
    end 
     
    //----------------------------------------------------------------------- 
    // Control Signal Generation 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK or negedge HRESETn) begin 
        if (!HRESETn) begin 
            // Reset all outputs 
            HADDR <= {ADDR_WIDTH{1'b0}}; 
            HTRANS <= TRANS_IDLE; 
            HWRITE <= 1'b0; 
            HSIZE <= 3'b000; 
            HBURST <= 3'b000; 
            HPROT <= 4'b0011; // Data, Privileged, Non-cacheable, Non-bufferable 
            HWDATA <= {DATA_WIDTH{1'b0}}; 
            transfer_done <= 1'b0; 
            read_data <= {DATA_WIDTH{1'b0}}; 
            transfer_error <= 1'b0; 
            transfer_active <= 1'b0; 
             
            // Reset internal registers 
            current_addr <= {ADDR_WIDTH{1'b0}}; 
            current_wdata <= {DATA_WIDTH{1'b0}}; 
            beat_count <= 8'h00; 
            total_beats <= 8'h00; 
            is_write <= 1'b0; 
            current_size <= 3'b000; 
            current_burst <= 3'b000; 
        end else begin 
            // Default assignments 
            transfer_done <= 1'b0; 
            transfer_error <= 1'b0; 
             
            case (current_state) 
                IDLE: begin 
                    HTRANS <= TRANS_IDLE; 
                    if (start_transfer) begin 
                        // Latch transfer parameters 
                        current_addr <= start_addr; 
                        current_wdata <= write_data; 
                        is_write <= rw_mode; 
                        current_size <= transfer_size; 
                        current_burst <= burst_type; 
                        total_beats <= (burst_length == 0) ? 8'h01 : burst_length; 
                        beat_count <= 8'h00; 
                        transfer_active <= 1'b1; 
                         
                        // Set up first transfer 
                        HADDR <= start_addr; 
                        HWRITE <= rw_mode; 
                        HSIZE <= transfer_size; 
                        HBURST <= burst_type; 
                        HTRANS <= TRANS_NONSEQ; 
                        HWDATA <= write_data; 
                    end else begin 
                        transfer_active <= 1'b0; 
                    end 
                end 
                 
                NONSEQ: begin 
                    if (HREADY && HRESP == 2'b00) begin // OKAY response 
                        // Capture read data 
                        if (!is_write) begin 
                            read_data <= HRDATA; 
                        end 
                         
                        // Check if transfer complete 
                        if (beat_count >= total_beats - 1) begin 
                            HTRANS <= TRANS_IDLE; 
                            transfer_done <= 1'b1; 
                            transfer_active <= 1'b0; 
                        end else begin 
                            // Set up next transfer 
                            beat_count <= beat_count + 1; 
                            current_addr <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HADDR <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HTRANS <= TRANS_SEQ; 
                            HWDATA <= write_data; // For simplicity, using same data 
                        end 
                    end 
                end 
                 
                SEQ: begin 
                    if (HREADY && HRESP == 2'b00) begin // OKAY response 
                        // Capture read data 
                        if (!is_write) begin 
                            read_data <= HRDATA; 
                        end 
                         
                        // Check if transfer complete 
                        if (beat_count >= total_beats - 1) begin 
                            HTRANS <= TRANS_IDLE; 
                            transfer_done <= 1'b1; 
                            transfer_active <= 1'b0; 
                        end else begin 
                            // Set up next transfer 
                            beat_count <= beat_count + 1; 
                            current_addr <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HADDR <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HWDATA <= write_data; // For simplicity, using same data 
                        end 
                    end 
                end 
                 
                WAIT: begin 
                    // Keep current values, wait for HREADY 
                    if (HREADY && HRESP == 2'b00) begin // OKAY response 
                        // Capture read data 
                        if (!is_write) begin 
                            read_data <= HRDATA; 
                        end 
                         
                        // Check if transfer complete 
                        if (beat_count >= total_beats - 1) begin 
                            HTRANS <= TRANS_IDLE; 
                            transfer_done <= 1'b1; 
                            transfer_active <= 1'b0; 
                        end else begin 
                            // Set up next transfer 
                            beat_count <= beat_count + 1; 
                            current_addr <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HADDR <= calculate_next_address(current_addr, current_burst, current_size, beat_count + 1, start_addr, total_beats); 
                            HTRANS <= TRANS_SEQ; 
                            HWDATA <= write_data; // For simplicity, using same data 
                        end 
                    end 
                end 
                 
                ERROR: begin 
                    HTRANS <= TRANS_IDLE; 
                    transfer_error <= 1'b1; 
                    transfer_active <= 1'b0; 
                end 
            endcase 
        end 
    end 
     
    //----------------------------------------------------------------------- 
    // Address Calculation Function 
    //----------------------------------------------------------------------- 
    function [ADDR_WIDTH-1:0] calculate_next_address; 
        input [ADDR_WIDTH-1:0] current; 
        input [2:0] burst; 
        input [2:0] size; 
        input [7:0] beat; 
        input [ADDR_WIDTH-1:0] base; 
        input [7:0] length; 
        reg [ADDR_WIDTH-1:0] increment; 
        reg [ADDR_WIDTH-1:0] wrap_mask; 
        begin 
            increment = 1 << size; 
             
            case (burst) 
                3'b000, 3'b001: begin // SINGLE, INCR 
                    calculate_next_address = current + increment; 
                end 
                3'b010: begin // WRAP4 
                    wrap_mask = (4 * increment) - 1; 
                    calculate_next_address = (base & ~wrap_mask) | ((current + increment) & wrap_mask); 
                end 
                3'b011: begin // INCR4 
                    calculate_next_address = current + increment; 
                end 
                3'b100: begin // WRAP8 
                    wrap_mask = (8 * increment) - 1; 
                    calculate_next_address = (base & ~wrap_mask) | ((current + increment) & wrap_mask); 
                end 
                3'b101: begin // INCR8 
                    calculate_next_address = current + increment; 
                end 
                3'b110: begin // WRAP16 
                    wrap_mask = (16 * increment) - 1; 
                    calculate_next_address = (base & ~wrap_mask) | ((current + increment) & wrap_mask); 
                end 
                3'b111: begin // INCR16 
                    calculate_next_address = current + increment; 
                end 
                default: begin 
                    calculate_next_address = current + increment; 
                end 
            endcase 
        end 
    endfunction 
     
    //----------------------------------------------------------------------- 
    // Transaction Monitor for Debugging 
    //----------------------------------------------------------------------- 
    always @(posedge HCLK) begin 
        if (HTRANS != 2'b00 && HREADY) begin 
            $display("Time=%0t: ADDR=0x%08h, TRANS=%0d, WRITE=%0b, SIZE=%0d, BURST=%0d",  
                     $time, HADDR, HTRANS, HWRITE, HSIZE, HBURST); 
            if (HWRITE && HTRANS != 2'b00) begin 
                $display("         WDATA=0x%08h", HWDATA); 
            end 
            if (!HWRITE && HREADY) begin 
                $display("         RDATA=0x%08h, RESP=%0d", HRDATA, HRESP); 
            end 
        end 
    end 
     
    // Timeout watchdog 
    initial begin 
        #(CLK_PERIOD * 10000); 
        if (transfer_active) begin 
            $display("ERROR: Transfer timeout!"); 
            $finish; 
        end 
    end 
     
endmodule