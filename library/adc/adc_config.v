`timescale 1ns / 1ps

module adc_config (
    input  wire        aclk,
    input  wire        aresetn,
    output wire [31:0] cfg,
    input  wire [31:0] status,
    output wire        adc_resetn,
    output wire        dma_resetn,
    output wire        packetizer_resetn,
    output wire        pwr_en,
    output wire        ref_en,
    output wire        io_en,
    output wire        diffamp_en,
    output wire        opamp_en,
    // AXIS manager to ADC
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    // AXI subordinate
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
    localparam reg [29:0] AddrConfig = 30'h0000_0000;
    localparam reg [29:0] AddrStatus = 30'h0000_0004;
    localparam reg [29:0] AddrAxis = 30'h0000_0008;

    reg  [31:0] config_reg = 32'b0;
    wire [31:0] status_reg;
    reg  [31:0] dma_cfg_reg = 32'b0;
    reg  [31:0] packetizer_cfg_reg = 32'b0;
    reg  [31:0] axis_reg = 32'b0;

    assign cfg = config_reg;
    assign status_reg = status;

    assign adc_resetn = config_reg[0] & aresetn;
    assign dma_resetn = config_reg[1] & aresetn;
    assign packetizer_resetn = config_reg[2] & aresetn;
    assign pwr_en = config_reg[3];
    assign ref_en = config_reg[4];
    assign io_en = config_reg[5];
    assign diffamp_en = config_reg[6];
    assign opamp_en = config_reg[7];

    reg [31:0] axi_lite_awaddr;
    reg axi_lite_awready;
    reg axi_lite_wready;
    reg [1:0] axi_lite_bresp;
    reg axi_lite_bvalid;
    reg [31:0] axi_lite_araddr;
    reg axi_lite_arready;
    reg [1:0] axi_lite_rresp;
    reg axi_lite_rvalid;
    reg axis_tvalid = 1'b0;

    assign s_axi_lite_awready = axi_lite_awready;
    assign s_axi_lite_wready  = axi_lite_wready;
    assign s_axi_lite_bresp   = axi_lite_bresp;
    assign s_axi_lite_bvalid  = axi_lite_bvalid;
    assign s_axi_lite_arready = axi_lite_arready;
    assign s_axi_lite_rresp   = axi_lite_rresp;
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
                              (axi_lite_araddr[29:2] == AddrStatus[29:2]) ? status_reg :
                              (axi_lite_araddr[29:2] == AddrAxis[29:2]) ? axis_reg : 0;
    assign s_axi_lite_rresp = (axi_lite_araddr[29:2] == AddrConfig[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrStatus[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrAxis[29:2]) ? 2'b00 : 2'b10;

    // AXI4-Lite write logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            config_reg <= 0;
            axis_reg <= 0;
            axis_tvalid <= 0;
            axi_lite_bresp <= 2'b00;
        end else begin
            if (axis_tvalid && m_axis_tready) begin
                axis_tvalid <= 0;
            end
            if (s_axi_lite_wvalid) begin
                case ((s_axi_lite_awvalid) ? s_axi_lite_awaddr[29:2] : axi_lite_awaddr[29:2])
                    AddrConfig[29:2]: begin
                        write_register(s_axi_lite_wdata, s_axi_lite_wstrb, config_reg);
                        axi_lite_bresp <= 2'b00;
                    end
                    AddrStatus[29:2]: begin
                        // The status register is read-only
                        axi_lite_bresp <= 2'b10;
                    end
                    AddrAxis[29:2]: begin
                        write_register(s_axi_lite_wdata, s_axi_lite_wstrb, axis_reg);
                        axi_lite_bresp <= 2'b00;
                        axis_tvalid <= 1;
                    end
                    default: axi_lite_bresp <= 2'b10;
                endcase
            end
        end
    end
    assign m_axis_tdata  = axis_reg;
    assign m_axis_tvalid = axis_tvalid;
endmodule
