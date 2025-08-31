//=====================================================
// SPI Slave (Verilog-2001)
// - Echo slave: drives back its tx_data
// - Tri-states MISO when CS_n=1
// - Correct CPOL/CPHA handling
// - Author: Teja Reddy
//=====================================================
module spi_slave #(
    parameter DATA_WIDTH = 8
)(
    input  wire                  sclk,
    input  wire                  cs_n,
    input  wire                  mosi,
    output wire                  miso,      // tri-stated when not selected
    input  wire [DATA_WIDTH-1:0] tx_data,
    output reg  [DATA_WIDTH-1:0] rx_data,
    input  wire                  CPOL,
    input  wire                  CPHA
);

    reg [DATA_WIDTH-1:0] sh_tx;
    reg [DATA_WIDTH-1:0] sh_rx;
    reg [3:0]            sample_cnt;
    reg                  miso_drv;

    assign miso = cs_n ? 1'bz : miso_drv;

    // Load/prepare on select
    always @(negedge cs_n or posedge cs_n) begin
        if (cs_n) begin
            // deselect
            sh_tx      <= {DATA_WIDTH{1'b0}};
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
            miso_drv   <= 1'b0;
        end else begin
            // select
            sh_tx      <= tx_data;
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
            // For CPHA=0, the first output bit must be present before first leading edge
            if (CPHA == 1'b0) begin
                miso_drv <= tx_data[DATA_WIDTH-1];
            end
        end
    end

    // At SCLK positive edge
    always @(posedge sclk) begin
        if (!cs_n) begin
            // Which kind of edge is this?
            if (CPOL == 1'b0) begin
                // posedge is LEADING
                if (CPHA == 1'b0) begin
                    // sample on leading
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end else begin
                    // CPHA=1: drive on leading
                    miso_drv <= sh_tx[DATA_WIDTH-1];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end
            end else begin
                // CPOL=1: posedge is TRAILING
                if (CPHA == 1'b0) begin
                    // CPHA=0: drive on trailing
                    miso_drv <= sh_tx[DATA_WIDTH-2];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end else begin
                    // CPHA=1: sample on trailing
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end
            end
        end
    end

    // At SCLK negative edge
    always @(negedge sclk) begin
        if (!cs_n) begin
            if (CPOL == 1'b0) begin
                // negedge is TRAILING
                if (CPHA == 1'b0) begin
                    // CPHA=0: drive on trailing
                    miso_drv <= sh_tx[DATA_WIDTH-2];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end else begin
                    // CPHA=1: sample on trailing
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end
            end else begin
                // CPOL=1: negedge is LEADING
                if (CPHA == 1'b0) begin
                    // CPHA=0: sample on leading
                    sh_rx      <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    sample_cnt <= sample_cnt + 1'b1;
                    if (sample_cnt == (DATA_WIDTH-1)) begin
                        rx_data <= {sh_rx[DATA_WIDTH-2:0], mosi};
                    end
                end else begin
                    // CPHA=1: drive on leading
                    miso_drv <= sh_tx[DATA_WIDTH-1];
                    sh_tx    <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                end
            end
        end
    end

endmodule
