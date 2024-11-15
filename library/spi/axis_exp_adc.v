module axis_exp_adc #(
    parameter integer NUM_SDI = 4,
    parameter integer DATA_WIDTH = 32
) (
    input wire aclk,
    input wire aresetn,
    input wire [NUM_SDI-1:0] spi_sdi,
    input wire trigger,
    output wire spi_sdo,
    output wire spi_csn,
    output wire spi_clk,
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    output wire m_axis_tready
);
    reg [DATA_WIDTH-1:0] spi_data_in;
    // The spi_shift_mask is a register with the same number of bits
    // that are transferred in each SPI transaction. On each falling
    // SPI clock edge, the bits are read out from the SDI line(s) and
    // the spi_shift_mask is shifted by 1 bit. Once all bits are shifted
    // in, the transaction is done.
    reg [DATA_WIDTH-1:0] spi_shift_mask;
    reg spi_clk_enable;
    reg spi_active;

    // Output clock buffer with gated with clock-enable.
    // Either BUFHCE or BUFMRCE is needed for their synchronous
    // transition.
    BUFHCE #(
        .CE_TYPE ("SYNC"),
        .INIT_OUT(0)
    ) output_clk (
        .O (spi_clk),
        .CE(spi_clk_enable),
        .I (aclk)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            spi_data_in <= 0;
            spi_shift_mask <= 0;
            spi_active <= 0;
            spi_clk_enable <= 0;
            spi_csn <= 1;
        end else begin
            if (trigger && !spi_active) begin
                // Beginning of the SPI transaction. Tell the ADC to
                // start latching out the data on the rising edge of
                // the clock by asserting the CS pin. The clock is still
                // disabled and only enable on the next rising edge.
                // Change CSn to low
                spi_csn <= 0;
                // Set SPI state to active because trigger might
                // fall again.
                spi_active <= 1;
                spi_shift_mask <= {1'b1, {DATA_WIDTH - 1{1'b0}}};
                spi_data_in <= 0;
                spi_clk_enable <= 0;
                // Skip to the next clock cycle. This ensures that
                // there is enough time between asserting CS and
                // the first rising edge.
            end else if (spi_active && spi_shift_mask != 1) begin
                if (!spi_clk_enable) begin
                    // Enable SPI clock and continue to the next cycle
                    spi_clk_enable <= 1;
                end else begin
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
                    spi_data_in <= {spi_data_in[DATA_WIDTH-1-NUM_SDI:0], spi_sdo};
                    spi_shift_mask <= spi_shift_mask >> NUM_SDI;
                end
            end else if (spi_active && spi_shift_mask == 1) begin
                spi_active <= 0;
                spi_cs <= 1;
                spi_clk_enable <= 0;
            end
        end
    end

endmodule
