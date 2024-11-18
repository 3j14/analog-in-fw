`timescale 1ns / 1ps

module axis_exp_adc_tb #(
    parameter unsigned NUM_SDI = 2,
    parameter unsigned DATA_WIDTH = 32,
    parameter reg [DATA_WIDTH-1:0] TEST_DATA = $unsigned(2342),
    parameter real CLK_FREQ = 50.0,  // clock frequency in MHz
    parameter integer PERIOD = $rtoi(1_000.0 / (2.0 * CLK_FREQ))  // half clock period in ns
);
    bit clk_out;
    bit trigger;
    bit csn;
    reg [NUM_SDI-1:0] sdo;
    wire clk_in;
    wire s_axis_tvalid;
    reg s_axis_tready = 0;
    wire [DATA_WIDTH-1:0] s_axis_tdata;
    reg [DATA_WIDTH-1:0] axis_data_in;
    // Create a register that is large enough to fit 'DATA_WIDTH'
    // as an unsigned integer.
    reg [$clog2(DATA_WIDTH / NUM_SDI):0] data_idx = $unsigned(0);

    axis_exp_adc #(
        .NUM_SDI(NUM_SDI),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .aclk(clk_out),
        .aresetn(1'b1),
        .spi_sdi(sdo),
        .spi_csn(csn),
        .spi_sck(clk_in),
        .trigger(trigger),
        .m_axis_tdata(s_axis_tdata),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tready(s_axis_tready)
    );

    always #(PERIOD) clk_out <= ~clk_out;

    always @(posedge csn) begin
        data_idx <= $unsigned(0);
    end

    always @(posedge clk_in or negedge csn) begin
        if (!csn) begin
            sdo <= #(PERIOD / 2) TEST_DATA[DATA_WIDTH-(data_idx+1)*NUM_SDI+:NUM_SDI];
            if (data_idx + 1 == DATA_WIDTH / NUM_SDI) begin
                data_idx <= $unsigned(0);
            end else begin
                data_idx <= data_idx + 1;
            end
        end
    end

    always @(posedge clk_out) begin
        if (s_axis_tready && s_axis_tvalid) begin
            axis_data_in <= s_axis_tdata;
        end
    end

    initial begin
        clk_out <= 0;
        trigger <= 0;
        sdo <= $unsigned(0);
        // Wait some time and trigger
        #(10 * PERIOD) @(posedge clk_out) trigger <= 1;
        #(PERIOD) @(posedge clk_out) trigger <= 0;
        // Wait until all data is transmitted
        #(DATA_WIDTH / NUM_SDI * 2 * PERIOD + 4 * PERIOD) @(posedge clk_out) s_axis_tready <= 1;
        // Check if data recieved on AXI Stream is the same
        #(4 * PERIOD) assert property (@(posedge clk_out) axis_data_in == TEST_DATA);
        #(2 * PERIOD) @(posedge clk_out) trigger <= 1;
        #(PERIOD) @(posedge clk_out) trigger <= 0;
    end

endmodule
