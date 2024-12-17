task automatic write_register;
    input [31:0] s_axi_lite_wdata;
    input [3:0] s_axi_lite_wstrb;
    inout [31:0] data;
    integer byte_index;
    begin
        for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1) begin
            if (s_axi_lite_wstrb[byte_index] == 1) begin
                data[8*byte_index+:8] <= s_axi_lite_wdata[8*byte_index+:8];
            end
        end
    end
endtask
