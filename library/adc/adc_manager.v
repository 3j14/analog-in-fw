`timescale 1ns / 1ps

module adc_manager #(
    parameter integer NUM_SDI = 4
) (
    input  wire               aclk,
    input  wire               aresetn,
    // Acquisition trigger
    input  wire               trigger,
    // SPI interface
    input  wire [NUM_SDI-1:0] spi_sdi,
    output reg                spi_sdo = 0,
    output wire               spi_csn,
    output wire               spi_clk,
    output wire               spi_resetn,
    // AXI Stream input (register access mode)
    input  wire [     32-1:0] s_axis_tdata,
    input  wire               s_axis_tvalid,
    output wire               s_axis_tready,
    // AXI Stream output (conversion data)
    output wire [     32-1:0] m_axis_tdata,
    output reg                m_axis_tvalid = 0,
    input  wire               m_axis_tready,
    // Status
    output wire [     32-1:0] status,
    output wire               ready
);
    // Reverse registers
    // Used to reverse the order of sdi[*]. The AD4030-24 in multi data lane
    // mode reverses the order of the sdi ports such that sdi[0] is the most
    // significant bit and sdi[3] is the least significant bit.
    function automatic [NUM_SDI-1:0] reverse;
        input reg [NUM_SDI-1:0] input_reg;
        integer bit_index;
        begin
            for (bit_index = 0; bit_index < NUM_SDI; bit_index = bit_index + 1) begin
                reverse[bit_index] = input_reg[NUM_SDI-1-bit_index];
            end
        end
    endfunction

    localparam integer DataWidth = 32;
    assign spi_resetn = aresetn;

    // Internal register holding the data that came from the ADC
    reg [DataWidth-1:0] cnv_data = 0;
    assign m_axis_tdata = cnv_data;

    // Internal register holding the register data to be written to
    // the ADC
    reg [23:0] reg_data = 0;

    // Index of the current SPI clock cycle
    // Used for Conversion and RegAcces modes
    localparam integer IdxDataSize = $clog2(DataWidth + 1);
    reg [IdxDataSize-1:0] data_idx = 0;
    localparam integer MaxIdxCnv = DataWidth / NUM_SDI;
    localparam integer MaxIdxReg = 24;

    // Device modes
    localparam reg [1:0] Conversion = 2'b00;
    localparam reg [1:0] RegAccessOnce = 2'b01;
    localparam reg [1:0] RegAccess = 2'b11;
    reg [1:0] device_mode = Conversion;
    reg transaction_active = 0;
    reg reg_available = 0;
    reg cs = 0;

    localparam reg [23:0] ExitReg = {1'b0, 15'h0014, 8'd1};
    //                write mode ----^^^^  ^^^^^^^^---- address

    // Used to gate the SPI clock
    reg spi_clk_enable = 0;

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

    assign s_axis_tready = ~cs & ~transaction_active & ~reg_available;
    assign spi_csn = ~cs;
    assign ready = ~cs & ~transaction_active & ~reg_available;

    assign status[0] = transaction_active;
    assign status[1] = reg_available;
    assign status[3:2] = device_mode;
    assign status[4] = m_axis_tvalid;
    assign status[7:5] = 0;
    assign status[31:8] = reg_data;

    always @(posedge spi_clk or negedge aresetn or negedge spi_csn) begin
        if (!aresetn) begin
            cnv_data <= 0;
            spi_sdo  <= 0;
            data_idx <= 0;
        end else begin
            if (~spi_csn && !transaction_active) begin
                // CSn was just asserted, setup counter
                if (device_mode == Conversion) begin
                    data_idx <= MaxIdxCnv[IdxDataSize-1:0];
                    spi_sdo  <= 0;
                end else begin
                    data_idx <= MaxIdxReg[IdxDataSize-1:0];
                    spi_sdo  <= reg_data[MaxIdxReg-1];
                end
            end else if (~spi_csn && data_idx > 0) begin
                if (device_mode == Conversion) begin
                    // Get data from SPI data in.
                    // Consider the following initial state:
                    //
                    // spi_data_in: 8'b01101010
                    // spi_sdo: 4'b1011
                    // DataWidth = 8, NUM_SDI = 4.
                    //
                    // Then, the concatenation looks as follows:
                    // {4'b1010, 4'b1011} == 8'b10101011
                    //
                    // The 'NUM_SDI' least significant bits of 'spi_data_in'
                    // are dropped and 'spi_sdo' is added to the most
                    // significant bits on the right.
                    cnv_data <= {cnv_data[DataWidth-1-NUM_SDI:0], reverse(spi_sdi)};
                end else begin
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
                data_idx <= data_idx - 1;
            end
        end
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_data <= 0;
            transaction_active <= 0;
            spi_clk_enable <= 0;
            m_axis_tvalid <= 0;
            device_mode <= Conversion;
            reg_available <= 0;
            cs <= 0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 0;
            end
            if (s_axis_tvalid && s_axis_tready) begin
                reg_data <= s_axis_tdata[23:0];
                reg_available <= 1;
                if (device_mode != RegAccess) begin
                    device_mode <= RegAccessOnce;
                end
            end
            if (~transaction_active) begin
                if (cs) begin
                    transaction_active <= 1;
                    spi_clk_enable <= 1;
                end else if (device_mode == Conversion && trigger) begin
                    cs <= 1;
                    m_axis_tvalid <= 0;
                end else if (reg_available) begin
                    cs <= 1;
                    reg_available <= 0;
                end
            end else begin
                if (data_idx == 0) begin
                    transaction_active <= 0;
                    spi_clk_enable <= 0;
                    cs <= 0;
                    if (device_mode == Conversion) begin
                        m_axis_tvalid <= 1;
                    end else begin
                        if (reg_data[23:21] == 3'b101) begin
                            device_mode <= RegAccess;
                        end else if (reg_data == ExitReg || device_mode == RegAccessOnce) begin
                            device_mode <= Conversion;
                        end
                    end
                end else begin
                    if (data_idx - 1 == 0) begin
                        // Clock has to be disabled one cycle in advance as it
                        // is synchronous with aclk.
                        spi_clk_enable <= 0;
                    end
                end
            end
        end
    end
endmodule
