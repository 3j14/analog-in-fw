`timescale 1ns / 1ps

module packetizer (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI-Stream data subordinate
    input  wire [31:0] s_axis_data_tdata,
    input  wire        s_axis_data_tvalid,
    output wire        s_axis_data_tready,
    // AXI-Stream (S2MM) data manager
    output wire [31:0] m_axis_s2mm_tdata,
    output wire        m_axis_s2mm_tvalid,
    input  wire        m_axis_s2mm_tready,
    output wire        m_axis_s2mm_tlast,
    // Additional 'tlast' output to trigger other modules
    output wire        last,
    // AXI4-Lite configuration subordinate
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
    // The packetizer takes an input stream of samples from the
    // ADC Manager and streams them to the AXI DMA IP.
    // On the last block of a predefined number of samples, 'TLAST' of
    // the S2MM interface is asserted high.
    // To configure the number of samples, the AXI4-Lite interface can
    // be used. The address of the configuratio register is defined
    // with the parameter 'AddrConfig'.
    // The configuration register is 32-bit register that holds an
    // unsinged integer equal to the number of samples. Writing zero
    // to the register disables the packetizer completly, not forwarding
    // any packages.
    localparam reg [29:0] AddrConfig = 30'h0000_0200;
    localparam reg [29:0] AddrStatus = 30'h0000_0204;

    // Internal register for storing data recieved on the AXI
    // subordinates.
    reg  [31:0] config_reg;
    wire [31:0] counter;

    // AXI4-Lite state machine and registers
    localparam reg [1:0] StateIdle = 2'b00;
    localparam reg [1:0] StateRaddr = 2'b01;
    localparam reg [1:0] StateRdata = 2'b11;
    localparam reg [1:0] StateWaddr = 2'b01;
    localparam reg [1:0] StateWdata = 2'b11;
    reg [ 1:0] state_write = StateIdle;
    reg [ 1:0] state_read = StateIdle;

    reg [31:0] axi_lite_awaddr;
    reg        axi_lite_awready;
    reg        axi_lite_wready;
    reg [ 1:0] axi_lite_bresp;
    reg        axi_lite_bvalid;
    reg [31:0] axi_lite_araddr;
    reg        axi_lite_arready;
    reg        axi_lite_rvalid;
    reg        axis_tvalid = 1'b0;
    reg        axis_tready = 1'b0;

    // Only accept writes if the counter is zero or equal to
    // config_reg
    assign s_axi_lite_awready = axi_lite_awready & ((counter == 32'b0) | (counter == config_reg));
    assign s_axi_lite_wready  = axi_lite_wready & ((counter == 32'b0) | (counter == config_reg));
    assign s_axi_lite_bresp   = axi_lite_bresp;
    assign s_axi_lite_bvalid  = axi_lite_bvalid;
    assign s_axi_lite_arready = axi_lite_arready;
    assign s_axi_lite_rvalid  = axi_lite_rvalid;

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
                    axi_lite_wready  <= 1;
                    state_write      <= StateWaddr;
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
            axi_lite_arready <= 0;
            axi_lite_rvalid <= 0;
            axi_lite_araddr <= 0;
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
                              (axi_lite_araddr[29:2] == AddrStatus[29:2]) ? counter : 0;
    assign s_axi_lite_rresp = (axi_lite_araddr[29:2] == AddrConfig[29:2]) ? 2'b00 :
                              (axi_lite_araddr[29:2] == AddrStatus[29:2]) ? 2'b00 : 2'b10;

    // AXI4-Lite write logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            config_reg <= 0;
            axi_lite_bresp <= 2'b00;
        end else begin
            if (s_axi_lite_wvalid) begin
                case ((s_axi_lite_awvalid) ? s_axi_lite_awaddr[29:2] : axi_lite_awaddr[29:2])
                    AddrConfig[29:2]: begin
                        config_reg <= write_register(
                            s_axi_lite_wdata, s_axi_lite_wstrb, config_reg
                        );
                        axi_lite_bresp <= 2'b00;
                    end
                    // The status register is a read-only register
                    AddrStatus[29:2]: axi_lite_bresp <= 2'b10;
                    default: axi_lite_bresp <= 2'b10;
                endcase
            end
        end
    end

    packetizer_s2mm s2mm (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),
        // AXI-Stream (S2MM) data manager
        .m_axis_s2mm_tdata(m_axis_s2mm_tdata),
        .m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
        .m_axis_s2mm_tready(m_axis_s2mm_tready),
        .m_axis_s2mm_tlast(m_axis_s2mm_tlast),
        // Other
        .config_reg(config_reg),
        .counter(counter)
    );
    assign last = m_axis_s2mm_tlast;
endmodule

module packetizer_s2mm (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI-Stream data subordinate
    input  wire [31:0] s_axis_data_tdata,
    input  wire        s_axis_data_tvalid,
    output wire        s_axis_data_tready,
    // AXI-Stream (S2MM) data manager
    output wire [31:0] m_axis_s2mm_tdata,
    output wire        m_axis_s2mm_tvalid,
    input  wire        m_axis_s2mm_tready,
    output wire        m_axis_s2mm_tlast,
    // Other
    input  wire [31:0] config_reg,
    output reg  [31:0] counter = 32'b0
);
    // AXI-Stream to AXI S2MM
    // Ready to receive data if downstream DMA is redy and config_reg is not 0
    assign s_axis_data_tready = m_axis_s2mm_tready & (|config_reg);
    // Last if config_reg not 0, tvalid is asserted high,
    // and config_reg is equal to counter.
    assign m_axis_s2mm_tlast  = |config_reg & m_axis_s2mm_tvalid & (config_reg == counter);
    // Data is valid if config_reg not zero,
    // and upstream data input is also valid.
    assign m_axis_s2mm_tvalid = |config_reg & s_axis_data_tvalid;
    // Funnel the data through the module.
    //
    // Note: If the upstream manager provides data (s_axis_data_tvalid
    // goes high), the data will stay valid until the downstream
    // subordinate asserts tready to high (m_axis_s2mm_tready). If the
    // 'config_reg' is set to 0, this will not propagate to the manager
    // and the data will stay valid until all conditions are met.
    //
    // There is no situation where the subordinate has tvalid and tready
    // asserted to high while the data is not valid.
    assign m_axis_s2mm_tdata  = s_axis_data_tdata;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            counter <= 0;
        end else begin
            if (m_axis_s2mm_tvalid && m_axis_s2mm_tready) begin
                // Transfer has been performed
                if (config_reg == 32'b0 || counter == config_reg) begin
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule
