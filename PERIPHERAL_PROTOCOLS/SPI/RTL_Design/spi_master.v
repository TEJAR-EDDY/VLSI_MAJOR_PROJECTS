//=====================================================
// SPI Master (Verilog-2001)
// - Parameterized DATA_WIDTH
// - 3-slave ready (slave_sel is 2 bits)
// - Runs all 4 modes via CPOL/CPHA inputs
// - Author: Teja Reddy
//=====================================================
module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLOCK_DIV  = 4   // must be even and >=2
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // control
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] tx_data,
    input  wire [1:0]            slave_sel,
    input  wire                  CPOL,
    input  wire                  CPHA,

    // status/data
    output reg  [DATA_WIDTH-1:0] rx_data,
    output reg                   done,

    // SPI bus
    output reg                   sclk,
    output reg                   mosi,
    input  wire                  miso,
    output reg  [2:0]            cs_n
);

    // prescaler
    reg [15:0] div_cnt;
    wire tick = (div_cnt == (CLOCK_DIV-1));
    reg active;

    // shifting
    reg [DATA_WIDTH-1:0] sh_tx;
    reg [DATA_WIDTH-1:0] sh_rx;
    reg [3:0]            sample_cnt; // up to 16 bits

    // prescale & SCLK toggle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= 0;
            sclk    <= 1'b0;
        end else if (active) begin
            if (div_cnt == (CLOCK_DIV-1)) begin
                div_cnt <= 0;
                sclk    <= ~sclk;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt <= 0;
            sclk    <= CPOL; // idle level
        end
    end

    // main control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active     <= 1'b0;
            done       <= 1'b0;
            cs_n       <= 3'b111;
            mosi       <= 1'b0;
            rx_data    <= {DATA_WIDTH{1'b0}};
            sh_tx      <= {DATA_WIDTH{1'b0}};
            sh_rx      <= {DATA_WIDTH{1'b0}};
            sample_cnt <= 4'd0;
        end else begin
            done <= 1'b0;

            // start of a new transaction
            if (start && !active) begin
                active     <= 1'b1;
                cs_n       <= 3'b111;
                cs_n[slave_sel] <= 1'b0;  // select slave
                sh_tx      <= tx_data;
                sh_rx      <= {DATA_WIDTH{1'b0}};
                sample_cnt <= 4'd0;
                mosi       <= (CPHA == 1'b0) ? tx_data[DATA_WIDTH-1] : mosi; // preload for CPHA=0
            end

            if (active && tick) begin
                // Decide which edge we are about to produce:
                // before toggle, if sclk == CPOL, next edge is leading; else trailing
                // (since we flip sclk after this block)
                if (sclk == CPOL) begin
                    // LEADING edge next
                    if (CPHA == 1'b0) begin
                        // CPHA=0: sample on leading
                        sh_rx      <= {sh_rx[DATA_WIDTH-2:0], miso};
                        sample_cnt <= sample_cnt + 1'b1;

                        if (sample_cnt == (DATA_WIDTH-1)) begin
                            // last sample completes the frame
                            rx_data <= {sh_rx[DATA_WIDTH-2:0], miso};
                            active  <= 1'b0;
                            cs_n    <= 3'b111;
                            done    <= 1'b1;
                        end
                    end else begin
                        // CPHA=1: drive on leading
                        mosi  <= sh_tx[DATA_WIDTH-1];
                        sh_tx <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                    end
                end else begin
                    // TRAILING edge next
                    if (CPHA == 1'b0) begin
                        // CPHA=0: drive on trailing
                        mosi  <= sh_tx[DATA_WIDTH-2]; // next bit after shift below
                        sh_tx <= {sh_tx[DATA_WIDTH-2:0], 1'b0};
                    end else begin
                        // CPHA=1: sample on trailing
                        sh_rx      <= {sh_rx[DATA_WIDTH-2:0], miso};
                        sample_cnt <= sample_cnt + 1'b1;

                        if (sample_cnt == (DATA_WIDTH-1)) begin
                            rx_data <= {sh_rx[DATA_WIDTH-2:0], miso};
                            active  <= 1'b0;
                            cs_n    <= 3'b111;
                            done    <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
