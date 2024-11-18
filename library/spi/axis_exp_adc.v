module axis_exp_adc #(
    parameter integer NUM_SDI = 4,
    parameter integer DATA_WIDTH = 32
) (
    input wire aclk,
    input wire aresetn,
    input wire [NUM_SDI-1:0] spi_sdi,
    input wire trigger,
    output reg spi_sdo = 0,
    output reg spi_csn = 0,
    output wire spi_sck,
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid = 0,
    input wire m_axis_tready
);
    // Internal register holding the data that came from the ADC
    reg [DATA_WIDTH-1:0] data = $unsigned(0);
    assign m_axis_tdata = data;
    // Index of the current SPI clock cycle
    reg [$clog2(DATA_WIDTH / NUM_SDI):0] data_idx = $unsigned(0);
    reg spi_active = 0;
    reg spi_sck_enable = 0;

    // Output clock buffer with gated with clock-enable.
    // Either BUFHCE or BUFMRCE is needed for their synchronous
    // transition.
    BUFHCE #(
        .CE_TYPE ("SYNC"),
        .INIT_OUT(0)
    ) output_clk (
        .O (spi_sck),
        .CE(spi_sck_enable),
        .I (aclk)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            data <= $unsigned(0);
            data_idx <= $unsigned(0);
            spi_active <= 1'b0;
            spi_sck_enable <= 0;
            spi_csn <= 1'b1;
        end else begin
            if (trigger && !spi_active) begin
                // Beginning of the SPI transaction. Tell the ADC to
                // start latching out the data on the rising edge of
                // the clock by asserting the CS pin. As the clock
                // buffer is synchronous, the first clock output will
                // only start on the next cycle.
                // This gives enough time for the ADC to output the
                // first bit(s).
                spi_csn <= 0;
                spi_active <= 1;
                spi_sck_enable <= 1;
                data <= $unsigned(0);
                data_idx <= $unsigned(0);
                // New data is coming in, so AXI Stream output is currently
                // not valid.
                m_axis_tvalid <= 0;
            end else if (spi_active && data_idx < DATA_WIDTH / NUM_SDI) begin
                // Get data from SPI data in.
                // Consider the following initial state:
                //
                // spi_data_in: 8'b01101010
                // spi_sdo: 4'b1011
                // DATA_WIDTH = 8, NUM_SDI = 4.
                //
                // Then, the concatenation looks as follows:
                // {4'b1010, 4'b1011} == 8'b10101011
                //
                // The 'NUM_SDI' least significant bits of 'spi_data_in'
                // are dropped and 'spi_sdo' is added to the most
                // significant bits on the right.
                data <= {data[DATA_WIDTH-1-NUM_SDI:0], spi_sdi};
                // Clock has to be disabled one cycle in advance as
                // it is synchronous with aclk.
                // Next cycle is going to be the last cycle
                if (data_idx + 1 == DATA_WIDTH / NUM_SDI) begin
                    spi_sck_enable <= 1'b0;
                end
                data_idx <= data_idx + 1;
            end else if (spi_active && data_idx == DATA_WIDTH / NUM_SDI) begin
                spi_csn <= 1;
                spi_active <= 0;
                spi_sck_enable <= 0;
                data_idx <= $unsigned(0);
                m_axis_tvalid <= 1;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
        end else begin
            // Turn off TVALID once the subordinate (receiver) is ready
            // Data is always presented on the m_axis_data bus.
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
            end
        end
    end

endmodule
