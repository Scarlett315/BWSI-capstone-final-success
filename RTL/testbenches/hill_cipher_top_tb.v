`timescale 1ns / 1ps
//=============================================================================
// tb_hill_cipher_top.v
// Runs hill_cipher_top through one full round (load -> [inverse] -> multiply
// -> write) and prints the key, the input (plaintext/ciphertext), the
// computed inverse key (decrypt only), and the final output.
//
// Compile together with hill_cipher_dut.v
//=============================================================================
 
module tb_hill_cipher_top;
 
    localparam N = 2;
    localparam KEY_AND_INNER_DIM = 2;
    localparam B_COLS = 3;
    localparam DW = 6;
    localparam ACC_W = $clog2(KEY_AND_INNER_DIM * 25 * 25 + 1) + 1;
 
    localparam KEY_SIZE  = 2 * N * KEY_AND_INNER_DIM;
    localparam LD_ADDR_W = $clog2(KEY_SIZE);
    localparam RD_ADDR_W = $clog2(N * B_COLS);
 
    // ======================= EDIT THESE VALUES =======================
    localparam MODE = 1'b1; // 0 = encrypt, 1 = decrypt
 
    // Key matrix [[K0,K1],[K2,K3]] -- addresses 0,1,2,3 in key_mem
    localparam signed [DW-1:0] KEY0 = 7, KEY1 = 8, KEY2 = 11, KEY3 = 11;
 
    // Input matrix (plaintext if encrypting, ciphertext if decrypting)
    // [[T0,T1],[T2,T3]] -- addresses 0,1,2,3 in plaintext_mem
    localparam signed [DW-1:0] TXT0 = 7, TXT1 = 8, TXT2 = 2, TXT3 = 11, TXT4 = 0 , TXT5 = 12;
    // ===================================================================
 
    reg clk, rst_n, start, mode;
    reg ld_en, ld_sel;
    reg  [LD_ADDR_W-1:0] ld_addr;
    reg  signed [DW-1:0] ld_data;
    reg  [RD_ADDR_W-1:0] rd_addr;
    wire signed [DW-1:0] rd_data;
    wire done;
 
    hill_cipher_top #(
        .N(N), .KEY_AND_INNER_DIM(KEY_AND_INNER_DIM), .B_COLS(B_COLS),
        .DW(DW), .ACC_W(ACC_W)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .done(done),
        .mode(mode),
        .ld_en(ld_en), .ld_sel(ld_sel), .ld_addr(ld_addr), .ld_data(ld_data),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );
 
    initial clk = 1'b0;
    always #5 clk = ~clk;
 
    //------------------------------------------------------------------
    // Narration: print controller state transitions as they happen
    //------------------------------------------------------------------
    reg [2:0] prev_state = 3'bxxx;
 
    function [63:0] state_name;
        input [2:0] st;
        begin
            case (st)
                3'd1: state_name = "IDLE";
                3'd2: state_name = "LOAD";
                3'd3: state_name = "INVERSE";
                3'd4: state_name = "MULTIPLY";
                3'd5: state_name = "WRITE";
                default: state_name = "?";
            endcase
        end
    endfunction
 
    always @(posedge clk) begin
        if (dut.hcc.currentState !== prev_state) begin
            $display("    ... controller state -> %0s", state_name(dut.hcc.currentState));
            prev_state <= dut.hcc.currentState;
        end
    end
 
    //------------------------------------------------------------------
    // Helpers
    //------------------------------------------------------------------
    task load_word;
        input                sel;
        input [LD_ADDR_W-1:0] addr;
        input signed [DW-1:0] data;
        begin
            @(negedge clk);
            ld_en = 1'b1; ld_sel = sel; ld_addr = addr; ld_data = data;
            @(posedge clk);
            @(negedge clk);
            ld_en = 1'b0;
        end
    endtask
 
    task print_2x2;
        input [127:0]        label;
        input signed [DW-1:0] m0, m1, m2, m3;
        begin
            $display("  %0s", label);
            $display("     [ %3d  %3d ]", m0, m1);
            $display("     [ %3d  %3d ]", m2, m3);
        end
    endtask

    task print_2x3;
        input [127:0]        label;
        input signed [DW-1:0] m0, m1, m2, m3, m4, m5;
        begin
            $display("  %0s", label);
            $display("     [ %3d  %3d %3d]", m0, m1, m2);
            $display("     [ %3d  %3d %3d]", m3, m4, m5);
        end
    endtask
 
    reg signed [DW-1:0] out0, out1, out2, out3, out4, out5;
    reg signed [DW-1:0] inv0, inv1, inv2, inv3, inv4, inv5;
 
    //------------------------------------------------------------------
    // Stimulus
    //------------------------------------------------------------------
    initial begin
        $dumpvars(0, dut);
        rst_n = 1'b0; start = 1'b0; mode = MODE;
        ld_en = 1'b0; ld_sel = 1'b0; ld_addr = 0; ld_data = 0; rd_addr = 0;
 
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
 
        $display("");
        $display("============================================================");
        $display(" Hill Cipher -- one round, mode = %0s", MODE ? "DECRYPT" : "ENCRYPT");
        $display("============================================================");
        print_2x2("Key Matrix", KEY0, KEY1, KEY2, KEY3);
        print_2x3(MODE ? "Ciphertext (input)" : "Plaintext (input)", TXT0, TXT1, TXT2, TXT3, TXT4, TXT5);
        $display("------------------------------------------------------------");
 
        // load key (ld_sel = 1)
        load_word(1'b1, 0, KEY0);
        load_word(1'b1, 1, KEY1);
        load_word(1'b1, 2, KEY2);
        load_word(1'b1, 3, KEY3);
     
 
        // load input text (ld_sel = 0)
        load_word(1'b0, 0, TXT0);
        load_word(1'b0, 1, TXT1);
        load_word(1'b0, 2, TXT2);
        load_word(1'b0, 3, TXT3);
        load_word(1'b0, 4, TXT4);
        load_word(1'b0, 5, TXT5);
 
        $display("  Starting...");
        start = 1'b1;
        @(posedge clk);
        @(negedge clk);
        start = 1'b0;
 
        while (!done) @(posedge clk);
        @(negedge clk);
 
        if (MODE) begin
            inv0 = dut.inverse_mem.storage_array[0];
            inv1 = dut.inverse_mem.storage_array[1];
            inv2 = dut.inverse_mem.storage_array[2];
            inv3 = dut.inverse_mem.storage_array[3];
           
            $display("------------------------------------------------------------");
            print_2x2("Computed Modular Inverse Key", inv0, inv1, inv2, inv3);
        end
 
        rd_addr = 0; #1; out0 = rd_data;
        rd_addr = 1; #1; out1 = rd_data;
        rd_addr = 2; #1; out2 = rd_data;
        rd_addr = 3; #1; out3 = rd_data;
        rd_addr = 4; #1; out4 = rd_data;
        rd_addr = 5; #1; out5 = rd_data;

 
        $display("------------------------------------------------------------");
        print_2x3(MODE ? "Recovered Plaintext (output)" : "Ciphertext (output)", out0, out1, out2, out3, out4, out5);
        $display("============================================================");
        $display("");
 
        $finish;
    end
 
endmodule