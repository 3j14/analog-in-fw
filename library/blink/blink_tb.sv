`timescale 1ns / 1ps

module blink_tb;
    bit  clk;
    bit  rst;
    wire led;

    blink dut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    always #5 clk <= ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #10 rst = 0;
        $finish();
    end
endmodule
