//=====================================================
// SPI Top (Verilog-2001)
// - 3 slaves
// - Slaves echo master's TX byte (wired)
// - Author: Teja Reddy
//=====================================================
module spi_top #(
    parameter DATA_WIDTH = 8,
    parameter CLOCK_DIV  = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [1:0]            slave_sel,
    input  wire                  CPOL,
    input  wire                  CPHA,
    output wire [DATA_WIDTH-1:0] rx_data,
    output wire                  done
);

    wire sclk, mosi;
    wire [2:0] cs_n;
    wire [2:0] miso_w;
    wire miso;

    // Only active slave drives MISO; else high-Z
    assign miso = (cs_n[0] == 1'b0) ? miso_w[0] :
                  (cs_n[1] == 1'b0) ? miso_w[1] :
                  (cs_n[2] == 1'b0) ? miso_w[2] : 1'bz;

    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_DIV (CLOCK_DIV)
    ) u_spi_master (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .tx_data  (tx_data),
        .slave_sel(slave_sel),
        .CPOL     (CPOL),
        .CPHA     (CPHA),
        .rx_data  (rx_data),
        .done     (done),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso),
        .cs_n     (cs_n)
    );

    // All slaves get same tx_data (echo design)
    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s0 (
        .sclk(sclk), .cs_n(cs_n[0]), .mosi(mosi),
        .miso(miso_w[0]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s1 (
        .sclk(sclk), .cs_n(cs_n[1]), .mosi(mosi),
        .miso(miso_w[1]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

    spi_slave #(.DATA_WIDTH(DATA_WIDTH)) u_s2 (
        .sclk(sclk), .cs_n(cs_n[2]), .mosi(mosi),
        .miso(miso_w[2]), .tx_data(tx_data), .rx_data(), .CPOL(CPOL), .CPHA(CPHA)
    );

endmodule
