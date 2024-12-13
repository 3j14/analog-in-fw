`timescale 1ns / 1ps

module adc_trigger_tb #(
    parameter real CLK_FREQ = 125.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));

    bit clk = 0;
    bit resetn = 0;
    reg [31:0] divider = 0;
    bit trigger;

    adc_trigger_impl dut (
        .clk(clk),
        .resetn(resetn),
        .divider(divider),
        .trigger(trigger)
    );

    always #(Period) clk <= ~clk;

    initial begin
        #(4 * Period) @(posedge clk) resetn = 1;
        #(10 * Period) @(posedge clk) divider = 10;
        $finish();
    end

endmodule

