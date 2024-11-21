`timescale 1ns / 1ps

module blink #(
    parameter integer USE_RESET = 1
) (
    input  clk,
    input  rst,
    output led
);
    reg [31:0] counter;
    assign led = counter[22];
    wire reset = USE_RESET == 1 ? rst : 1'b0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 32'b0;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule
