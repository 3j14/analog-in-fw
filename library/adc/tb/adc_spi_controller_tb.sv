`timescale 1ns / 1ps

module adc_spi_controller_tb #(
    parameter integer NUM_SDI = 4,
    // clock frequency in MHz
    parameter real SPI_CLK_FREQ = 50.0,
    // cnv clock frequency in MHz
    parameter real CNV_FREQ = 2.0
);
    localparam integer ClkPeriodHalf = $rtoi(1_000.0 / (2.0 * SPI_CLK_FREQ));
    localparam integer CnvPeriod = $rtoi(1_000.0 / CNV_FREQ);

    logic clk = 1'b0;
    logic resetn = 1'b0;
    logic cnv_clk = 1'b0;
    logic cnv_clk_en = 1'b0;

    always #(ClkPeriodHalf) clk <= ~clk;
    always #(CnvPeriod) cnv_clk <= cnv_clk_en;
    always_ff @(posedge clk) begin
        cnv_clk <= 1'b0;
    end

    wire spi_clk;
    wire [NUM_SDI-1:0] spi_miso;
    wire spi_mosi;
    wire spi_resetn;
    wire spi_csn;

    wire cnv;
    wire busy;

    logic start_acq = 0;
    logic start_reg_wrt = 0;

    wire acq_done;
    wire reg_wrt_done;
    wire [31:0] cnv_data;
    wire ctrl_busy;

    logic [31:0] test_pattern = 32'h8BADF00D;
    logic [23:0] reg_cmd;
    wire [23:0] reg_cmd_received;

    adc_spi_controller #(
        .NUM_SDI (NUM_SDI),
        .SETUP_CS(1'b0)
    ) dut (
        .clk(clk),
        .resetn(resetn),

        .spi_sdi(spi_miso),
        .spi_sdo(spi_mosi),
        .spi_csn(spi_csn),
        .spi_resetn(spi_resetn),
        .spi_clk(spi_clk),

        .start_acq(start_acq),
        .start_reg_wrt(start_reg_wrt),
        .acq_done(acq_done),
        .reg_wrt_done(reg_wrt_done),
        .busy(ctrl_busy),
        .reg_cmd(reg_cmd),
        .cnv_data(cnv_data)
    );

    adc_model adc (
        .cnv(cnv),
        .busy(busy),
        .sck(spi_clk),
        .csn(spi_csn),
        .resetn(spi_resetn),
        .sdi(spi_mosi),
        .sdo(spi_miso),
        .test_pattern(test_pattern),
        .reg_cmd(reg_cmd_received)
    );

    assign cnv = cnv_clk;

    logic is_adc_busy = 1'b0;
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            is_adc_busy <= 1'b0;
            start_acq   <= 1'b0;
        end else begin
            start_acq <= 1'b0;
            if (busy) begin
                is_adc_busy <= 1'b1;
            end else if (is_adc_busy) begin
                is_adc_busy <= 1'b0;
                start_acq   <= 1'b1;
            end
        end
    end

    initial begin
        $dumpfile("build/traces/adc_spi_controller_tb.vcd");
        $dumpvars();

        resetn = 0;
        #(5 * ClkPeriodHalf);
        resetn = 1;
        #(5 * ClkPeriodHalf);
        reg_cmd = {8'b0, 3'b101, 21'b0};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * ClkPeriodHalf);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done)
        if (reg_cmd_received != reg_cmd) begin
            $error("Register write command not received");
        end
        reg_cmd = {8'b0, 1'b0, 15'h0020, 2'b10, 6'b0};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * ClkPeriodHalf);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) reg_cmd = {8'b0, 1'b0, 15'h0015, 8'h01};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * ClkPeriodHalf);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) reg_cmd = {8'b0, 1'b0, 15'h0014, 8'h01};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * ClkPeriodHalf);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) #(4 * ClkPeriodHalf);
        @(posedge clk) cnv_clk_en = 1'b1;
        @(posedge acq_done)
        if (cnv_data != test_pattern) begin
            $error("Received data does not match test pattern");
        end
        test_pattern = 32'h23ff42;
        @(posedge acq_done)
        if (cnv_data != test_pattern) begin
            $error("Received data does not match test pattern");
        end
        $finish();
    end

endmodule
