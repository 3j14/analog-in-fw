`timescale 1ns / 1ps

module adc_impl #(
    parameter integer CNV_TIME = 282
) (
    input  wire  cnv,
    output logic busy = 0,

    input wire sck,
    input wire csn,
    input wire resetn,

    input wire sdi,
    output logic [3:0] sdo = 0,

    input  wire  [31:0] test_pattern,
    output logic [23:0] reg_cmd
);
    typedef enum logic {
        REG_ACCESS,
        CNV
    } device_mode_t;
    device_mode_t device_mode = CNV;

    localparam logic [1:0] LaneModeOne = 2'b00;
    localparam logic [1:0] LaneModeTwo = 2'b01;
    localparam logic [1:0] LaneModeFour = 2'b10;
    logic [1:0] lane_md = LaneModeOne;

    logic data_ready = 0;

    localparam logic [14:0] ExitReg = 15'h0014;
    localparam logic [14:0] ModeReg = 15'h0020;

    logic [5:0] data_idx = 0;

    always_ff @(posedge sck or negedge resetn or negedge csn) begin
        if (!resetn || (!csn && !sck)) begin
            reg_cmd <= 0;
        end else begin
            // Shift SDI into reg_cmd on each clock cycle
            reg_cmd <= {reg_cmd[22:0], sdi};
        end
    end

    // Check the register command at the end of a transaction.
    // Check if the register access command was received (msb == 3'b101)
    // and enable RegAccess mode.
    // If already in RegAccess mode, write registers or exit if exit
    // command received.
    always_ff @(posedge csn or negedge resetn) begin
        if (!resetn) begin
            device_mode <= CNV;
            lane_md <= LaneModeOne;
        end else begin
            if (reg_cmd[23:21] == 3'b101) begin
                device_mode <= REG_ACCESS;
            end else if (device_mode == REG_ACCESS) begin
                if (reg_cmd[23:8] == {1'b0, ModeReg}) begin
                    lane_md <= reg_cmd[7:6];
                end else if (reg_cmd[23:8] == {1'b0, ExitReg}) begin
                    if (reg_cmd[0]) begin
                        device_mode <= CNV;
                    end
                end
            end
        end
    end

    always_ff @(posedge sck or negedge csn or posedge cnv or negedge resetn) begin
        if (!resetn) begin
            data_ready <= 0;
            data_idx <= 0;
            busy <= 0;
            sdo <= 0;
        end else if (cnv) begin
            busy <= 1;
            data_ready <= #(CNV_TIME) 1;
            busy <= #(CNV_TIME) 0;
            data_idx <= 32;
        end else if (device_mode == CNV && !csn && data_ready) begin
            if (data_idx == 0) begin
                data_ready <= 0;
            end else begin
                case (lane_md)
                    LaneModeFour: begin
                        sdo[3:0] <= #(8.1) {<<{test_pattern[data_idx-4+:4]}};
                        data_idx <= data_idx - 4;
                    end
                    LaneModeTwo: begin
                        sdo[1:0] <= #(8.1) {<<{test_pattern[data_idx-2+:2]}};
                        data_idx <= data_idx - 2;
                    end
                    default: begin
                        sdo[0]   <= #(8.1) test_pattern[data_idx-1];
                        data_idx <= data_idx - 1;
                    end
                endcase
            end
        end
    end
endmodule


module adc_spi_controller_tb #(
    parameter integer NUM_SDI = 4,
    parameter integer DATA_WIDTH = 32,
    // clock frequency in MHz
    parameter real SPI_CLK_FREQ = 50.0,
    // cnv clock frequency in MHz
    parameter real CNV_FREQ = 2.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * SPI_CLK_FREQ));
    localparam integer CnvPeriod = $rtoi(1_000.0 / (2.0 * CNV_FREQ));

    logic clk = 1'b0;
    logic resetn = 1'b0;
    logic cnv_clk = 1'b0;
    logic cnv_clk_en = 1'b0;

    always #(Period) clk <= ~clk;
    always #(CnvPeriod) cnv_clk <= ~cnv_clk & cnv_clk_en;

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

    adc_impl adc (
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
        #(5 * Period);
        resetn = 1;
        #(5 * Period);
        reg_cmd = {8'b0, 3'b101, 21'b0};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * Period);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done)
        if (reg_cmd_received != reg_cmd) begin
            $error("Register write command not received");
        end
        reg_cmd = {8'b0, 1'b0, 15'h0020, 2'b10, 6'b0};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * Period);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) reg_cmd = {8'b0, 1'b0, 15'h0015, 8'h01};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * Period);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) reg_cmd = {8'b0, 1'b0, 15'h0014, 8'h01};
        @(posedge clk) start_reg_wrt <= 1;
        #(2 * Period);
        @(posedge clk) start_reg_wrt <= 0;
        @(posedge reg_wrt_done) #(4 * Period);
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
