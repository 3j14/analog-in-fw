module adc_trigger (
    input  wire        aclk,
    input  wire        aresetn,
    output wire        trigger,
    output wire        cnv,
    input  wire        busy,
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
    localparam reg [29:0] AddrTrigger = 30'h0000_0018;

    reg [31:0] trigger_reg = 32'b0;

    reg [31:0] axi_lite_awaddr;
    reg axi_lite_awready;
    reg axi_lite_wready;
    reg [1:0] axi_lite_bresp;
    reg axi_lite_bvalid;
    reg [31:0] axi_lite_araddr;
    reg axi_lite_arready;
    reg [1:0] axi_lite_rresp;
    reg axi_lite_rvalid;

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

    assign s_axi_lite_rdata = (axi_lite_araddr[29:2] == AddrTrigger[29:2]) ? trigger_reg : 0;
    assign s_axi_lite_rresp = (axi_lite_araddr[29:2] == AddrTrigger[29:2]) ? 2'b00 : 2'b10;

    // AXI4-Lite write logic
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            trigger_reg <= 0;
            axi_lite_bresp <= 2'b00;
        end else begin
            if (s_axi_lite_wvalid) begin
                case ((s_axi_lite_awvalid) ? s_axi_lite_awaddr[29:2] : axi_lite_awaddr[29:2])
                    AddrTrigger[29:2]: begin
                        axi4lite_helpers.write_register(s_axi_lite_wdata, s_axi_lite_wstrb,
                                                        trigger_reg);
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
        .divider(trigger_reg),
        .trigger(trigger)
    );
endmodule

module adc_trigger_impl (
    input wire clk,
    input wire resetn,
    input wire [31:0] divider,
    output wire trigger
);
    reg [31:0] counter = 32'b0;
    // Logic for trigger output.
    // By wrinting a value other than 0 to the divider input
    // the trigger is pulsed for one clock cycle every (2^(divier)-1)
    // clock cycles.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 32'b0;
        end else if (counter < divider && divider != 0) begin
            counter <= counter + 1;
        end else begin
            counter <= 32'b0;
        end
    end
    assign trigger = (counter == divider) & |counter;
endmodule
