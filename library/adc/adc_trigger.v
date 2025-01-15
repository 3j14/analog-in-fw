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
    //      Base address: 0x?000_0100, 32bit large.
    //      If least significant bit is 1, the trigger
    //      will run continuously, not stopping when one
    //      complete DMA transaction is made. If 0, the
    //      trigger will stop as soon as the first
    //      transaction is completed.
    //      Write 1 to the second bit to start the next
    //      transaction (only if first bit is 0).
    localparam reg [29:0] AddrConfig = 30'h0000_0100;
    localparam reg [29:0] AddrDivider = 30'h0000_0104;
    localparam reg [29:0] AddrAverages = 30'h0000_0108;

    reg [31:0] divider_reg = 32'b0;
    reg [31:0] config_reg = 32'b0;
    reg [31:0] averages_reg = 1;

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
                              (axi_lite_araddr[29:2] == AddrDivider[29:2]) ? divider_reg :
                              (axi_lite_araddr[29:2] == AddrAverages[29:2]) ? averages_reg : 0;
    assign s_axi_lite_rresp = (axi_lite_araddr[29:2] == AddrConfig[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrDivider[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrAverages[29:2]) ? 2'b00 : 2'b10;

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
                    AddrAverages[29:2]: begin
                        averages_reg <= write_register(
                            s_axi_lite_wdata, s_axi_lite_wstrb, averages_reg
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
        .averages(averages_reg),
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
    input  wire [31:0] averages,
    input  wire [31:0] cfg,
    output reg         trigger = 0,
    output wire        cnv,
    input  wire        busy,
    input  wire        last,
    input  wire        ready
);
    localparam reg [1:0] StateIdle = 2'b00;
    localparam reg [1:0] StateRun = 2'b10;
    localparam reg [1:0] StateStop = 2'b01;
    reg        adc_busy = 0;
    reg [ 1:0] state_clk = StateIdle;
    reg [31:0] counter = 32'b0;
    reg [31:0] avg_counter = 1;

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

    // Logic for trigger output.
    // By wrinting a value other than 0 to the divider input
    // the trigger is pulsed for one clock cycle every (2^(divier)-1)
    // clock cycles.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 32'b0;
        end else if (counter < divider && divider != 0 && state_clk[1]) begin
            counter <= counter + 1;
        end else begin
            counter <= 32'b0;
        end
    end

    // state_clk[1] is only set if the current state is 'StateRun'
    // and downstream devices are ready
    assign cnv = ready & state_clk[1] & (counter == divider) & |counter;

    // Technically, 'busy' is not aligned with the clock. However,
    // the busy signal is usually high for more than 200 ns,
    // whereas a clock cycle is 20 ns, so it should be sufficient
    // to assume synchronicity with the clock.
    always @(posedge clk or negedge busy or negedge resetn) begin
        if (!resetn) begin
            adc_busy <= 0;
            avg_counter <= 1;
        end else begin
            if (adc_busy && !busy && ready) begin
                // ADC was previously busy but is now done, and downstream
                // devices are ready to recieve data.
                adc_busy <= 0;
                trigger  <= (averages == 0) ? 1 : (avg_counter == averages);
                if (avg_counter < averages) begin
                    avg_counter <= avg_counter + 1;
                end else begin
                    avg_counter <= 1;
                end
            end else begin
                if (trigger) begin
                    trigger <= 0;
                end
                if (busy) begin
                    adc_busy <= 1;
                end
            end
        end
    end
endmodule
