module blink (
    input  clk,
    input  rst,
    output led
);
    logic [31:0] counter;
    assign led = counter[22];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 32'b0;
        end else begin
            counter <= counter + 1;
        end
    end
endmodule
