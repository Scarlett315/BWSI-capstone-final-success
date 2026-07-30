/*
mod 2 (mem)
*/
module mem #(
    parameter DW = 8,
    parameter SIZE = 64,
    parameter ADDR_W = 6
)(
    input wire clk,
    input wire ld_en,
    input wire [ADDR_W-1:0] w_addr,
    input wire signed [DW-1:0] w_data,

    input wire [ADDR_W-1:0] r_addr,
    output wire signed [DW-1:0] r_data
);

    reg signed [DW-1:0] storage_array [0:SIZE-1];

    always @(posedge clk) begin
        if (ld_en) begin
            storage_array[w_addr] <= w_data;
        end
    end

    assign r_data = storage_array[r_addr];

endmodule

/*
module mem_unit #(
    parameter DW    = 8, 
    parameter DEPTH = 64, // Changed name from SIZE to DEPTH
    parameter ADDR_W = $clog2(DEPTH)
)(
    input wire clk, 
    input wire permss, 
    input wire [ADDR_W-1:0] w_addr, 
    input wire signed [DW-1:0] w_data, 

    input wire [ADDR_W-1:0] r_addr, 
    output wire signed [DW-1:0] r_data 
);  
    reg signed [DW - 1:0] storage_array [0:DEPTH - 1]; 

    always @(posedge clk) begin
        if (permss == 1'b1) begin
            storage_array[w_addr] <= w_data; 
        end 
    end
    assign r_data = storage_array[r_addr];
endmodule
*/