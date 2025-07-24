`timescale 1ns / 1ps

module adc_manager_tb #(
    parameter unsigned NUM_SDI = 4,
    // clock frequencies in MHz
    parameter real ACLK_FREQ = 125.0,
    parameter real SPI_CLK_FREQ = 50.0,
    parameter real CNV_FREQ = 2.0
);
    localparam integer AclkPeriodHalf = $rtoi(1_000.0 / (2.0 * ACLK_FREQ));
    localparam integer SpiClkPeriodHalf = $rtoi(1_000.0 / (2.0 * SPI_CLK_FREQ));
    localparam integer CnvPeriod = $rtoi(1_000.0 / CNV_FREQ);

    logic aclk = 1'b0;
    logic aresetn = 1'b0;
    logic spi_clk = 1'b0;
    logic spi_resetn = 1'b0;
    logic cnv_clk = 1'b0;
    logic cnv_clk_en = 1'b0;

    always #(AclkPeriodHalf) aclk <= ~aclk;
    always #(SpiClkPeriodHalf) spi_clk <= ~spi_clk;
    always #(CnvPeriod) cnv_clk <= cnv_clk_en;

    always_ff @(posedge aclk) begin
        cnv_clk <= 1'b0;
    end

    wire spi_clk_out;
    wire [NUM_SDI-1:0] spi_miso;
    wire spi_mosi;
    wire spi_resetn_out;
    wire spi_csn;

    wire cnv;
    wire busy;
    wire ready;
    logic trigger_acq = 0;

    // AXI Stream sender
    logic [31:0] m_axis_tdata = 32'b0;
    wire m_axis_tready;
    logic m_axis_tvalid = 1'b0;

    // AXI Stream receiver
    wire [31:0] s_axis_tdata;
    logic s_axis_tready = 1'b0;
    wire s_axis_tvalid;

    logic [31:0] axis_data_received = 32'b0;
    logic [23:0] reg_cmd_received = 24'b0;

    logic [31:0] test_pattern = 32'h8BADF00D;

    adc_spi_manager #(
        .NUM_SDI (NUM_SDI),
        .SETUP_CS(1'b0)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),

        .spi_clk(spi_clk),
        .spi_resetn(spi_resetn),

        .spi_sdi(spi_miso),
        .spi_sdo(spi_mosi),
        .spi_csn(spi_csn),
        .spi_resetn_out(spi_resetn_out),
        .spi_clk_out(spi_clk_out),

        .trigger_acq(trigger_acq),

        .s_axis_tdata (m_axis_tdata),
        .s_axis_tvalid(m_axis_tvalid),
        .s_axis_tready(m_axis_tready),

        .m_axis_tdata (s_axis_tdata),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tready(s_axis_tready),

        .ready(ready)
    );

    adc_model adc (
        .cnv(cnv),
        .busy(busy),
        .sck(spi_clk_out),
        .csn(spi_csn),
        .resetn(spi_resetn_out),
        .sdi(spi_mosi),
        .sdo(spi_miso),
        .test_pattern(test_pattern),
        .reg_cmd(reg_cmd_received)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
        end else begin
            if (s_axis_tready && s_axis_tvalid) begin
                axis_data_received <= s_axis_tdata;
                s_axis_tready <= 1'b0;
            end
            if (m_axis_tready && m_axis_tvalid) begin
                m_axis_tvalid <= 1'b0;
            end
        end
    end

    assign cnv = cnv_clk;

    logic is_adc_busy = 1'b0;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            is_adc_busy <= 1'b0;
            trigger_acq <= 1'b0;
        end else begin
            trigger_acq <= 1'b0;
            if (busy) begin
                is_adc_busy <= 1'b1;
            end else if (is_adc_busy) begin
                is_adc_busy <= 1'b0;
                trigger_acq <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("build/traces/adc_manager_tb.vcd");
        $dumpvars();

        m_axis_tdata = {8'b0, 3'b101, 21'b0};
        aresetn = 1'b0;
        spi_resetn = 1'b0;
        #(5 * SpiClkPeriodHalf);
        aresetn = 1'b1;
        spi_resetn = 1'b1;
        #(5 * SpiClkPeriodHalf);
        @(posedge aclk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tdata = {8'b0, 1'b0, 15'h0020, 2'b10, 6'b0};
        @(posedge aclk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tdata = {8'b0, 1'b0, 15'h0015, 8'h01};
        @(posedge aclk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tdata = {8'b0, 1'b0, 15'h0014, 8'h01};
        @(posedge aclk) m_axis_tvalid = 1;

        @(posedge m_axis_tready) $display(reg_cmd_received);
        if (reg_cmd_received == 24'h01401) begin
            $display("Device configured");
        end else $error("Register received does not match");
        //
        // #(4 * Period);
        // @(posedge clk) cnv_clk_en = 1;
        // @(posedge clk) s_axis_tready = 1;
        //
        // @(negedge s_axis_tvalid) $display("%x", axis_data_received);
        // $display("%x", test_pattern);
        // if (axis_data_received == test_pattern) begin
        //     $display("Test pattern received from ADC");
        // end else $error("Received invalid data");
        //
        // // Try again with different test pattern
        // #(4 * Period) test_pattern = 32'h23ff42;
        // @(negedge s_axis_tvalid)
        // if (axis_data_received == test_pattern) begin
        //     $display("Test pattern received from ADC");
        // end else $error("Received invalid data");
        // $finish();
    end

endmodule
