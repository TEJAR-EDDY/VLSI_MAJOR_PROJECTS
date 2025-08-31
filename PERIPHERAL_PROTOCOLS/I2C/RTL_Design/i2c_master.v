//=============================================================================
// I2C Master Module
// Implements I2C master functionality with FSM for beginners
// Author: Teja Reddy
//=============================================================================
module i2c_master (
    input wire clk,
    input wire reset,
    
    // Control interface
    input wire start_transaction,      // Start I2C transaction
    input wire rw_bit,                // 0=write, 1=read
    input wire [6:0] slave_addr,      // 7-bit slave address
    input wire [7:0] write_data,      // Data to write to slave
    
    // Status outputs
    output reg [7:0] read_data,       // Data read from slave
    output reg transaction_done,      // Transaction complete flag
    output reg ack_received,          // ACK received from slave
    
    // I2C bus (open-drain)
    inout wire sda,
    inout wire scl
);

    // Internal signals for open-drain implementation
    reg sda_out;
    reg scl_out;
    reg sda_enable;  // 0 = release line (high-Z), 1 = drive low
    reg scl_enable;  // 0 = release line (high-Z), 1 = drive low
    
    // Open-drain implementation: only drive low, never drive high
    assign sda = sda_enable ? 1'b0 : 1'bz;
    assign scl = scl_enable ? 1'b0 : 1'bz;

    // FSM states - easy to understand for beginners
    localparam [3:0] IDLE       = 4'h0,
                     START      = 4'h1,  // Generate START condition
                     ADDR_SEND  = 4'h2,  // Send 7-bit address + R/W bit
                     ADDR_ACK   = 4'h3,  // Wait for address ACK
                     DATA_WRITE = 4'h4,  // Send data byte (write mode)
                     DATA_ACK   = 4'h5,  // Wait for data ACK (write mode)
                     DATA_READ  = 4'h6,  // Read data byte (read mode)
                     MASTER_ACK = 4'h7,  // Send NACK after read (master doesn't want more data)
                     STOP       = 4'h8;  // Generate STOP condition

    reg [3:0] state, next_state;
    reg [3:0] bit_count;        // Count bits being sent/received (0-7)
    reg [7:0] shift_reg;        // Shift register for data transmission
    reg [7:0] addr_byte;        // Address byte (7-bit addr + R/W bit)
    reg [7:0] clock_div;        // Simple clock divider for I2C timing
    reg i2c_clk;                // Divided clock for I2C operations
    
    // Simple clock divider - creates slower I2C clock from main clock
    // This makes timing easier to understand and debug
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clock_div <= 8'h00;
            i2c_clk <= 1'b0;
        end else begin
            clock_div <= clock_div + 1;
            if (clock_div == 8'h00)  // Divide by 256 for slow I2C clock
                i2c_clk <= ~i2c_clk;
        end
    end

    // FSM state register
    always @(posedge i2c_clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next state logic - describes what happens in each state
    always @(*) begin
        next_state = state;  // Default: stay in current state
        
        case (state)
            IDLE: begin
                if (start_transaction)
                    next_state = START;
            end
            
            START: begin
                next_state = ADDR_SEND;  // After START, always send address
            end
            
            ADDR_SEND: begin
                if (bit_count == 4'd7)   // Sent all 8 bits (7 addr + 1 R/W)
                    next_state = ADDR_ACK;
            end
            
            ADDR_ACK: begin
                if (rw_bit == 1'b0)      // Write operation
                    next_state = DATA_WRITE;
                else                     // Read operation
                    next_state = DATA_READ;
            end
            
            DATA_WRITE: begin
                if (bit_count == 4'd7)   // Sent all 8 data bits
                    next_state = DATA_ACK;
            end
            
            DATA_ACK: begin
                next_state = STOP;       // After data ACK, always stop
            end
            
            DATA_READ: begin
                if (bit_count == 4'd7)   // Received all 8 data bits
                    next_state = MASTER_ACK;
            end
            
            MASTER_ACK: begin
                next_state = STOP;       // After master ACK, always stop
            end
            
            STOP: begin
                next_state = IDLE;       // Return to idle after STOP
            end
            
            default: next_state = IDLE;
        endcase
    end

    // FSM output logic - controls I2C bus and internal registers
    always @(posedge i2c_clk or posedge reset) begin
        if (reset) begin
            sda_enable <= 1'b0;
            scl_enable <= 1'b0;
            bit_count <= 4'h0;
            shift_reg <= 8'h00;
            addr_byte <= 8'h00;
            read_data <= 8'h00;
            transaction_done <= 1'b0;
            ack_received <= 1'b0;
        end else begin
            // Default values
            transaction_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    sda_enable <= 1'b0;    // Release SDA (high)
                    scl_enable <= 1'b0;    // Release SCL (high)
                    bit_count <= 4'h0;
                    ack_received <= 1'b0;
                    if (start_transaction) begin
                        // Prepare address byte: 7-bit address + R/W bit
                        addr_byte <= {slave_addr, rw_bit};
                        shift_reg <= write_data;
                    end
                end
                
                START: begin
                    // START condition: SDA goes low while SCL is high
                    sda_enable <= 1'b1;    // Pull SDA low
                    scl_enable <= 1'b0;    // Keep SCL high initially
                    bit_count <= 4'h0;     // Reset bit counter
                    shift_reg <= addr_byte; // Load address for transmission
                end
                
                ADDR_SEND: begin
                    scl_enable <= 1'b1;    // Pull SCL low for data setup
                    // Send MSB first (I2C protocol)
                    sda_enable <= ~shift_reg[7]; // 0 = pull low, 1 = release high
                    shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left
                    bit_count <= bit_count + 1;
                end
                
                ADDR_ACK: begin
                    sda_enable <= 1'b0;    // Release SDA to read ACK
                    scl_enable <= 1'b1;    // Clock pulse for ACK
                    ack_received <= ~sda;   // ACK = 0, NACK = 1
                    if (rw_bit == 1'b1) begin // Read mode
                        bit_count <= 4'h0;  // Reset for data reading
                    end else begin           // Write mode
                        shift_reg <= write_data; // Load write data
                        bit_count <= 4'h0;  // Reset for data writing
                    end
                end
                
                DATA_WRITE: begin
                    scl_enable <= 1'b1;    // Pull SCL low for data setup
                    sda_enable <= ~shift_reg[7]; // Send MSB first
                    shift_reg <= {shift_reg[6:0], 1'b0}; // Shift left
                    bit_count <= bit_count + 1;
                end
                
                DATA_ACK: begin
                    sda_enable <= 1'b0;    // Release SDA to read ACK
                    scl_enable <= 1'b1;    // Clock pulse for ACK
                    // Note: In real application, check ACK here
                end
                
                DATA_READ: begin
                    sda_enable <= 1'b0;    // Release SDA to read data
                    scl_enable <= 1'b1;    // Clock pulse to read bit
                    // Read data bit and shift into register
                    read_data <= {read_data[6:0], sda};
                    bit_count <= bit_count + 1;
                end
                
                MASTER_ACK: begin
                    sda_enable <= 1'b1;    // Send NACK (pull SDA low = ACK, high = NACK)
                    scl_enable <= 1'b1;    // Clock pulse for NACK
                    // Master sends NACK to indicate no more data needed
                end
                
                STOP: begin
                    // STOP condition: SDA goes high while SCL is high
                    scl_enable <= 1'b0;    // Release SCL (high)
                    sda_enable <= 1'b0;    // Release SDA (high)
                    transaction_done <= 1'b1; // Signal completion
                end
            endcase
        end
    end

endmodule