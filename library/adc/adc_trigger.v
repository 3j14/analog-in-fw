`timescale 1ns / 1ps

module adc_trigger (
    input  wire        aclk,
    input  wire        aresetn,
    output wire        trigger,
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
    localparam reg [29:0] AddrConfig = 30'h0000_0100;
    localparam reg [29:0] AddrDivider = 30'h0000_0104;

    reg [31:0] divider_reg = 32'b0;
    reg [31:0] config_reg = 32'b0;

    reg [31:0] axi_lite_awaddr;
    reg        axi_lite_awready;
    reg        axi_lite_wready;
    reg [ 1:0] axi_lite_bresp;
    reg        axi_lite_bvalid;
    reg [31:0] axi_lite_araddr;
    reg        axi_lite_arready;
    reg        axi_lite_rvalid;

    assign s_axi_lite_awready = axi_lite_awready;
    assign s_axi_lite_wready  = axi_lite_wready;
    assign s_axi_lite_bresp   = axi_lite_bresp;
    assign s_axi_lite_bvalid  = axi_lite_bvalid;
    assign s_axi_lite_arready = axi_lite_arready;
    assign s_axi_lite_rvalid  = axi_lite_rvalid;

    localparam reg [1:0] StateIdle = 2'b00;
    localparam reg [1:0] StateRaddr = 2'b01;
    localparam reg [1:0] StateRdata = 2'b11;
    localparam reg [1:0] StateWaddr = 2'b01;
    localparam reg [1:0] StateWdata = 2'b11;

    reg [1:0] state_write = StateIdle;
    reg [1:0] state_read = StateIdle;

    // AXI4-Lite state machine for write operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_lite_awready <= 0;
            axi_lite_wready <= 0;
            axi_lite_bvalid <= 0;
            axi_lite_awaddr <= 0;
            state_write <= StateIdle;
        end else begin
            case (state_write)
                StateIdle: begin
                    axi_lite_awready <= 1;
                    axi_lite_wready <= 1;
                    state_write <= StateWaddr;
                end
                StateWaddr: begin
                    if (s_axi_lite_awvalid && s_axi_lite_awready) begin
                        axi_lite_awaddr <= s_axi_lite_awaddr;
                        if (s_axi_lite_wvalid) begin
                            // Set address and write is performed at the same
                            // time, address is available from the
                            // s_axi_lite_awaddr input.
                            axi_lite_awready <= 1;
                            state_write <= StateWaddr;
                            axi_lite_bvalid <= 1;
                        end else begin
                            // Write will be performed in the upcoming cycles,
                            // disable axi_lite_bvalid if it has been read.
                            axi_lite_awready <= 0;
                            state_write <= StateWdata;
                            if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                        end
                    end else begin
                        if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                    end
                end
                StateWdata: begin
                    if (s_axi_lite_wvalid && axi_lite_wready) begin
                        state_write <= StateWaddr;
                        axi_lite_bvalid <= 1;
                        axi_lite_awready <= 1;
                    end else begin
                        if (s_axi_lite_bready && axi_lite_bvalid) axi_lite_bvalid <= 0;
                    end
                end
                default: state_write <= StateIdle;
            endcase
        end
    end

    // AXI4-Lite state machine for read operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_lite_araddr <= 0;
            axi_lite_arready <= 0;
            axi_lite_rvalid <= 0;
            state_read <= StateIdle;
        end else begin
            case (state_read)
                StateIdle: begin
                    axi_lite_arready <= 1;
                    state_read <= StateRaddr;
                end
                StateRaddr: begin
                    if (s_axi_lite_arvalid && s_axi_lite_arready) begin
                        axi_lite_araddr <= s_axi_lite_araddr;
                        axi_lite_rvalid <= 1;
                        axi_lite_arready <= 1;
                        state_read <= StateRdata;
                    end
                end
                StateRdata: begin
                    if (s_axi_lite_rvalid && s_axi_lite_rready) begin
                        axi_lite_rvalid <= 0;
                        axi_lite_arready <= 1;
                        state_read <= StateRaddr;
                    end
                end
                default: state_read <= StateIdle;
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
                        axi_lite_bresp <= 2'b00;
                    end
                    default: axi_lite_bresp <= 2'b10;
                endcase
            end
        end
    end

    adc_trigger_impl adc_trigger_0 (
        .clk(aclk),
        .resetn(aresetn),
        .divider(divider_reg),
        .cfg(config_reg),
        .trigger(trigger),
        .cnv(cnv),
        .busy(busy),
        .last(last),
        .ready(ready)
    );
endmodule

module adc_trigger_impl (
    input  wire        clk,
    input  wire        resetn,
    input  wire [31:0] divider,
    input  wire [31:0] cfg,
    output wire        trigger,
    output wire        cnv,
    input  wire        busy,
    input  wire        last,
    input  wire        ready
);
    localparam reg [1:0] StateIdle = 2'b00;
    localparam reg [1:0] StateRun = 2'b10;
    localparam reg [1:0] StateStop = 2'b01;
    reg [ 1:0] state_clk = StateIdle;
    reg [31:0] counter = 32'b0;
    reg        adc_busy = 0;
    reg        acq_pending = 0;
    reg        acq_trigger = 0;

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

    // Clock-divider for conversion trigger
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 32'b0;
        end else if (counter < divider && divider != 0 && state_clk[1]) begin
            counter <= counter + 1;
        end else begin
            counter <= 32'b0;
        end
    end

    assign cnv = ready & state_clk[1] & (counter == divider) & |counter;
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
