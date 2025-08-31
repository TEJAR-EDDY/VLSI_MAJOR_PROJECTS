//  Author: Teja Reddy
// Generic APB Slave with configurable memory 
 
 
 
module apb_slave #( 
    parameter ADDR_WIDTH = 32, 
    parameter DATA_WIDTH = 32, 
    parameter SLAVE_ID = 0, 
    parameter WAIT_CYCLES = 0 
)( 
    // System signals 
    input  wire                    pclk, 
    input  wire                    presetn, 
     
    // APB Slave interface 
    input  wire [ADDR_WIDTH-1:0]   paddr, 
    input  wire [DATA_WIDTH-1:0]   pwdata, 
    output reg  [DATA_WIDTH-1:0]   prdata, 
    input  wire                    pwrite, 
    input  wire                    psel, 
    input  wire                    penable, 
    output reg                     pready, 
    output reg                     pslverr, 
    input  wire [2:0]              pprot, 
    input  wire [3:0]              pstrb 
); 
 
    // Internal memory (simple register file) 
    reg [DATA_WIDTH-1:0] memory [0:255]; 
     
    // Wait state counter 
    reg [$clog2(WAIT_CYCLES+1)-1:0] wait_count; 
     
    // FSM States 
    typedef enum logic [1:0] { 
        IDLE   = 2'b00, 
        ACCESS = 2'b01, 
        ERROR  = 2'b10 
    } slave_state_t; 
     
    slave_state_t current_state, next_state; 
     
    // Address decode (use lower 8 bits for memory addressing) 
    wire [7:0] mem_addr = paddr[9:2]; // Word-aligned addressing 
    wire valid_address = (paddr[31:10] == 22'h0); // Valid if upper bits are 0 
     
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
                if (psel && !penable) 
                    next_state = ACCESS; 
                else 
                    next_state = IDLE; 
            end 
             
            ACCESS: begin 
                if (!valid_address) 
                    next_state = ERROR; 
                else if (wait_count == WAIT_CYCLES) 
                    next_state = IDLE; 
                else 
                    next_state = ACCESS; 
            end 
             
            ERROR: begin 
                next_state = IDLE; 
            end 
             
            default: next_state = IDLE; 
        endcase 
    end 
     
    // Wait counter 
    always_ff @(posedge pclk or negedge presetn) begin 
        if (!presetn) begin 
            wait_count <= '0; 
        end else begin 
            if (current_state == ACCESS && next_state == ACCESS) 
                wait_count <= wait_count + 1; 
            else 
                wait_count <= '0; 
        end 
    end 
     
    // Memory operations and output generation 
    always_ff @(posedge pclk or negedge presetn) begin 
        if (!presetn) begin 
            prdata  <= '0; 
            pready  <= 1'b0; 
            pslverr <= 1'b0; 
             
            // Initialize memory with slave-specific pattern 
            for (int i = 0; i < 256; i++) begin 
                memory[i] <= {SLAVE_ID[7:0], 24'h000000} + i; 
            end 
 
 
        end else begin 
            case (current_state) 
                IDLE: begin 
                    pready  <= 1'b0; 
                    pslverr <= 1'b0; 
                    prdata  <= '0; 
                end 
                 
                ACCESS: begin 
                    if (valid_address && wait_count == WAIT_CYCLES) begin 
                        pready <= 1'b1; 
                        pslverr <= 1'b0; 
                         
                        if (pwrite) begin 
                            // Write operation 
                            if (pstrb[0]) memory[mem_addr][ 7: 0] <= pwdata[ 7: 0]; 
                            if (pstrb[1]) memory[mem_addr][15: 8] <= pwdata[15: 8]; 
                            if (pstrb[2]) memory[mem_addr][23:16] <= pwdata[23:16]; 
                            if (pstrb[3]) memory[mem_addr][31:24] <= pwdata[31:24]; 
                        end else begin 
                            // Read operation 
                            prdata <= memory[mem_addr]; 
                        end 
                    end else if (!valid_address) begin 
                        pready  <= 1'b0; 
                        pslverr <= 1'b0; 
                    end else begin 
                        pready  <= 1'b0; 
                        pslverr <= 1'b0; 
                    end 
                end 
                 
                ERROR: begin 
                    pready  <= 1'b1; 
                    pslverr <= 1'b1; 
                    prdata  <= 32'hDEADBEEF; // Error pattern 
                end 
            endcase 
        end 
    end 
 
endmodule

