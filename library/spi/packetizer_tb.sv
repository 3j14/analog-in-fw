`timescale 1ns / 1ps
`include "packetizer.v"

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
    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = tvalid;
    assign m_axis_tdata  = data;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tvalid <= 1;
        end else begin
            if (tvalid && m_axis_tready) begin
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
    bit         resetn = 0;

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
        .aresetn(resetn),
        .s_axis_tdata(m_axis_s2mm_tdata),
        .s_axis_tready(m_axis_s2mm_tready),
        .s_axis_tvalid(m_axis_s2mm_tvalid),
        .m_axis_tdata(s_axis_data_tdata),
        .m_axis_tready(s_axis_data_tready),
        .m_axis_tvalid(s_axis_data_tvalid)
    );

    packetizer_s2mm s2mm (
        .aclk(clk),
        .aresetn(resetn),
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
        @(posedge clk) resetn = 1;
        #(5 * Period);
        @(posedge clk) config_reg = 10;
        #(Period);
        @(posedge clk) if (counter != 1) $error("Counter not incremented");
        #(18 * Period);
        @(posedge clk) if (~last) $error("'last' not asserted");
        #(40 * Period);
        $finish();
    end
endmodule
