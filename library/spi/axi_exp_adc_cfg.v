module axi_exp_adc_cfg (
    input  wire        aclk,
    input  wire        aresetn,
    output wire [31:0] cfg,
    output wire [31:0] dma_cfg,
    output wire [31:0] packetizer_cfg,
    input  wire [31:0] status,
    output wire        trigger,
    // AXIS manager to ADC
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    // AXI subordinate
    input  wire [31:0] s_axi_awaddr,
    input  wire [ 2:0] s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [ 3:0] s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [1:0] s_axi_bresp,
    output wire       s_axi_bvalid,
    input  wire       s_axi_bready,

    input  wire [31:0] s_axi_araddr,
    input  wire [ 2:0] s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output wire [31:0] s_axi_rdata,
    output wire [ 1:0] s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready
);
    localparam reg [29:0] AddrConfig = 30'h0000_0004;
    localparam reg [29:0] AddrStatus = 30'h0000_0008;
    localparam reg [29:0] AddrDma = 30'h0000_000C;
    localparam reg [29:0] AddrPacketizer = 30'h0000_0010;
    localparam reg [29:0] AddrAxis = 30'h0000_0014;
    localparam reg [29:0] AddrTrigger = 30'h0000_0018;

    reg [31:0] config_reg = 32'b0;
    reg [31:0] status_reg = 32'b0;
    reg [31:0] dma_cfg_reg = 32'b0;
    reg [31:0] packetizer_cfg_reg = 32'b0;
    reg [31:0] axis_reg = 32'b0;
    reg [31:0] trigger_reg = 32'b0;

    reg [31:0] counter = 32'b0;

    reg [31:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [31:0] axi_araddr;
    reg axi_arready;
    reg [1:0] axi_rresp;
    reg axi_rvalid;
    reg axis_tvalid = 1'b0;

    assign s_axi_awready = axi_awready;
    assign s_axi_wready  = axi_wready;
    assign s_axi_bresp   = axi_bresp;
    assign s_axi_bvalid  = axi_bvalid;
    assign s_axi_arready = axi_arready;
    assign s_axi_rresp   = axi_rresp;
    assign s_axi_rvalid  = axi_rvalid;

    localparam reg [1:0] StateIdle = 2'b00;
    localparam reg [1:0] StateRaddr = 2'b01;
    localparam reg [1:0] StateRdata = 2'b11;
    localparam reg [1:0] StateWaddr = 2'b01;
    localparam reg [1:0] StateWdata = 2'b11;

    reg [1:0] state_write = StateIdle;
    reg [1:0] state_read = StateIdle;

    integer byte_index;

    // State machine for write operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_awready <= 0;
            axi_wready  <= 0;
            axi_bvalid  <= 0;
            axi_awaddr  <= 0;
            state_write <= StateIdle;
        end else begin
            case (state_write)
                StateIdle: begin
                    axi_awready <= 1;
                    axi_wready  <= 1;
                    state_write <= StateWaddr;
                end
                StateWaddr: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        axi_awaddr <= s_axi_awaddr;
                        if (s_axi_wvalid) begin
                            // Set address and write is performed at the same
                            // time, address is available from the
                            // s_axi_awaddr input.
                            axi_awready <= 1;
                            state_write <= StateWaddr;
                            axi_bvalid  <= 1;
                        end else begin
                            // Write will be performed in the upcoming cycles,
                            // disable axi_bvalid if it has been read.
                            axi_awready <= 0;
                            state_write <= StateWdata;
                            if (s_axi_bready && axi_bvalid) axi_bvalid <= 0;
                        end
                    end else begin
                        if (s_axi_bready && axi_bvalid) axi_bvalid <= 0;
                    end
                end
                StateWdata: begin
                    if (s_axi_wvalid && axi_wready) begin
                        state_write <= StateWaddr;
                        axi_bvalid  <= 1;
                        axi_awready <= 1;
                    end else begin
                        if (s_axi_bready && axi_bvalid) axi_bvalid <= 0;
                    end
                end
                default: state_read <= StateIdle;
            endcase
        end
    end

    // State machine for read operations
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            axi_arready <= 0;
            axi_rvalid  <= 0;
            axi_rresp   <= 0;
            state_read  <= StateIdle;
        end else begin
            case (state_read)
                StateIdle: begin
                    axi_arready <= 1;
                    state_read  <= StateRaddr;
                end
                StateRaddr: begin
                    if (s_axi_arvalid && s_axi_arready) begin
                        axi_araddr  <= s_axi_araddr;
                        axi_rvalid  <= 1;
                        axi_arready <= 1;
                        state_read  <= StateRdata;
                    end
                end
                StateRdata: begin
                    if (s_axi_rvalid && s_axi_rready) begin
                        axi_rvalid  <= 0;
                        axi_arready <= 1;
                        state_read  <= StateRaddr;
                    end
                end
                default: state_read <= StateIdle;
            endcase
        end
    end

    assign s_axi_rdata = (axi_araddr[29:2] == AddrConfig[29:2]) ? config_reg :
        (axi_araddr[29:2] == AddrStatus[29:2]) ? status_reg :
        (axi_araddr[29:2] == AddrDma[29:2]) ? dma_cfg_reg :
        (axi_araddr[29:2] == AddrPacketizer[29:2]) ? packetizer_cfg_reg :
        (axi_araddr[29:2] == AddrAxis[29:2]) ? axis_reg :
        (axi_araddr[29:2] == AddrTrigger[29:2]) ? trigger_reg : 0;
    assign s_axi_rresp = (axi_araddr[29:2] == AddrConfig[29:2]) ? 2'b00 :
        (axi_araddr[29:2] == AddrStatus[29:2]) ? 2'b00 :
        (axi_araddr[29:2] == AddrDma[29:2]) ? 2'b00 :
        (axi_araddr[29:2] == AddrPacketizer[29:2]) ? 2'b00 :
        (axi_araddr[29:2] == AddrAxis[29:2]) ? 2'b00 :
        (axi_araddr[29:2] == AddrTrigger[29:2]) ? 2'b00 : 2'b10;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            config_reg <= 0;
            dma_cfg_reg <= 0;
            packetizer_cfg_reg <= 0;
            axis_reg <= 0;
            trigger_reg <= 0;
            axis_tvalid <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                axis_tvalid <= 0;
            end
            if (s_axi_wvalid) begin
                case ((s_axi_awvalid) ? s_axi_awaddr[29:2] : axi_awaddr[29:2])
                    AddrConfig[29:2]: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index] == 1) begin
                                config_reg[8*byte_index+:8] <= s_axi_wdata[8*byte_index+:8];
                            end
                        end
                        axi_bresp <= 2'b00;
                    end
                    AddrDma[29:2]: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index] == 1) begin
                                dma_cfg_reg[8*byte_index+:8] <= s_axi_wdata[8*byte_index+:8];
                            end
                        end
                        axi_bresp <= 2'b00;
                    end
                    AddrPacketizer[29:2]: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index] == 1) begin
                                packetizer_cfg_reg[8*byte_index+:8] <= s_axi_wdata[8*byte_index+:8];
                            end
                        end
                        axi_bresp <= 2'b00;
                    end
                    AddrAxis[29:2]: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index] == 1) begin
                                axis_reg[8*byte_index+:8] <= s_axi_wdata[8*byte_index+:8];
                            end
                        end
                        axi_bresp   <= 2'b00;
                        axis_tvalid <= 1;
                    end
                    AddrTrigger[29:2]: begin
                        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
                            if (s_axi_wstrb[byte_index] == 1) begin
                                trigger_reg[8*byte_index+:8] <= s_axi_wdata[8*byte_index+:8];
                            end
                        end
                        axi_bresp <= 2'b00;
                    end
                    default: axi_bresp <= 2'b10;
                endcase
            end
        end
    end
    assign m_axis_tdata  = axis_reg;
    assign m_axis_tvalid = axis_tvalid & ~s_axi_wvalid;

    // Logic for trigger output.
    // By wrinting a value other than 0 to the trigger register
    // (see 'AddrTrigger'), the trigger is pulsed for one
    // clock cycle every (2^(trigger_reg)-1) clock cycles.
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            counter <= 32'b0;
        end else if (trigger_reg != 32'b0) begin
            if (trigger) begin
                counter <= 1;
            end
            counter <= counter + 1;
        end else begin
            counter <= 32'b0;
        end
    end
    assign trigger = (32'b1 << trigger_reg[4:0]) == counter;
endmodule
