`timescale 1ns / 1ps

module delay #(
    parameter integer DELAY_CYCLES = 2
) (
    input  wire clk,
    input  wire resetn,
    input  wire signal_in,
    output wire signal_out
);
    reg [31:0] counter = 0;
    assign signal_out = (DELAY_CYCLES > 0) ? counter == DELAY_CYCLES : signal_in;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 0;
        end else begin
            if (counter == 0 && signal_in) begin
                counter <= 1;
            end else if (counter > 0) begin
                if (counter >= DELAY_CYCLES) begin
                    counter <= 0;
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule
