`timescale 1ns/1ps

module tb_mem;

    parameter DW     = 8;
    parameter SIZE   = 64;
    parameter ADDR_W = 6;

    reg clk;
    reg ld_en;

    reg signed [ADDR_W-1:0] w_addr;
    reg signed [DW-1:0]     w_data;

    reg signed [ADDR_W-1:0] r_addr;
    wire signed [DW-1:0]    r_data;

    mem #(
        .DW(DW),
        .SIZE(SIZE),
        .ADDR_W(ADDR_W)
    ) dut (
        .clk    (clk),
        .ld_en  (ld_en),
        .w_addr (w_addr),
        .w_data (w_data),
        .r_addr (r_addr),
        .r_data (r_data)
    );

    // Clock with a 10 ns period
    always #5 clk = ~clk;

    initial begin
        clk    = 0;
        ld_en  = 0;
        w_addr = 0;
        w_data = 0;
        r_addr = 0;

        $display("Starting memory testbench");

        // Test 1: Write 10 to address 3
        ld_en  = 1;
        w_addr = 6'd3;
        w_data = 8'sd10;

        @(posedge clk);
        #1;

        ld_en  = 0;
        r_addr = 6'd3;
        #1;

        if (r_data == 8'sd10)
            $display("PASS: Address 3 contains 10");
        else
            $display("FAIL: Address 3 expected 10, got %0d", r_data);

        // Test 2: Write -5 to address 7
        ld_en  = 1;
        w_addr = 6'd7;
        w_data = -8'sd5;

        @(posedge clk);
        #1;

        ld_en  = 0;
        r_addr = 6'd7;
        #1;

        if (r_data == -8'sd5)
            $display("PASS: Address 7 contains -5");
        else
            $display("FAIL: Address 7 expected -5, got %0d", r_data);

        // Test 3: Confirm ld_en = 0 prevents writing
        ld_en  = 0;
        w_addr = 6'd3;
        w_data = 8'sd25;

        @(posedge clk);
        #1;

        r_addr = 6'd3;
        #1;

        if (r_data == 8'sd10)
            $display("PASS: Write ignored when ld_en was 0");
        else
            $display("FAIL: Address 3 changed to %0d", r_data);

        // Test 4: Confirm address 7 still contains -5
        r_addr = 6'd7;
        #1;

        if (r_data == -8'sd5)
            $display("PASS: Address 7 still contains -5");
        else
            $display("FAIL: Address 7 expected -5, got %0d", r_data);

        $display("Memory testbench finished");
        $finish;
    end

endmodule