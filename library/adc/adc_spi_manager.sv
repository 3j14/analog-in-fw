`timescale 1ns / 1ps

module adc_spi_manager #(
    parameter integer NUM_SDI  = 4,
    parameter logic   SETUP_CS = 1'b0
) (
    input wire aclk,
    input wire aresetn,

    input wire spi_clk,
    input wire spi_resetn,

    input  wire [NUM_SDI-1:0] spi_sdi,
    output wire               spi_sdo,
    output wire               spi_csn,
    output wire               spi_resetn_out,
    output wire               spi_clk_out,

    input wire trigger_acq,

    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    output wire  [31:0] m_axis_tdata,
    output logic        m_axis_tvalid,
    input  wire         m_axis_tready,

    // Status (aclk domain)
    output wire ready
);
    typedef enum logic [1:0] {
        IDLE,
        WAIT_ACQ,
        WAIT_REG_WRT
    } axi_state_t;

    axi_state_t state = IDLE;

    wire [31:0] cnv_data;
    assign m_axis_tdata = cnv_data;
    reg [23:0] reg_cmd;
    logic start_acq, start_reg_wrt = 1'b0;
    wire start_acq_spi, start_reg_wrt_spi;

    wire acq_done;
    wire reg_wrt_done;
    wire spi_busy_aclk;

    wire acq_done_spi;
    wire reg_wrt_done_spi;
    wire [31:0] cnv_data_spi;
    wire [23:0] reg_cmd_spi;
    wire busy_spi;

    // AXI interface logic
    assign ready = (state == IDLE) && !spi_busy_aclk && aresetn;
    assign s_axis_tready = ready;
    assign m_axis_tdata = cnv_data;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            m_axis_tvalid <= 1'b0;
            reg_cmd <= 0;
            start_acq <= 1'b0;
            start_reg_wrt <= 1'b0;
        end else begin
            start_acq <= 1'b0;
            start_reg_wrt <= 1'b0;
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
            end
            case (state)
                IDLE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        reg_cmd <= s_axis_tdata[23:0];
                        start_reg_wrt <= 1'b1;
                        state <= WAIT_REG_WRT;
                    end else if (trigger_acq && !spi_busy_aclk) begin
                        start_acq <= 1'b1;
                        state <= WAIT_ACQ;
                    end
                end
                WAIT_ACQ: begin
                    if (acq_done) begin
                        m_axis_tvalid <= 1'b1;
                        state <= IDLE;
                    end
                end
                WAIT_REG_WRT: begin
                    if (reg_wrt_done) begin
                        reg_cmd <= 0;
                        state   <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

    xpm_cdc_pulse #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .REG_OUTPUT(1),
        .RST_USED(1),
        .SIM_ASSERT_CHK(1)
    ) cdc_start_acq (
        .dest_pulse(start_acq_spi),
        .dest_clk(spi_clk),
        .dest_rst(~spi_resetn),
        .src_pulse(start_acq),
        .src_clk(aclk),
        .src_rst(~aresetn)
    );

    xpm_cdc_pulse #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .REG_OUTPUT(1),
        .RST_USED(1),
        .SIM_ASSERT_CHK(1)
    ) cdc_start_req_wrt (
        .dest_pulse(start_reg_wrt_spi),
        .dest_clk(spi_clk),
        .dest_rst(~spi_resetn),
        .src_pulse(start_reg_wrt),
        .src_clk(aclk),
        .src_rst(~aresetn)
    );

    xpm_cdc_array_single #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG(1),
        .WIDTH(24)
    ) cdc_reg_cmd (
        .dest_out(reg_cmd_spi),
        .dest_clk(spi_clk),
        .src_in  (reg_cmd),
        .src_clk (aclk)
    );

    xpm_cdc_pulse #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .REG_OUTPUT(1),
        .RST_USED(1),
        .SIM_ASSERT_CHK(1)
    ) cdc_acq_done (
        .dest_pulse(acq_done),
        .dest_clk(aclk),
        .dest_rst(~aresetn),
        .src_pulse(acq_done_spi),
        .src_clk(spi_clk),
        .src_rst(~spi_resetn)
    );

    xpm_cdc_pulse #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .REG_OUTPUT(1),
        .RST_USED(1),
        .SIM_ASSERT_CHK(1)
    ) cdc_reg_wrt_done (
        .dest_pulse(reg_wrt_done),
        .dest_clk(aclk),
        .dest_rst(~aresetn),
        .src_pulse(reg_wrt_done_spi),
        .src_clk(spi_clk),
        .src_rst(~spi_resetn)
    );

    xpm_cdc_array_single #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG(1),
        .WIDTH(32)
    ) cdc_conv_data (
        .dest_out(cnv_data),
        .dest_clk(aclk),
        .src_in  (cnv_data_spi),
        .src_clk (spi_clk)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF  (2),
        .INIT_SYNC_FF  (0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG (1)
    ) cdc_busy (
        .dest_out(spi_busy_aclk),
        .dest_clk(aclk),
        .src_in  (busy_spi),
        .src_clk (spi_clk)
    );

    adc_spi_controller #(
        .NUM_SDI(NUM_SDI)
    ) spi_ctrl (
        .clk(spi_clk),
        .resetn(spi_resetn),

        .spi_sdi(spi_sdi),
        .spi_sdo(spi_sdo),
        .spi_csn(spi_csn),
        .spi_clk(spi_clk_out),
        .spi_resetn(spi_resetn_out),

        .start_acq(start_acq_spi),
        .start_reg_wrt(start_reg_wrt_spi),
        .acq_done(acq_done_spi),
        .reg_wrt_done(reg_wrt_done_spi),

        .reg_cmd (reg_cmd_spi),
        .cnv_data(cnv_data_spi),

        .busy(busy_spi)
    );

endmodule

