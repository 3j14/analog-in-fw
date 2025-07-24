`timescale 1ns / 1ps

module adc_model #(
    parameter integer CNV_TIME = 282
) (
    input  wire  cnv,
    output logic busy = 0,

    input wire sck,
    input wire csn,
    input wire resetn,

    input wire sdi,
    output logic [3:0] sdo = 0,

    input  wire  [31:0] test_pattern,
    output logic [23:0] reg_cmd
);
    typedef enum logic {
        REG_ACCESS,
        CNV
    } device_mode_t;
    device_mode_t device_mode = CNV;

    localparam logic [1:0] LaneModeOne = 2'b00;
    localparam logic [1:0] LaneModeTwo = 2'b01;
    localparam logic [1:0] LaneModeFour = 2'b10;
    logic [1:0] lane_md = LaneModeOne;

    logic data_ready = 0;

    localparam logic [14:0] ExitReg = 15'h0014;
    localparam logic [14:0] ModeReg = 15'h0020;

    logic [5:0] data_idx = 0;

    always_ff @(posedge sck or negedge resetn or negedge csn) begin
        if (!resetn || (!csn && !sck)) begin
            reg_cmd <= 0;
        end else begin
            // Shift SDI into reg_cmd on each clock cycle
            reg_cmd <= {reg_cmd[22:0], sdi};
        end
    end

    // Check the register command at the end of a transaction.
    // Check if the register access command was received (msb == 3'b101)
    // and enable RegAccess mode.
    // If already in RegAccess mode, write registers or exit if exit
    // command received.
    always_ff @(posedge csn or negedge resetn) begin
        if (!resetn) begin
            device_mode <= CNV;
            lane_md <= LaneModeOne;
        end else begin
            if (reg_cmd[23:21] == 3'b101) begin
                device_mode <= REG_ACCESS;
            end else if (device_mode == REG_ACCESS) begin
                if (reg_cmd[23:8] == {1'b0, ModeReg}) begin
                    lane_md <= reg_cmd[7:6];
                end else if (reg_cmd[23:8] == {1'b0, ExitReg}) begin
                    if (reg_cmd[0]) begin
                        device_mode <= CNV;
                    end
                end
            end
        end
    end

    always_ff @(posedge sck or negedge csn or posedge cnv or negedge resetn) begin
        if (!resetn) begin
            data_ready <= 0;
            data_idx <= 0;
            busy <= 0;
            sdo <= 0;
        end else if (cnv) begin
            busy <= 1;
            data_ready <= #(CNV_TIME) 1;
            busy <= #(CNV_TIME) 0;
            data_idx <= 32;
        end else if (device_mode == CNV && !csn && data_ready) begin
            if (data_idx == 0) begin
                data_ready <= 0;
            end else begin
                case (lane_md)
                    LaneModeFour: begin
                        sdo[3:0] <= #(8.1) {<<{test_pattern[data_idx-4+:4]}};
                        data_idx <= data_idx - 4;
                    end
                    LaneModeTwo: begin
                        sdo[1:0] <= #(8.1) {<<{test_pattern[data_idx-2+:2]}};
                        data_idx <= data_idx - 2;
                    end
                    default: begin
                        sdo[0]   <= #(8.1) test_pattern[data_idx-1];
                        data_idx <= data_idx - 1;
                    end
                endcase
            end
        end
    end
endmodule


