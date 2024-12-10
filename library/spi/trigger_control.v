module trigger_control (
    input wire clk,
    input wire resetn,
    input wire [31:0] divider,
    output wire trigger
);
    reg [31:0] counter = 32'b0;
    // Logic for trigger output.
    // By wrinting a value other than 0 to the divider input
    // the trigger is pulsed for one clock cycle every (2^(divier)-1)
    // clock cycles.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            counter <= 32'b0;
        end else if (divider != 32'b0) begin
            if (trigger) begin
                counter <= 1;
            end
            counter <= counter + 1;
        end else begin
            counter <= 32'b0;
        end
    end
    assign trigger = (32'b1 << divider[4:0]) == counter;
endmodule
