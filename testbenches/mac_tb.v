`timescale 1ns/1ps

module tb_mac;
    parameter DW = 5;
    parameter ACC_W = 12;

    reg clk;
    reg rst_n;

    reg signed [DW-1:0] a;
    reg signed [DW-1:0] b;
    reg valid_in;
    reg clear_acc;

    wire signed [ACC_W-1:0] acc_out;
    wire valid_out;

    mac #(
        .DW(DW),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .valid_in(valid_in),
        .clear_acc(clear_acc),
        .acc_out(acc_out),
        .valid_out(valid_out)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        a = 0;
        b = 0;
        valid_in = 0;
        clear_acc = 0;

        // Reset
        #12;
        rst_n = 1;

        // Test 1: clear accumulator and calculate 4 * 5 = 20
        @(negedge clk);
        a = 4;
        b = 5;
        valid_in = 1;
        clear_acc = 1;

        @(negedge clk);
        valid_in = 0;
        clear_acc = 0;

        // Wait for pipeline output
        wait(valid_out == 1);
        #1;

        if (acc_out == 20 && valid_out == 1)
            $display("Test 1 Passed: acc_out = %0d", acc_out);
        else
            $display("Test 1 Failed: acc_out = %0d, valid_out = %b",
                     acc_out, valid_out);

        // Test 2: accumulate 3 * 4 = 12
        // Expected result: 20 + 12 = 32
        @(negedge clk);
        a = 3;
        b = 4;
        valid_in = 1;
        clear_acc = 0;

        @(negedge clk);
        valid_in = 0;

        wait(valid_out == 1);
        #1;

        if (acc_out == 32 && valid_out == 1)
            $display("Test 2 Passed: acc_out = %0d", acc_out);
        else
            $display("Test 2 Failed: acc_out = %0d, valid_out = %b",
                     acc_out, valid_out);

        // Test 3: signed multiplication -2 * 5 = -10
        // Clear first, so expected result is -10
        @(negedge clk);
        a = -2;
        b = 5;
        valid_in = 1;
        clear_acc = 1;

        @(negedge clk);
        valid_in = 0;
        clear_acc = 0;

        wait(valid_out == 1);
        #1;

        if (acc_out == -10 && valid_out == 1)
            $display("Test 3 Passed: acc_out = %0d", acc_out);
        else
            $display("Test 3 Failed: acc_out = %0d, valid_out = %b",
                     acc_out, valid_out);
        

        // Test 4: bubble cycle
        @(negedge clk);
        a = 7;
        b = 2;
        valid_in = 0;
        clear_acc = 0;

        repeat (2) @(negedge clk);

        if (valid_out == 0)
            $display("Test 4 Passed: bubble produced no valid output");
        else
            $display("Test 4 Failed: valid_out should be 0");

        #20;
        $finish;
    end

    initial begin
        $monitor(
            "time=%0t rst_n=%b valid_in=%b clear_acc=%b a=%0d b=%0d valid_out=%b acc_out=%0d",
            $time, rst_n, valid_in, clear_acc,
            a, b, valid_out, acc_out
        );
    end

endmodule