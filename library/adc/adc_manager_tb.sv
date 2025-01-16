`timescale 1ns / 1ps

module adc_impl #(
    parameter integer CNV_TIME = 282
) (
    input  wire cnv,
    output reg  busy = 0,

    input wire sck,
    input wire csn,
    input wire resetn,

    input wire sdi,
    output reg [3:0] sdo = 0,

    input  reg [31:0] test_pattern,
    output reg [23:0] reg_command
);
    localparam reg Conversion = 1'b0;
    localparam reg RegAccess = 1'b1;

    localparam reg [1:0] LaneModeOne = 2'b00;
    localparam reg [1:0] LaneModeTwo = 2'b01;
    localparam reg [1:0] LaneModeFour = 2'b10;
    reg [1:0] lane_md = LaneModeOne;
    reg data_ready = 0;
    reg device_mode = Conversion;

    localparam reg [14:0] ExitReg = 15'h0014;
    localparam reg [14:0] ModeReg = 15'h0020;

    reg [5:0] data_idx = 0;

    always @(posedge sck or negedge resetn or negedge csn) begin
        if (!resetn || (!csn && !sck)) begin
            reg_command <= 0;
        end else if (!csn) begin
            reg_command <= {reg_command[22:0], sdi};
        end
    end

    // Check the register command at the end of a transaction.
    // Check if the register access command was received (msb == 3'b101)
    // and enable RegAccess mode.
    // If already in RegAccess mode, write registers or exit if exit
    // command received.
    always @(posedge csn or negedge resetn) begin
        if (!resetn) begin
            device_mode <= Conversion;
            lane_md <= LaneModeOne;
        end else begin
            if (reg_command[23:21] == 3'b101) begin
                device_mode <= RegAccess;
            end else if (device_mode == RegAccess) begin
                if (reg_command[23:8] == {1'b0, ModeReg}) begin
                    lane_md <= reg_command[7:6];
                end else if (reg_command[23:8] == {1'b0, ExitReg}) begin
                    if (reg_command[0]) begin
                        device_mode <= Conversion;
                    end
                end
            end
        end
    end

    always @(posedge sck or negedge csn or posedge cnv or negedge resetn) begin
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
        end else if (device_mode == Conversion && !csn && data_ready) begin
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

module adc_manager_tb #(
    parameter unsigned NUM_SDI = 4,
    parameter unsigned DATA_WIDTH = 32,
    // clock frequency in MHz
    parameter real CLK_FREQ = 50.0,
    // cnv clock frequency in MHz
    parameter real CNV_FREQ = 2.0
);
    // half clock period in ns
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));
    localparam integer CnvPeriod = $rtoi(1_000.0 / (2.0 * CNV_FREQ));
    reg [DATA_WIDTH-1:0] test_pattern = 32'h8BADF00D;

    bit clk = 0;
    bit aresetn = 1;
    bit cnv_clk = 0;
    bit cnv_clk_en = 0;

    wire cnv;
    wire busy;
    bit trigger = 0;

    wire sck;
    wire mosi;
    wire [3:0] miso;
    wire resetn;
    wire csn;
    wire ready;

    // AXI Stream sender
    reg [DATA_WIDTH-1:0] m_axis_tdata = 0;
    wire m_axis_tready;
    reg m_axis_tvalid = 0;

    // AXI Stream receiver
    wire [DATA_WIDTH-1:0] s_axis_tdata;
    reg s_axis_tready = 0;
    wire s_axis_tvalid;

    // Received data from AXI Stream
    reg [DATA_WIDTH-1:0] axis_data_received;
    // Received register command on ADC
    reg [23:0] reg_command_received;

    wire [31:0] status;

    adc_impl adc (
        .cnv(cnv),
        .busy(busy),
        .sck(sck),
        .csn(csn),
        .resetn(resetn),
        .sdi(mosi),
        .sdo(miso),
        .test_pattern(test_pattern),
        .reg_command(reg_command_received)
    );

    adc_manager #(
        .NUM_SDI(NUM_SDI)
    ) dut (
        .aclk(clk),
        .aresetn(aresetn),
        .spi_sdi(miso),
        .spi_sdo(mosi),
        .spi_csn(csn),
        .spi_clk(sck),
        .spi_resetn(resetn),
        .trigger(trigger),
        .s_axis_tdata(m_axis_tdata),
        .s_axis_tvalid(m_axis_tvalid),
        .s_axis_tready(m_axis_tready),
        .m_axis_tdata(s_axis_tdata),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tready(s_axis_tready),
        .status(status),
        .ready(ready)
    );

    always #(Period) clk <= ~clk;
    always #(CnvPeriod) cnv_clk <= ~cnv_clk & cnv_clk_en;

    assign cnv = cnv_clk;

    always @(posedge clk) begin
        if (s_axis_tready && s_axis_tvalid) begin
            axis_data_received <= s_axis_tdata;
        end
    end

    always @(negedge busy) begin
        trigger <= 1;
        trigger <= #(3 * Period) 0;
    end

    initial begin
        $dumpfile("build/traces/adc_manager_tb.vcd");
        $dumpvars();
        m_axis_tdata = {8'b0, 3'b101, 21'b0};

        #(10 * Period);

        @(posedge clk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tvalid = 0;

        m_axis_tdata = {8'b0, 1'b0, 15'h0020, 2'b10, 6'b0};
        @(posedge clk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tvalid = 0;

        m_axis_tdata = {8'b0, 1'b0, 15'h0015, 8'h01};
        @(posedge clk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tvalid = 0;

        m_axis_tdata = {8'b0, 1'b0, 15'h0014, 8'h01};
        @(posedge clk) m_axis_tvalid = 1;
        @(negedge m_axis_tready) m_axis_tvalid = 0;

        @(posedge m_axis_tready)
        if (reg_command_received == {1'b0, 15'h0014, 8'b00000001}) begin
            $display("Device configured");
        end else $error("Register received does not match");

        #(4 * Period);
        @(posedge clk) cnv_clk_en = 1;
        @(posedge clk) s_axis_tready = 1;

        @(negedge s_axis_tvalid) $display("%x", axis_data_received);
        $display("%x", test_pattern);
        if (axis_data_received == test_pattern) begin
            $display("Test pattern received from ADC");
        end else $error("Received invalid data");

        // Try again with different test pattern
        #(4 * Period) test_pattern = 32'h23ff42;
        @(negedge s_axis_tvalid)
        if (axis_data_received == test_pattern) begin
            $display("Test pattern received from ADC");
        end else $error("Received invalid data");
        $finish();
    end

endmodule
