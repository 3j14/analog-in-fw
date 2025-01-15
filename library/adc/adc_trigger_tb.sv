`timescale 1ns / 1ps

module adc_model #(
    parameter integer CNV_TIME = 282
) (
    input  wire resetn,
    input  wire cnv,
    output reg  busy = 0
);
    always @(posedge cnv or negedge resetn) begin
        if (!resetn) begin
            busy <= 0;
        end else begin
            if (busy) begin
                $error("Asserted 'cnv' while ADC is busy");
            end
            busy <= 1;
            busy <= #(CNV_TIME) 0;
        end
    end
endmodule

module adc_trigger_tb #(
    parameter real CLK_FREQ = 50.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));

    bit clk = 0;
    bit resetn = 0;
    wire cnv;
    wire busy;
    bit last = 0;
    bit ready = 0;
    reg [31:0] divider = 0;
    reg [31:0] cfg = 0;
    reg [31:0] averages = 1;
    wire trigger;

    adc_model adc (
        .resetn(resetn),
        .cnv(cnv),
        .busy(busy)
    );

    adc_trigger_impl dut (
        .clk(clk),
        .resetn(resetn),
        .divider(divider),
        .averages(averages),
        .cfg(cfg),
        .trigger(trigger),
        .cnv(cnv),
        .busy(busy),
        .last(last),
        .ready(ready)
    );

    always #(Period) clk <= ~clk;

    bit has_cnv = 0;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            has_cnv <= 0;
        end else begin
            if (cnv) begin
                has_cnv <= 1;
            end
        end
    end

    initial begin
        #(4 * Period) @(posedge clk) resetn = 1;
        #(10 * Period) @(posedge clk) divider = 50;
        #(divider * 2 * Period);
        @(posedge clk) if (cnv) $error("Conversion triggered (not ready)");
        #(2 * Period) @(posedge clk) ready = 1;
        #(divider * 2 * Period);
        @(posedge clk) if (!cnv) $error("Conversion not triggered");
        @(negedge busy);
        @(posedge clk) if (!trigger) $error("Acquisition not triggered");
        @(negedge cnv);
        #((divider + 1) * 2 * Period);
        @(posedge clk) if (!cnv) $error("Conversion not triggered");
        // After acquisition, set 'last' to 1
        @(posedge trigger);
        #(2 * Period);
        @(posedge clk) last = 1;
        #(Period);
        @(posedge clk) last = 0;
        has_cnv = 0;
        // Wait for at least 2 cycles to check that no conversion is triggered
        #(divider * 4 * Period);
        if (has_cnv) $error("Unexpected conversion after 'last'");
        @(posedge clk) cfg[1] = 1'b1;
        #(Period);
        @(posedge clk) cfg[1] = 1'b0;
        #(divider * 2 * Period);
        @(posedge clk) if (!cnv) $error("Conversion not triggered");
        #(4 * Period);
        $finish();
    end

endmodule

