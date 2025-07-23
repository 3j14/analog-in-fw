`timescale 1ns / 1ps

module adc_spi_controller #(
    parameter integer NUM_SDI  = 4,
    parameter logic   SETUP_CS = 1'b0
) (
    input wire clk,
    input wire resetn,

    input  wire  [NUM_SDI-1:0] spi_sdi,
    output logic               spi_sdo,
    output logic               spi_csn,
    output wire                spi_resetn,
    output wire                spi_clk,

    input wire start_acq,
    input wire start_reg_wrt,
    output logic acq_done,
    output logic reg_wrt_done,
    output wire busy,
    input wire [23:0] reg_cmd,
    output logic [31:0] cnv_data

);
    // Number of SPI clock cycles for conversion results or register writes
    localparam int SpiConvCycles = 32 / NUM_SDI;
    localparam int SpiWriteCycles = 24;

    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        ACQUISITION,
        REG_WRT
    } state_t;

    state_t state = IDLE;

    logic [7:0] cycle_count;
    logic [23:0] reg_data_shift;
    logic spi_clk_enable;

    assign busy = (state != IDLE);
    assign spi_resetn = resetn;

    BUFHCE #(
        .CE_TYPE ("SYNC"),
        .INIT_OUT(0)
    ) spi_clk_buffer (
        .O (spi_clk),
        .CE(spi_clk_enable),
        .I (clk)
    );

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
            spi_csn <= 1'b1;
            spi_sdo <= 1'b0;
            spi_clk_enable <= 1'b0;
            cycle_count <= 0;
            cnv_data <= 0;
            acq_done <= 1'b0;
            reg_wrt_done <= 1'b0;
            reg_data_shift <= 0;
        end else begin
            acq_done <= 1'b0;
            reg_wrt_done <= 1'b0;
            unique case (state)
                IDLE: begin
                    if (start_acq) begin
                        state <= (SETUP_CS) ? SETUP : ACQUISITION;
                        spi_csn <= 1'b0;
                        spi_clk_enable <= ~SETUP_CS;
                        cycle_count <= SpiConvCycles;
                        cnv_data <= 0;
                        spi_sdo <= 1'b0;
                    end else if (start_reg_wrt) begin
                        state <= (SETUP_CS) ? SETUP : REG_WRT;
                        spi_csn <= 1'b0;
                        spi_clk_enable <= ~SETUP_CS;
                        cycle_count <= SpiWriteCycles;
                        reg_data_shift <= reg_cmd;
                        spi_sdo <= reg_cmd[23];
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
                        state <= ACQUISITION;
                    end else begin
                        state <= REG_WRT;
                    end
                end
                ACQUISITION: begin
                    if (cycle_count > 0) begin
                        cycle_count <= cycle_count - 1;
                        cnv_data <= {cnv_data[31-NUM_SDI:0], {<<{spi_sdi}}};

                        if (cycle_count == 1) begin
                            spi_clk_enable <= 1'b0;
                        end
                    end else begin
                        state <= IDLE;
                        spi_csn <= 1'b1;
                        acq_done <= 1'b1;
                    end
                end
                REG_WRT: begin
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
                        reg_wrt_done <= 1'b1;
                    end
                end
            endcase
        end
    end
endmodule
