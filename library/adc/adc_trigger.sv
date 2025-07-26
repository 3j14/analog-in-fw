`timescale 1ns / 1ps

module adc_trigger (
    input wire aclk,
    input wire aresetn,

    input wire spi_clk,
    input wire spi_resetn,

    input wire cnv_clk,
    input wire cnv_clk_locked,

    output wire        trigger_acq,
    output wire        cnv,
    input  wire        busy,
    input  wire        last,
    input  wire        ready,
    // AXI4-Lite subordinate
    input  wire [31:0] s_axi_lite_awaddr,
    input  wire [ 2:0] s_axi_lite_awprot,
    input  wire        s_axi_lite_awvalid,
    output wire        s_axi_lite_awready,

    input  wire [31:0] s_axi_lite_wdata,
    input  wire [ 3:0] s_axi_lite_wstrb,
    input  wire        s_axi_lite_wvalid,
    output wire        s_axi_lite_wready,

    output wire [1:0] s_axi_lite_bresp,
    output wire       s_axi_lite_bvalid,
    input  wire       s_axi_lite_bready,

    input  wire [31:0] s_axi_lite_araddr,
    input  wire [ 2:0] s_axi_lite_arprot,
    input  wire        s_axi_lite_arvalid,
    output wire        s_axi_lite_arready,

    output wire [31:0] s_axi_lite_rdata,
    output wire [ 1:0] s_axi_lite_rresp,
    output wire        s_axi_lite_rvalid,
    input  wire        s_axi_lite_rready
);
    `include "axi4lite_helpers.vh"
    // Address configuration:
    //  - Config register:
    //      Base address: 0x?000_0100, 32-bit large.
    //  - Divider register:
    //      Base address: 0x?000_0104, 32-bit large
    //
    // Config register:
    // +----------+--------+---------+------------+
    // | RESERVED | ZONE_1 | RESTART | CONTINUOUS |
    // +----------+--------+---------+------------+
    // |     31-4 |      2 |       1 |          0 |
    // +----------+--------+---------+------------+
    //
    // - CONTINUOUS: If zero, after each full transfer (LAST signal asserted by
    //     packetizer), the trigger stops. Writing 1 to this bit makes the
    //     trigger continuous.
    // - RESTART: Writing 1 to this bit will restart the trigger if not in
    //     continuous mode
    // - ZONE_1: Enable acquisition in "Zone 1", directly after the falling
    //     edge of BUSY. By default, this is zero and the acquisition is done
    //     at the next rising edge of CNV.
    // - RESERVED: Not in use, writing to this has no effect
    //
    // Divider regsiter:
    // +------+
    // |  DIV |
    // +------+
    // | 31-0 |
    // +------+
    // - DIV: Unsigned integer, number of clock cycles per conversion.
    localparam logic [29:0] AddrConfig = 30'h0000_0100;
    localparam logic [29:0] AddrDivider = 30'h0000_0104;

    logic [31:0] divider_reg = 32'b0;
    logic [31:0] config_reg = 32'b0;

    logic [31:0] axi_lite_awaddr;
    logic        axi_lite_awready;
    logic        axi_lite_wready;
    logic [ 1:0] axi_lite_bresp;
    logic        axi_lite_bvalid;
    logic [31:0] axi_lite_araddr;
    logic        axi_lite_arready;
    logic        axi_lite_rvalid;

    assign s_axi_lite_awready = axi_lite_awready;
    assign s_axi_lite_wready  = axi_lite_wready;
    assign s_axi_lite_bresp   = axi_lite_bresp;
    assign s_axi_lite_bvalid  = axi_lite_bvalid;
    assign s_axi_lite_arready = axi_lite_arready;
    assign s_axi_lite_rvalid  = axi_lite_rvalid;

    axi4lite_write_state_t state_write = WADDR;
    axi4lite_read_state_t  state_read = RADDR;

    // AXI4-Lite state machine for write operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_lite_awready <= 0;
            axi_lite_wready <= 0;
            axi_lite_bvalid <= 0;
            axi_lite_awaddr <= 0;
            state_write <= WADDR;
        end else begin
            axi_lite_awready <= 1;
            axi_lite_wready  <= 1;
            unique case (state_write)
                WADDR: begin
                    if (s_axi_lite_awvalid && s_axi_lite_awready) begin
                        axi_lite_awaddr <= s_axi_lite_awaddr;
                        if (s_axi_lite_wvalid) begin
                            // Set address and write is performed at the same
                            // time, address is available from the
                            // s_axi_lite_awaddr input.
                            axi_lite_awready <= 1;
                            state_write <= WADDR;
                            axi_lite_bvalid <= 1;
                        end else begin
                            // Write will be performed in the upcoming cycles,
                            // disable axi_lite_bvalid if it has been read.
                            axi_lite_awready <= 0;
                            state_write <= WDATA;
                            if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                        end
                    end else begin
                        if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                    end
                end
                WDATA: begin
                    if (s_axi_lite_wvalid && axi_lite_wready) begin
                        state_write <= WADDR;
                        axi_lite_bvalid <= 1;
                        axi_lite_awready <= 1;
                    end else begin
                        if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                    end
                end
            endcase
        end
    end

    // AXI4-Lite state machine for read operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_lite_araddr <= 0;
            axi_lite_arready <= 0;
            axi_lite_rvalid <= 0;
            state_read <= RADDR;
        end else begin
            axi_lite_arready <= 1;
            unique case (state_read)
                RADDR: begin
                    if (s_axi_lite_arvalid && s_axi_lite_arready) begin
                        axi_lite_araddr <= s_axi_lite_araddr;
                        axi_lite_rvalid <= 1;
                        state_read <= RDATA;
                    end
                end
                RDATA: begin
                    if (s_axi_lite_rvalid && s_axi_lite_rready) begin
                        axi_lite_rvalid <= 0;
                        axi_lite_arready <= 1;
                        state_read <= RADDR;
                    end
                end
                default: state_read <= IDLE;
            endcase
        end
    end

    assign s_axi_lite_rdata = (axi_lite_araddr[29:2] == AddrConfig[29:2]) ? config_reg :
                              (axi_lite_araddr[29:2] == AddrDivider[29:2]) ? divider_reg : 0;
    assign s_axi_lite_rresp = (axi_lite_araddr[29:2] == AddrConfig[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrDivider[29:2]) ? 2'b00 : 2'b10;

    // AXI4-Lite write logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            divider_reg <= 0;
            config_reg <= 0;
            axi_lite_bresp <= 2'b00;
        end else begin
            if (s_axi_lite_wvalid) begin
                if (config_reg[1]) begin
                    // The trigger for the next cycle is always reset.
                    // 'adc_trigger_impl' checks this at every cycle
                    // and resets its state accordingly.
                    config_reg[1] <= 0;
                end
                case ((s_axi_lite_awvalid) ? s_axi_lite_awaddr[29:2] : axi_lite_awaddr[29:2])
                    AddrConfig[29:2]: begin
                        config_reg <= write_register(
                            s_axi_lite_wdata, s_axi_lite_wstrb, config_reg
                        );
                        axi_lite_bresp <= 2'b00;
                    end
                    AddrDivider[29:2]: begin
                        divider_reg <= write_register(
                            s_axi_lite_wdata, s_axi_lite_wstrb, divider_reg
                        );
                        divider_write_trigger <= 1'b1;  // Trigger PLL reconfiguration
                        axi_lite_bresp <= 2'b00;
                    end
                    default: axi_lite_bresp <= 2'b10;
                endcase
            end
        end
    end

    wire last_spi;
    wire [31:0] divider_reg_spi;
    wire [31:0] config_reg_spi;

    xpm_cdc_pulse #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .REG_OUTPUT(1),
        .RST_USED(1),
        .SIM_ASSERT_CHK(1)
    ) cdc_last (
        .dest_pulse(last_spi),
        .dest_clk(spi_clk),
        .dest_rst(~spi_resetn),
        .src_pulse(last),
        .src_clk(aclk),
        .src_rst(~aresetn)
    );

    xpm_cdc_array_single #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG(1),
        .WIDTH(24)
    ) cdc_divider_reg (
        .dest_out(divider_reg_spi),
        .dest_clk(spi_clk),
        .src_in  (divider_reg),
        .src_clk (aclk)
    );

    xpm_cdc_array_single #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .SIM_ASSERT_CHK(1),
        .SRC_INPUT_REG(1),
        .WIDTH(24)
    ) cdc_config_reg (
        .dest_out(config_reg_spi),
        .dest_clk(spi_clk),
        .src_in  (config_reg),
        .src_clk (aclk)
    );

    adc_trigger_impl adc_trigger_0 (
        .clk(spi_clk),
        .resetn(spi_resetn),
        .cnv_clk_raw(pll_cnv_clk),
        .cnv_clk_locked(pll_locked),
        .divider(divider_reg_spi),
        .cfg(config_reg_spi),
        .trigger(trigger_acq),
        .cnv(cnv),
        .busy(busy),
        .last(last_spi),
        .ready(ready)
    );
endmodule

module adc_trigger_impl (
    input  wire        clk,
    input  wire        resetn,
    input  wire        cnv_clk,
    input  wire        cnv_clk_locked,
    input  wire [31:0] divider,
    input  wire [31:0] cfg,
    output wire        trigger,
    output wire        cnv,
    input  wire        busy,
    input  wire        last,
    input  wire        ready
);
    localparam logic [1:0] StateIdle = 2'b00;
    localparam logic [1:0] StateRun = 2'b10;
    localparam logic [1:0] StateStop = 2'b01;
    logic [1:0] state_clk = StateIdle;
    logic       adc_busy = 0;
    logic       acq_pending = 0;
    logic       acq_trigger = 0;

    wire        cnv_clk_enable;
    assign cnv_clk_enable = cnv_clk_locked & ready & state_clk[1];

    BUFHCE #(
        .CE_TYPE ("SYNC"),
        .INIT_OUT(0)
    ) cnv_clk_buffer (
        .O (cnv),
        .CE(cnv_clk_enable),
        .I (cnv_clk)
    );

    // State machine for conversion clock
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_clk <= StateIdle;
        end else begin
            case (state_clk)
                StateRun: begin
                    if (last && ~cfg[1]) begin
                        state_clk <= StateStop;
                    end
                end
                StateStop: begin
                    if (cfg[0] || cfg[1]) begin
                        state_clk <= StateRun;
                    end
                end
                default: state_clk <= StateRun;
            endcase
        end
    end

    assign trigger = ready & acq_trigger;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            adc_busy <= 0;
            acq_pending <= 0;
            acq_trigger <= 0;
        end else begin
            if (acq_trigger) begin
                // Always reset trigger
                acq_trigger <= 0;
            end
            if (cfg[2]) begin
                // In "Zone 1" mode, acq_pending is not used. Set it to zero
                // to avoid triggering, for example when switching zone mode
                // during a transaction.
                acq_pending <= 0;
            end
            if (busy) begin
                if (!adc_busy) begin
                    // Rising edge of 'busy'
                    adc_busy <= 1;
                    if (acq_pending) begin
                        // Trigger previous pending acquisition
                        acq_trigger <= 1;
                        acq_pending <= 0;
                    end
                end
            end else begin
                // ADC not busy
                if (adc_busy) begin
                    // Falling edge of 'busy'
                    adc_busy <= 0;
                    if (cfg[2]) begin
                        acq_trigger <= 1;
                    end else begin
                        acq_pending <= 1;
                    end
                end
            end
        end
    end
endmodule
