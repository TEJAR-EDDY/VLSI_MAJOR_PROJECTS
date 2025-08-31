//=============================================================================
// Top Module - Connects 1 Master and 3 Slaves
// This module demonstrates a complete I2C system
// Author: Teja Reddy
//=============================================================================
module i2c_top (
    input wire clk,
    input wire reset,
    
    // Master control interface
    input wire start_transaction,
    input wire rw_bit,
    input wire [6:0] slave_addr,
    input wire [7:0] master_write_data,
    
    // Master status interface
    output wire [7:0] master_read_data,
    output wire transaction_done,
    output wire ack_received,
    
    // Slave data interfaces (for testbench to control/monitor)
    input wire [7:0] slave0_write_data,
    input wire [7:0] slave1_write_data,
    input wire [7:0] slave2_write_data,
    output wire [7:0] slave0_read_data,
    output wire [7:0] slave1_read_data,
    output wire [7:0] slave2_read_data,
    output wire slave0_data_valid,
    output wire slave1_data_valid,
    output wire slave2_data_valid
);

    // I2C bus wires (open-drain)
    wire sda, scl;
    
    // Slave addresses - each slave has a unique 7-bit address
    localparam [6:0] SLAVE0_ADDR = 7'h10;  // Address 0x10
    localparam [6:0] SLAVE1_ADDR = 7'h20;  // Address 0x20
    localparam [6:0] SLAVE2_ADDR = 7'h30;  // Address 0x30

    // Instantiate I2C Master
    i2c_master master_inst (
        .clk(clk),
        .reset(reset),
        .start_transaction(start_transaction),
        .rw_bit(rw_bit),
        .slave_addr(slave_addr),
        .write_data(master_write_data),
        .read_data(master_read_data),
        .transaction_done(transaction_done),
        .ack_received(ack_received),
        .sda(sda),
        .scl(scl)
    );

    // Instantiate I2C Slave 0
    i2c_slave slave0_inst (
        .clk(clk),
        .reset(reset),
        .slave_address(SLAVE0_ADDR),
        .slave_write_data(slave0_write_data),
        .slave_read_data(slave0_read_data),
        .data_valid(slave0_data_valid),
        .sda(sda),
        .scl(scl)
    );

    // Instantiate I2C Slave 1
    i2c_slave slave1_inst (
        .clk(clk),
        .reset(reset),
        .slave_address(SLAVE1_ADDR),
        .slave_write_data(slave1_write_data),
        .slave_read_data(slave1_read_data),
        .data_valid(slave1_data_valid),
        .sda(sda),
        .scl(scl)
    );

    // Instantiate I2C Slave 2
    i2c_slave slave2_inst (
        .clk(clk),
        .reset(reset),
        .slave_address(SLAVE2_ADDR),
        .slave_write_data(slave2_write_data),
        .slave_read_data(slave2_read_data),
        .data_valid(slave2_data_valid),
        .sda(sda),
        .scl(scl)
    );

    // Pull-up resistors for I2C bus (weak pull-up)
    // In real hardware, external pull-up resistors would be used
    // Here we model them as weak pulls in the testbench
    
endmodule