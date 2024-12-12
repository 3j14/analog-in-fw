module axis_loopback_checker (
    input  wire        aclk,
    input  wire        aresetn,
    // AXI-Stream subordinate
    input  wire [31:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    // AXI-Stream data manager
    output wire [31:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready
);
    reg [31:0] data = $urandom();
    reg tvalid = 1'b1;
    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = tvalid;
    assign m_axis_tdata  = data;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tvalid <= 1;
        end else begin
            if (tvalid && m_axis_tready) begin
                tvalid <= 0;
            end
            if (s_axis_tvalid && s_axis_tready) begin
                assert (s_axis_tdata == next_data)
                else $error("Invalid data recieved");
                data   <= $urandom();
                tvalid <= 1;
            end
        end
    end
endmodule

module packetizer_tb #(
    parameter real CLK_FREQ = 125.0
);
    localparam integer Period = $rtoi(1_000.0 / (2.0 * CLK_FREQ));

    bit clk = 0;
    bit resetn = 0;
    reg [31:0] count = 0;


    packetizer_s2mm s2mm ();
endmodule
