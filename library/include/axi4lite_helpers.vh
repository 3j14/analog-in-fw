typedef enum logic {
    WADDR,
    WDATA
} axi4lite_write_state_t;

typedef enum logic {
    RADDR,
    RDATA
} axi4lite_read_state_t;

function automatic [31:0] write_register;
    input reg [31:0] s_axi_lite_wdata;
    input reg [3:0] s_axi_lite_wstrb;
    input reg [31:0] data;
    integer byte_index;
    begin
        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
            if (s_axi_lite_wstrb[byte_index] == 1) begin
                write_register[8*byte_index+:8] = s_axi_lite_wdata[8*byte_index+:8];
            end else begin
                write_register[8*byte_index+:8] = data[8*byte_index+:8];
            end
        end
    end
endfunction
