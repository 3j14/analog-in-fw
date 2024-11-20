`timescale 1ns / 1ps

module axis_exp_adc #(
    parameter integer NUM_SDI = 4,
    parameter integer DATA_WIDTH = 32
) (
    input wire aclk,
    input wire aresetn,
    // Acquisition trigger
    input wire trigger,
    // SPI interface
    input wire [NUM_SDI-1:0] spi_sdi,
    output reg spi_sdo = 0,
    output wire spi_csn,
    output wire spi_sck,
    output wire spi_resetn,
    // AXI Stream input (register access mode)
    input wire [DATA_WIDTH-1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    // AXI Stream output (conversion data)
    output wire [DATA_WIDTH-1:0] m_axis_tdata,
    output reg m_axis_tvalid = 0,
    input wire m_axis_tready
);
    assign spi_resetn = aresetn;

    // Internal register holding the data that came from the ADC
    reg [DATA_WIDTH-1:0] cnv_data = 0;
    assign m_axis_tdata = cnv_data;

    // Internal register holding the register data to be written to
    // the ADC
    reg [23:0] reg_data = 0;

    // Index of the current SPI clock cycle
    // Used for Conversion and RegAcces modes
    reg [$clog2(DATA_WIDTH+1)-1:0] data_idx = 0;
    localparam reg [$clog2(DATA_WIDTH+1)-1:0] MaxIdxCnv = DATA_WIDTH / NUM_SDI;
    localparam reg [$clog2(DATA_WIDTH+1)-1:0] MaxIdxReg = 24;

    // Device modes
    localparam reg [1:0] Conversion = 2'b00;
    localparam reg [1:0] RegAccessOnce = 2'b01;
    localparam reg [1:0] RegAccess = 2'b11;
    reg [1:0] device_mode = Conversion;
    reg transaction_active = 0;
    reg reg_available = 0;

    localparam reg [23:0] ExitReg = {1'b1, 15'h0014, 8'b01};
    //                write mode ----^^^^  ^^^^^^^^---- address

    // Used to gate the SPI clock
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

    assign s_axis_tready = ~transaction_active & ~reg_available;
    assign spi_csn = ~transaction_active;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            cnv_data <= 0;
            reg_data <= 0;
            data_idx <= 0;
            transaction_active <= 0;
            spi_sck_enable <= 0;
        end else if (~transaction_active) begin
            case (device_mode)
                Conversion: begin
                    if (trigger) begin
                        transaction_active <= 1;
                        spi_sck_enable <= 1;
                        cnv_data <= 0;
                        data_idx <= MaxIdxCnv;
                        spi_sdo <= 0;
                        m_axis_tvalid <= 0;
                    end
                end
                RegAccessOnce, RegAccess: begin
                    if (reg_available) begin
                        transaction_active <= 1;
                        spi_sck_enable <= 1;
                        data_idx <= MaxIdxReg;
                        spi_sdo <= reg_data[MaxIdxReg-1];
                        reg_available <= 0;
                    end
                end
            endcase
        end else begin
            if (data_idx == 0) begin
                transaction_active <= 0;
                spi_sck_enable <= 0;
                data_idx <= 0;
                case (device_mode)
                    Conversion: m_axis_tvalid <= 1;
                    RegAccessOnce, RegAccess: begin
                        if (reg_data[23:21] == 3'b101) begin
                            device_mode <= RegAccess;
                        end else if (reg_data == ExitReg) begin
                            // TODO: Check if this was the first transmission
                            // and the bits transmitted where 24'b101.
                            // Only then the device is actually
                            // in RegAccess mode
                            device_mode <= Conversion;
                        end
                    end
                endcase
            end else begin
                if (data_idx - 1 == 0) begin
                    // Clock has to be disabled one cycle in advance as it
                    // is synchronous with aclk.
                    spi_sck_enable <= 0;
                end
                case (device_mode)
                    Conversion: begin
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
                        cnv_data <= {cnv_data[DATA_WIDTH-1-NUM_SDI:0], spi_sdi};
                    end
                    RegAccessOnce, RegAccess: begin
                        // NOTE: Because the first bit is already shifted out
                        // at the falling edge of CSn, we have to shift out the
                        // bits offset by 1 with respect to the index.
                        // The last cycle can be skipped and the output set to 0.
                        if (data_idx - 1 == 0) begin
                            spi_sdo <= 0;
                        end else begin
                            spi_sdo <= reg_data[data_idx-2];
                        end
                        // TODO: There is currently no way of reading the
                        // returned registers.
                    end
                endcase
                data_idx <= data_idx - 1;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
        end else begin
            if (s_axis_tvalid & s_axis_tready) begin
                reg_data <= s_axis_tdata[23:0];
                reg_available <= 1;
                if (device_mode != RegAccess) begin
                    device_mode <= RegAccessOnce;
                end
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
