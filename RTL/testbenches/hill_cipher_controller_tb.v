`timescale 1ns/1ps

module tb_hill_cipher_controller;

    reg clk;
    reg rst_n;
    reg start;
    reg mode_in;     

    reg load_done;
    reg mult_done;
    reg write_done;

    wire loadEnable;
    wire matmulBegin;
    wire writeEnable;

    wire busy;
    wire done;
    wire mode;

    integer errors;

    hill_cipher_controller dut (
            .clk          (clk),
            .rst_n        (rst_n),
            .start        (start),

            .mode_in      (mode_in),

            .load_done    (load_done),
            .mult_done    (mult_done),
            .write_done   (write_done),

            .loadEnable   (loadEnable),
            .matmulBegin  (matmulBegin),
            .writeEnable  (writeEnable),

            .busy         (busy),
            .done         (done),
            .mode         (mode)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    task check_signal;
        input actual;
        input expected;
        input [255:0] signal_name;

        begin
            if (actual !== expected) begin
                $display(
                    "FAIL at time %0t: %0s expected %b, got %b",
                    $time,
                    signal_name,
                    expected,
                    actual
                );

                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS at time %0t: %0s = %b",
                    $time,
                    signal_name,
                    actual
                );
            end
        end
    endtask

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        start      = 1'b0;
        mode_in    = 1'b0;

        load_done  = 1'b0;
        mult_done  = 1'b0;
        write_done = 1'b0;

        errors = 0;

        // test reset
        repeat (2) @(posedge clk);
        #1;

        check_signal(busy, 1'b0, "busy after reset");
        check_signal(done, 1'b0, "done after reset");

        rst_n = 1'b1;

        /////////////////////////////
        // test encryption operation
        // mode_in = 0 (encrypt)
        /////////////////////////////

        $display("\n--- Encryption controller test ---");
@(negedge clk);
        mode_in = 1'b0;
        start   = 1'b1;

        @(negedge clk);
        start = 1'b0;

        // Controller should now be in LOAD
        @(posedge clk);
        #1;

        check_signal(busy, 1'b1, "busy in LOAD");
        check_signal(loadEnable, 1'b1, "loadEnable in LOAD");
        check_signal(mode, 1'b0, "saved encryption mode");

        // Finish loading
        @(negedge clk);
        load_done = 1'b1;

        #1;
        check_signal(matmulBegin, 1'b1, "matmulBegin pulse after load_done");

        @(negedge clk);
        load_done = 1'b0;

        // Controller should now be in MULTIPLY
        @(posedge clk);
        #1;

        check_signal(busy, 1'b1, "busy in MULTIPLY");
        check_signal(matmulBegin, 1'b0, "matmulBegin low after start pulse");

        // Finish multiplication
        @(negedge clk);
        mult_done = 1'b1;

        @(negedge clk);
        mult_done = 1'b0;

        // Controller should now be in WRITE
        @(posedge clk);
        #1;

        check_signal(busy, 1'b1, "busy in WRITE");
        check_signal(writeEnable, 1'b1, "writeEnable in WRITE");

        // Finish writing
        @(negedge clk);
        write_done = 1'b1;

        #1;
        check_signal(done, 1'b1, "done when write_done is high");

        @(negedge clk);
        write_done = 1'b0;

        // Controller should return to IDLE
        @(posedge clk);
        #1;

        check_signal(busy, 1'b0, "busy after operation");
        check_signal(done, 1'b0, "done after returning to IDLE");

        /////////////////////////////
        // test decryption operation
        /////////////////////////////
        $display("\n--- Decryption mode test ---");

        @(negedge clk);
        mode_in = 1'b1;
        start   = 1'b1;

        @(negedge clk);
        start = 1'b0;

        @(posedge clk);
        #1;

        check_signal(mode, 1'b1, "saved decryption mode");
        check_signal(loadEnable, 1'b1, "loadEnable for decryption");

        // Complete remaining operation quickly
        @(negedge clk);
        load_done = 1'b1;

        @(negedge clk);
        load_done = 1'b0;

        @(negedge clk);
        mult_done = 1'b1;

        @(negedge clk);
        mult_done = 1'b0;

        @(negedge clk);
        write_done = 1'b1;

        #1;
        check_signal(done, 1'b1, "decryption done");

        @(negedge clk);
        write_done = 1'b0;

        repeat (2) @(posedge clk);

        ////////////////
        // final result
        ////////////////
        
        if (errors == 0)
            $display("\nAll Controller Tests Passesd!");
        else
            $display("\nController Test Failed: %0d error(s)", errors);
        

        $finish;
    end

endmodule