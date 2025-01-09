`timescale 1ns / 1ps

module axis_loopback_checker (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI-Stream subordinate
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    // AXI-Stream data manager
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);
    reg [31:0] data = $urandom();
    reg tvalid = 1'b1;
    reg tready = 1'b0;
    assign s_axis_tready = tready;
    assign m_axis_tvalid = tvalid;
    assign m_axis_tdata  = data;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            data   <= $urandom();
            tvalid <= 1;
            tready <= 0;
        end else begin
            tready <= 1;
            if (m_axis_tvalid && m_axis_tready) begin
                tvalid <= 0;
            end
            if (s_axis_tvalid && s_axis_tready) begin
                if (s_axis_tdata != data) $error("Invalid data recieved");
                data   <= $urandom();
                tvalid <= 1;
            end
        end
    end
endmodule

module packetizer_tb #(
    parameter real CLK_FREQ = 125.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));

    bit         clk = 0;
    bit         resetn_loopback = 0;
    bit         resetn_s2mm = 0;

    wire [31:0] s_axis_data_tdata;
    wire        s_axis_data_tvalid;
    wire        s_axis_data_tready;

    wire [31:0] m_axis_s2mm_tdata;
    wire        m_axis_s2mm_tvalid;
    wire        m_axis_s2mm_tready;
    wire        last;

    reg  [31:0] config_reg = 32'b0;
    wire [31:0] counter;

    axis_loopback_checker loopback (
        .aclk(clk),
        .aresetn(resetn_loopback),
        .s_axis_tdata(m_axis_s2mm_tdata),
        .s_axis_tready(m_axis_s2mm_tready),
        .s_axis_tvalid(m_axis_s2mm_tvalid),
        .m_axis_tdata(s_axis_data_tdata),
        .m_axis_tready(s_axis_data_tready),
        .m_axis_tvalid(s_axis_data_tvalid)
    );

    packetizer_s2mm s2mm (
        .aclk(clk),
        .aresetn(resetn_s2mm),
        .s_axis_data_tdata(s_axis_data_tdata),
        .s_axis_data_tvalid(s_axis_data_tvalid),
        .s_axis_data_tready(s_axis_data_tready),

        .m_axis_s2mm_tdata (m_axis_s2mm_tdata),
        .m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
        .m_axis_s2mm_tready(m_axis_s2mm_tready),
        .m_axis_s2mm_tlast (last),

        .config_reg(config_reg),
        .counter(counter)
    );

    always #(Period) clk <= ~clk;

    initial begin
        #(5 * Period);
        @(posedge clk) resetn_loopback = 1;
        resetn_s2mm = 1;
        #(5 * Period);
        @(posedge clk) config_reg = 10;
        #(Period);
        @(posedge clk) if (counter != 1) $error("Counter not incremented");
        #(18 * Period);
        @(posedge clk) if (~last) $error("'last' not asserted");
        #(40 * Period);
        @(posedge clk) resetn_loopback = 0;
        #(Period);
        @(posedge clk) resetn_s2mm = 0;
        config_reg = 0;
        #(Period);
        @(posedge clk) resetn_s2mm = 1;
        #(Period);
        @(posedge clk) config_reg = 10;
        #(40 * Period);
        $finish();
    end
endmodule
