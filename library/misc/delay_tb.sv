`timescale 1ns / 1ps

module delay_tb #(
    parameter integer DELAY_CYCLES = 4,
    parameter real CLK_FREQ = 125.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));

    bit  clk = 0;
    bit  resetn = 0;
    bit  signal_in = 0;
    wire signal_out;

    delay #(
        .DELAY_CYCLES(DELAY_CYCLES)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .signal_in(signal_in),
        .signal_out(signal_out)
    );
    always #(Period) clk <= ~clk;

    initial begin
        #(4 * Period);
        @(posedge clk) resetn = 1;
        #(2 * Period);
        @(posedge clk) signal_in = 1;
        signal_in = #(Period) 0;
        #(7 * Period);
        @(posedge clk) if (signal_out != 1) $error("Signal out not asserted");
        #(2 * Period);
        @(posedge clk) if (signal_out != 0) $error("Signal out not de-asserted");
        #(4 * Period);
        $finish();
    end

endmodule
