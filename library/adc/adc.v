`timescale 1ns / 1ps

module adc #(
    parameter integer NUM_SDI = 4,
    parameter reg SETUP_CS = 1'b0
) (
    input wire aclk,
    input wire aresetn,

    input wire spi_clk,
    input wire spi_resetn,

    input  wire [NUM_SDI-1:0] spi_sdi,
    output wire               spi_sdo,
    output wire               spi_csn,
    output wire               spi_resetn_out,
    output wire               spi_clk_out,

    input wire trigger_acq,

    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    output wire [31:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready
);
endmodule
