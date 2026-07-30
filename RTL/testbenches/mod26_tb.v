`timescale 1ns/1ps

module mod26_tb;

    parameter ACC_W = 12;
    parameter DW    = 6;

    reg  [ACC_W-1:0] in;
    wire [DW-1:0]    out;

    mod26 #(
        .ACC_W(ACC_W),
        .DW(DW)
    ) dut (
        .in        (in),
        .remainder (out)
    );

    initial begin
        $dumpvars(0, mod26_tb);

        in = 12'd0;
        #1;
        if (out == 0)
            $display("PASS: 0 mod 26 = %0d", out);
        else
            $display("FAIL: 0 mod 26 expected 0, got %0d", out);

        in = 12'd2047;
        #1;
        if (out == 19)
            $display("PASS: 2047 mod 26 = %0d", out);
        else
            $display("FAIL: 2047 mod 26 expected 19, got %0d", out);

        in = 12'd1024;
        #1;
        if (out == 10)
            $display("PASS: 1024 mod 26 = %0d", out);
        else
            $display("FAIL: 1024 mod 26 expected 10, got %0d", out);

        in = 12'd519;
        #1;
        if (out == 25)
            $display("PASS: 519 mod 26 = %0d", out);
        else
            $display("FAIL: 519 mod 26 expected 25, got %0d", out);

        in = 12'd21;
        #1;
        if (out == 21)
            $display("PASS: 21 mod 26 = %0d", out);
        else
            $display("FAIL: 21 mod 26 expected 21, got %0d", out);

        $display("Mod26 testbench finished");
        $finish;
    end

endmodule