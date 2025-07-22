`timescale 1ns / 1ps

module axis_dual_dac #(
    parameter integer DAC_DATA_WIDTH = 14
) (
    input wire aclk,
    input wire aresetn,
    input wire [31:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,

    input wire dac_clk_1x,
    input wire locked,
    output wire dac_sel_out,
    output wire dac_rst_out,
    output logic [DAC_DATA_WIDTH-1:0] dac_data_out
);
    // The DAC of the Red Pitaya (DAC1401D125) is configured in interleaved
    // mode, allowing for a single, 14-bit wide data bus for both channels.
    // Data is clocked out on the rising edge of dac_wrt_out, the channel for
    // the current frame is selected using dac_sel_out
    // (high = channel A, low = channel B).
    logic dac_rst;
    assign dac_rst = ~aresetn | ~locked;

    logic [DAC_DATA_WIDTH-1:0] dac_data_a, dac_data_b = {(DAC_DATA_WIDTH) {1'b0}};

    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            dac_data_a <= {(DAC_DATA_WIDTH) {1'b0}};
            dac_data_b <= {(DAC_DATA_WIDTH) {1'b0}};
        end else begin
            if (locked & s_axis_tvalid) begin
                dac_data_a <= s_axis_tdata[DAC_DATA_WIDTH-1:0];
                dac_data_b <= s_axis_tdata[16+DAC_DATA_WIDTH-1:16];
            end
        end
    end

    // Reset logic
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0)
    ) oddr_dac_rst (
        .Q (dac_rst_out),
        .D1(dac_rst),
        .D2(dac_rst),
        .C (dac_clk_1x),
        .CE(1'b1),
        .R (1'b0),
        .S (1'b0)
    );
    // Select logic
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0)
    ) oddr_dac_sel (
        .Q (dac_rst_out),
        .D1(1'b1),
        .D2(1'b0),
        .C (dac_clk_1x),
        .CE(1'b1),
        .R (dac_rst),
        .S (1'b0)
    );
    ODDR #(
        .DDR_CLK_EDGE("SAME_EDGE"),
        .INIT(1'b0)
    ) oddr_dac_data[DAC_DATA_WIDTH-1:0] (
        .Q (dac_data_out),
        .D1(dac_data_a),
        .D2(dac_data_b),
        .C (dac_clk_1x),
        .CE(1'b1),
        .R (dac_rst),
        .S (1'b0)
    );

endmodule
