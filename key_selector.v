// routes A_rd_addr from MATMUL to the KEY OR INVERSE KEY
// routes A_rd_data from KEY OR INVERSE KEY to MATMUL!!!!

module key_selector #(
    parameter N = 2,
    parameter KEY_AND_INNER_DIM = N,
    parameter DW = 6 
)(
    input wire mode,

    // broadcast read address 
    output wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] key_rd_addr,
    output wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] inverse_rd_addr,

    input wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] A_rd_addr,

    // data routing
    input wire [DW-1:0] key_rd_data,
    input wire [DW-1:0] inverse_rd_data,
    output wire [DW-1:0] A_rd_data

);
    // broadcast address to both mems
    assign inverse_rd_addr = A_rd_addr;
    assign key_rd_addr = A_rd_addr;

    // select data from the one that is picked
    assign A_rd_data = (mode) ? inverse_rd_data : key_rd_data;

endmodule