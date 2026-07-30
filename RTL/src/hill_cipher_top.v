
module hill_cipher_top #(
    parameter N = 2, //temporay defalt
    parameter KEY_AND_INNER_DIM = N, // key is N (this) x N
    parameter B_COLS = 2, // plaintext can be N x B_COLS (whatever)

    parameter DW = 6, // input operand width (signed INT6)
    parameter ACC_W = $clog2(KEY_AND_INNER_DIM * 25 * 25 + 1) + 1
) (
    input  wire clk,
    input  wire rst_n,

    input  wire start,
    output wire done,

    input  wire mode, // encrypt (0) or decrypt (1)

    input  wire                   ld_en,  // load enable
    input  wire                   ld_sel, // 0 = plaintext, 1 = key
    input  wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] ld_addr,
    input  wire signed [DW-1:0] ld_data,

    input  wire [$clog2(N * B_COLS)-1:0] rd_addr,
    output wire signed [DW-1:0] rd_data // final output
);


    /*
    The top module takes the key and plaintext (or ciphertext). The 
    inverse is calculated by a separate internal module. 

    (this is a note to myself because I will mess up)
    */

    localparam KEY_SIZE = 2 * N * KEY_AND_INNER_DIM;
    localparam TEXT_SIZE = N * B_COLS;
    localparam OUT_SIZE = N * B_COLS;
    localparam OUT_ADDR_W =
        (OUT_SIZE <= 1) ? 1 : $clog2(OUT_SIZE);

    // ----------------- wires --------------------
    //  controller wires 
    
    wire controller_mode; // stores encode/decode (0/1)
    
    wire matmulBegin;
    wire writeEnable;
    wire busy;

    wire load_done;
    wire mult_done;
    wire write_done;

    wire inverse_begin;
    wire inverse_done;

    wire [OUT_ADDR_W-1:0] inverse_key_rd_addr;
    wire [OUT_ADDR_W-1:0] matmul_key_rd_addr;
    wire [OUT_ADDR_W-1:0] inverse_w_addr;
    wire [DW-1:0] inverse_w_data;

    // memory output wires
    wire signed [DW-1:0]    plaintext_rd_data;
    wire signed [DW-1:0]    key_rd_data;
    wire signed [DW-1:0]    inverse_rd_data;
    

    wire signed [DW-1:0]    final_rd_data;
    
    wire loadEnable; // ???

    wire plaintext_ld_enable;
    wire key_ld_enable;
    wire inverse_ld_enable;
    wire output_ld_enable;

    wire [$clog2(KEY_AND_INNER_DIM * B_COLS)-1:0] plaintext_rd_addr;
    wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0]  key_rd_addr;
    wire [OUT_ADDR_W-1:0] inverse_rd_addr;

    wire [$clog2(N * B_COLS)-1:0] output_ld_addr;
    
    // internal data wires
    wire signed [DW-1:0] output_ld_data;

    assign plaintext_ld_enable = ld_en && (ld_sel == 1'b0);
    assign key_ld_enable = ld_en && (ld_sel == 1'b1);

    assign load_done =  1'b1;
    assign write_done = 1'b1; // write is always done in one cycle based off of the change we mdae in mod26

    
    // ------------------ mux to decide on key / key^-1 --------------
    wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] matmul_A_rd_addr;

    wire [$clog2(2 * N * KEY_AND_INNER_DIM)-1:0] key_selector_rd_addr;   // add this declaration
    assign key_rd_addr = controller_mode ? inverse_key_rd_addr : key_selector_rd_addr;

    wire [DW-1:0] matmul_A_rd_data;

    // key selector routes read and data wires (a.k.a. pain and suffering)
    key_selector #(
        .N(N),
        .KEY_AND_INNER_DIM(KEY_AND_INNER_DIM),
        .DW(DW)
    ) key_select_inst(
        .mode(controller_mode),
        .key_rd_addr(key_selector_rd_addr),
        .inverse_rd_addr(inverse_rd_addr),
        .A_rd_addr(matmul_A_rd_addr),

        .key_rd_data(key_rd_data),
        .inverse_rd_data(inverse_rd_data),
        .A_rd_data(matmul_A_rd_data)
    );

    // ------------------ initializations -----------------------
    
    // controller
    hill_cipher_controller hcc (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .mode_in      (mode),

        .load_done    (load_done),
        .inverse_done(inverse_done),
        .mult_done    (mult_done),
        .write_done   (write_done),

        .loadEnable   (loadEnable),
        .inverseBegin(inverse_begin),
        .matmulBegin  (matmulBegin),
        .writeEnable  (writeEnable),

        .busy         (busy),
        .done         (done),

        .mode         (controller_mode)
    );

    // plaintext memory
    mem #(
        .DW(DW),
        .SIZE(TEXT_SIZE),
        .ADDR_W($clog2(TEXT_SIZE))
    ) plaintext_mem (
        .clk     (clk),

        .ld_en   (plaintext_ld_enable),
        .w_addr (ld_addr[$clog2(KEY_AND_INNER_DIM * B_COLS)-1:0]),
        .w_data (ld_data),

        .r_addr (plaintext_rd_addr),
        .r_data (plaintext_rd_data)
    );

    // key memory
    mem #(
        .DW(DW),
        .SIZE(KEY_SIZE),
        .ADDR_W($clog2(KEY_SIZE))
    ) key_mem (
        .clk     (clk),

        .ld_en   (key_ld_enable),
        .w_addr (ld_addr),
        .w_data (ld_data),

        .r_addr (key_rd_addr),
        .r_data (key_rd_data)
    );

    // inverse key mem
    mem #(
        .DW(DW),
        .SIZE(N * N),
        .ADDR_W(OUT_ADDR_W)
    ) inverse_mem (
        .clk(clk),
        .ld_en (inverse_ld_enable),
        .w_addr(inverse_w_addr),
        .w_data(inverse_w_data),

        .r_addr(inverse_rd_addr),
        .r_data(inverse_rd_data)
    );

   
    // final product + mod26 result memory
    mem #(
        .DW(DW),
        .SIZE(OUT_SIZE),
        .ADDR_W(OUT_ADDR_W)
    ) output_mem (
        .clk    (clk),

        .ld_en  (output_ld_enable),
        .w_addr (output_ld_addr),
        .w_data (output_ld_data),

        .r_addr (rd_addr),
        .r_data (rd_data)
    );

     // modular inverse 
    modular_inverse_top #(
        .N(N),
        .DW(DW),
        .ACC_W(ACC_W)
    ) modular_inverse_inst (
        .clk(clk),
        .rst_n(rst_n),

        .start(inverse_begin),
        .done(inverse_done),

        .in_rd_addr(inverse_key_rd_addr),
        .in_rd_data(key_rd_data),

        .out_w_en(inverse_ld_enable),
        .out_w_addr(inverse_w_addr),
        .out_w_data(inverse_w_data),

        .invalid_key()
    );

    // matrix multiplication
    matmul_mod26_top #(
        .N(N),
        .KEY_AND_INNER_DIM(KEY_AND_INNER_DIM),
        .B_COLS(B_COLS),
        .DW(DW),
        .ACC_W(ACC_W),
        .ADDR_W(OUT_ADDR_W)
    ) matmul_inst (
        .clk   (clk),
        .rst_n (rst_n),
        .mode(controller_mode), //i think matrix selection should happen before this?

        .start (matmulBegin),
        .done  (mult_done),

        .A_rd_addr (matmul_A_rd_addr),
        .A_rd_data (matmul_A_rd_data),

        .B_rd_addr (plaintext_rd_addr),
        .B_rd_data (plaintext_rd_data),

        .product_mem_ld_enable (output_ld_enable),
        .product_mem_ld_addr   (output_ld_addr),
        .product_mem_ld_data   (output_ld_data)
    );


endmodule