//=============================================================================
// I2C Slave Module
// Implements I2C slave functionality with FSM for beginners
// Author: Teja Reddy
//=============================================================================
module i2c_slave (
    input wire clk,
    input wire reset,
    
    // Configuration
    input wire [6:0] slave_address,   // This slave's 7-bit address
    
    // Data interface
    input wire [7:0] slave_write_data, // Data slave will send when read
    output reg [7:0] slave_read_data,  // Data slave received from master
    output reg data_valid,             // Flag: new data received
    
    // I2C bus (open-drain)
    inout wire sda,
    inout wire scl
);

    // Internal signals for open-drain implementation
    reg sda_enable;  // 0 = release line (high-Z), 1 = drive low
    
    // Open-drain implementation: only drive low, never drive high
    assign sda = sda_enable ? 1'b0 : 1'bz;
    // Note: Slave doesn't drive SCL, only master does

    // FSM states - easy to understand for beginners
    localparam [3:0] IDLE         = 4'h0,
                     START_DET    = 4'h1,  // START condition detected
                     ADDR_RX      = 4'h2,  // Receiving address + R/W bit
                     ADDR_ACK     = 4'h3,  // Send ACK for correct address
                     DATA_RX      = 4'h4,  // Receiving data (write mode)
                     DATA_ACK     = 4'h5,  // Send ACK for received data
                     DATA_TX      = 4'h6,  // Transmitting data (read mode)
                     DATA_WAIT    = 4'h7,  // Wait for master ACK/NACK
                     STOP_DET     = 4'h8;  // STOP condition detected

    reg [3:0] state, next_state;
    reg [3:0] bit_count;        // Count bits being sent/received (0-7)
    reg [7:0] shift_reg;        // Shift register for data
    reg [7:0] addr_reg;         // Received address + R/W bit
    reg rw_bit;                 // Extracted R/W bit
    reg address_match;          // Flag: received address matches ours
    
    // Edge detection for START and STOP conditions
    reg sda_prev, scl_prev;
    reg start_detected, stop_detected;
    
    // Capture previous values and detect START/STOP conditions
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sda_prev <= 1'b1;
            scl_prev <= 1'b1;
            start_detected <= 1'b0;
            stop_detected <= 1'b0;
        end else begin
            sda_prev <= sda;
            scl_prev <= scl;
            
            // START condition: SDA falls while SCL is high
            start_detected <= (scl_prev && scl && sda_prev && !sda);
            
            // STOP condition: SDA rises while SCL is high
            stop_detected <= (scl_prev && scl && !sda_prev && sda);
        end
    end

    // FSM state register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next state logic
    always @(*) begin
        next_state = state;  // Default: stay in current state
        
        case (state)
            IDLE: begin
                if (start_detected)
                    next_state = START_DET;
            end
            
            START_DET: begin
                next_state = ADDR_RX;    // Always receive address after START
            end
            
            ADDR_RX: begin
                if (bit_count == 4'd7)   // Received all 8 bits
                    next_state = ADDR_ACK;
            end
            
            ADDR_ACK: begin
                if (address_match && rw_bit == 1'b0) // Write to this slave
                    next_state = DATA_RX;
                else if (address_match && rw_bit == 1'b1) // Read from this slave
                    next_state = DATA_TX;
                else                     // Address doesn't match
                    next_state = IDLE;   // Ignore transaction
            end
            
            DATA_RX: begin
                if (bit_count == 4'd7)   // Received all 8 data bits
                    next_state = DATA_ACK;
            end
            
            DATA_ACK: begin
                if (stop_detected)
                    next_state = STOP_DET;
                else
                    next_state = IDLE;   // Wait for next transaction
            end
            
            DATA_TX: begin
                if (bit_count == 4'd7)   // Sent all 8 data bits
                    next_state = DATA_WAIT;
            end
            
            DATA_WAIT: begin
                if (stop_detected)
                    next_state = STOP_DET;
                else
                    next_state = IDLE;   // Master sent NACK
            end
            
            STOP_DET: begin
                next_state = IDLE;       // Return to idle after STOP
            end
            
            default: next_state = IDLE;
        endcase
    end

    // FSM output logic - controls SDA and internal registers
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sda_enable <= 1'b0;
            bit_count <= 4'h0;
            shift_reg <= 8'h00;
            addr_reg <= 8'h00;
            rw_bit <= 1'b0;
            address_match <= 1'b0;
            slave_read_data <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            // Default values
            data_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    sda_enable <= 1'b0;    // Release SDA
                    bit_count <= 4'h0;
                    address_match <= 1'b0;
                end
                
                START_DET: begin
                    bit_count <= 4'h0;     // Reset bit counter
                    shift_reg <= 8'h00;    // Clear shift register
                end
                
                ADDR_RX: begin
                    // Wait for falling edge of SCL to read data
                    if (scl_prev && !scl) begin
                        // Read address bit and shift into register
                        shift_reg <= {shift_reg[6:0], sda};
                        bit_count <= bit_count + 1;
                        
                        if (bit_count == 4'd7) begin // Last bit received
                            addr_reg <= {shift_reg[6:0], sda};
                            rw_bit <= sda;  // LSB is R/W bit
                            // Check if address matches (excluding R/W bit)
                            address_match <= ({shift_reg[6:0], sda}[7:1] == slave_address);
                        end
                    end
                end
                
                ADDR_ACK: begin
                    // Send ACK (pull SDA low) if address matches
                    if (scl_prev && !scl) begin // Setup ACK on falling SCL
                        if (address_match)
                            sda_enable <= 1'b1;    // ACK (pull low)
                        else
                            sda_enable <= 1'b0;    // NACK (release high)
                    end
                    
                    if (address_match) begin
                        bit_count <= 4'h0;     // Reset for data phase
                        if (rw_bit == 1'b1)    // Read mode - prepare data
                            shift_reg <= slave_write_data;
                    end
                end
                
                DATA_RX: begin
                    sda_enable <= 1'b0;        // Release SDA to read
                    
                    // Wait for falling edge of SCL to read data
                    if (scl_prev && !scl) begin
                        shift_reg <= {shift_reg[6:0], sda};
                        bit_count <= bit_count + 1;
                        
                        if (bit_count == 4'd7) begin // Last bit received
                            slave_read_data <= {shift_reg[6:0], sda};
                            data_valid <= 1'b1;  // Signal new data received
                        end
                    end
                end
                
                DATA_ACK: begin
                    // Send ACK for received data
                    if (scl_prev && !scl)       // Setup ACK on falling SCL
                        sda_enable <= 1'b1;    // ACK (pull low)
                end
                
                DATA_TX: begin
                    // Send data bit on falling edge of SCL
                    if (scl_prev && !scl) begin
                        sda_enable <= ~shift_reg[7]; // Send MSB first
                        shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left
                        bit_count <= bit_count + 1;
                    end
                end
                
                DATA_WAIT: begin
                    sda_enable <= 1'b0;        // Release SDA for master ACK
                    // Master will send ACK/NACK here
                end
                
                STOP_DET: begin
                    sda_enable <= 1'b0;        // Release SDA
                end
            endcase
        end
    end

endmodule