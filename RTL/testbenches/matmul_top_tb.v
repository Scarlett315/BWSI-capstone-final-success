`timescale 1ns/1ps

module matmul_top_tb;

parameter N     = 2;
parameter DW    = 8;
parameter ACC_W = 32;

parameter A_AW = $clog2(2 * N * N);
parameter B_AW = $clog2(N * N);
parameter OUT_AW = $clog2(N * N);

//----------------------------------------------------
// Clock / Reset
//----------------------------------------------------

reg clk;
reg rst_n;
reg start;
reg mode;
wire done;

always #5 clk = ~clk;

//----------------------------------------------------
// DUT <-> "memory" interface
//----------------------------------------------------

// addresses requested by matmul
wire [A_AW-1:0] A_rd_addr;
wire [B_AW-1:0] B_rd_addr;

// data returned to matmul
wire signed [DW-1:0] A_rd_data;
wire signed [DW-1:0] B_rd_data;

// write interface produced by matmul
wire                  product_mem_ld_enable;
wire [OUT_AW-1:0]         product_mem_ld_addr;
wire signed [DW-1:0]  product_mem_ld_data;

//----------------------------------------------------
// "Memory" arrays
//----------------------------------------------------

reg signed [DW-1:0] key_mem [0:2*N*N-1];
reg signed [DW-1:0] plaintext_mem [0:N*N-1];
reg signed [DW-1:0] result_mem    [0:N*N-1];

// asynchronous reads
assign A_rd_data = key_mem[A_rd_addr];
assign B_rd_data = plaintext_mem[B_rd_addr];

// synchronous writes
always @(posedge clk) begin
    if(product_mem_ld_enable)
        result_mem[product_mem_ld_addr] <= product_mem_ld_data;
end

//----------------------------------------------------
// DUT
//----------------------------------------------------

matmul_mod26_top #(
    .N(N),
    .DW(DW),
    .ACC_W(ACC_W)
) dut (
    .clk(clk),
    .rst_n(rst_n),

    .mode(mode),

    .start(start),
    .done(done),

    .A_rd_addr(A_rd_addr),
    .A_rd_data(A_rd_data),

    .B_rd_addr(B_rd_addr),
    .B_rd_data(B_rd_data),

    .product_mem_ld_enable(product_mem_ld_enable),
    .product_mem_ld_addr(product_mem_ld_addr),
    .product_mem_ld_data(product_mem_ld_data)
);

//----------------------------------------------------
// Initialize matrices
//----------------------------------------------------

integer i;

initial begin

    //------------------------------------------------
    // Regular key matrix: addresses 0-3
    //------------------------------------------------

    key_mem[0] = 1;
    key_mem[1] = 22;
    key_mem[2] = 18;
    key_mem[3] = 8;

    //------------------------------------------------
    // Inverse-key space: addresses 4-7
    // Not used because mode = 0 in this test
    //------------------------------------------------

    key_mem[4] = 0;
    key_mem[5] = 0;
    key_mem[6] = 0;
    key_mem[7] = 0;

    //------------------------------------------------
    // Plaintext matrix
    //------------------------------------------------

    plaintext_mem[0] = 0;
    plaintext_mem[1] = 18;
    plaintext_mem[2] = 8;
    plaintext_mem[3] = 2;

    //------------------------------------------------
    // Clear result memory
    //------------------------------------------------

    for (i = 0; i < N*N; i = i + 1)
        result_mem[i] = 0;

end

//----------------------------------------------------
// Test
//----------------------------------------------------

integer r,c;

initial begin

    $dumpvars(0,matmul_top_tb);

    clk   = 0;
    rst_n = 0;
    start = 0;
    mode = 0;

    repeat(3) @(posedge clk);

    rst_n = 1;

    @(negedge clk);
    start = 1;

    @(negedge clk);
    start = 0;

    wait(done);

    @(posedge clk);

    $display("\nResult matrix:");

    for(r=0;r<N;r=r+1) begin
        for(c=0;c<N;c=c+1)
            $write("%6d ", result_mem[r*N+c]);
        $write("\n");
    end

    $finish;

end

endmodule