`timescale 1ns / 1ps

module adc_spi_controller #(
    parameter integer NUM_SDI = 4
) (
    input logic spi_clk,
    input logic spi_resetn,

    input  logic [NUM_SDI-1:0] spi_sdi,
    output logic               spi_sdo,
    output logic               spi_csn,
    output logic               spi_clk_out,

    input logic        start_conversion,
    input logic        start_reg_write,
    input logic [23:0] reg_write_data,

    output logic [31:0] conversion_data,
    output logic        conversion_done,
    output logic        reg_write_done,

    // Status
    output logic busy
);
    // Reverse function for SDI bit order
    function automatic logic [NUM_SDI-1:0] reverse(input logic [NUM_SDI-1:0] input_reg);
        for (int i = 0; i < NUM_SDI; i++) begin
            reverse[i] = input_reg[NUM_SDI-1-i];
        end
    endfunction

    // Number of SPI clock cycles for conversion results or register writes
    localparam int SpiConvCycles = 32 / NUM_SDI;
    localparam int SpiWriteCycles = 24;

    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        CONVERSION,
        REG_WRITE
    } state_t;

    state_t state = IDLE;

    logic [7:0] cycle_count;
    logic [23:0] reg_data_shift;
    logic spi_clk_enable;

    assign busy = (state != IDLE);

    BUFHCE #(
        .CE_TYPE ("SYNC"),
        .INIT_OUT(0)
    ) spi_clk_buffer (
        .O (spi_clk_out),
        .CE(spi_clk_enable),
        .I (spi_clk)
    );

    always_ff @(posedge spi_clk or negedge spi_resetn) begin
        if (!spi_resetn) begin
            state <= IDLE;
            spi_csn <= 1'b1;
            spi_sdo <= 1'b0;
            spi_clk_enable <= 1'b0;
            cycle_count <= 0;
            conversion_data <= 0;
            conversion_done <= 1'b0;
            reg_write_done <= 1'b0;
            reg_data_shift <= 0;
        end else begin
            conversion_done <= 1'b0;
            reg_write_done  <= 1'b0;
            unique case (state)
                IDLE: begin
                    if (start_conversion) begin
                        state <= SETUP;
                        spi_csn <= 1'b0;
                        spi_clk_enable <= 1'b0;
                        cycle_count <= SpiConvCycles;
                        conversion_data <= 0;
                        spi_sdo <= 1'b0;
                    end else if (start_reg_write) begin
                        state <= SETUP;
                        spi_csn <= 1'b0;
                        spi_clk_enable <= 1'b0;
                        cycle_count <= SpiWriteCycles;
                        reg_data_shift <= reg_write_data;
                        spi_sdo <= reg_write_data[23];
                    end else begin
                        spi_csn <= 1'b1;
                        spi_clk_enable <= 1'b0;
                        spi_sdo <= 1'b0;
                    end
                end
                SETUP: begin
                    // Setup is used as an intermediate state between idle and
                    // the transfer to meet timing requirements of the ADC.
                    // The CSn falling edge to first clk rising edge time
                    // needs to be at least 9.8 ns. By delaying the clock by
                    // one cycle, this timing can be guaranteed.
                    spi_clk_enable <= 1'b1;
                    if (cycle_count == SpiConvCycles) begin
                        state <= CONVERSION;
                    end else begin
                        state <= REG_WRITE;
                    end
                end
                CONVERSION: begin
                    if (cycle_count > 0) begin
                        cycle_count <= cycle_count - 1;
                        conversion_data <= {conversion_data[31-NUM_SDI:0], reverse(spi_sdi)};

                        if (cycle_count == 1) begin
                            spi_clk_enable <= 1'b0;
                        end
                    end else begin
                        state <= IDLE;
                        spi_csn <= 1'b1;
                        conversion_done <= 1'b1;
                    end
                end
                REG_WRITE: begin
                    if (cycle_count > 0) begin
                        cycle_count <= cycle_count - 1;
                        if (cycle_count > 1) begin
                            reg_data_shift <= reg_data_shift << 1;
                            spi_sdo <= reg_data_shift[22];
                        end else begin
                            spi_sdo <= 1'b0;
                        end
                        if (cycle_count == 1) begin
                            spi_clk_enable <= 1'b0;
                        end
                    end else begin
                        state <= IDLE;
                        spi_csn <= 1'b1;
                        reg_write_done <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
