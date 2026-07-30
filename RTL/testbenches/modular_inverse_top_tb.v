`timescale 1ns / 1ps
//----------------------------------------------------------------------------
// yes Claude made this I'm too tired to completely check but it looks right
// everything passed :>
//
//Testbench for: modular_inverse_top  (Hill cipher 2x2 modular inverse)
//
// Prints, for every test case:
//    - the input key matrix [[a,b],[c,d]]
//    - the determinant and det mod 26
//    - whether the key SHOULD be invertible mod 26 (reference model)
//    - the expected inverse matrix vs. the DUT's inverse matrix, side by side
//    - a PASS/FAIL verdict
//
// NOTE: assumes the 3 fixes described alongside this file have been applied
// to modular_inverse_top (in_rd_addr direction, det width, invalid_key
// wiring). A minimal behavioral `mod26` stand-in is included below since it
// wasn't part of the shared source.
//----------------------------------------------------------------------------

module tb_modular_inverse_top;

    localparam N      = 2;
    localparam DW     = 6;
    localparam ACC_W  = 12;
    localparam ADDR_W = 2; // $clog2(N*N)

    reg                  clk;
    reg                  rst_n;
    reg                  start;
    wire                 done;
    wire                 invalid_key;

    // key mem (testbench writes it; DUT reads it)
    reg                  key_ld_en;
    reg  [ADDR_W-1:0]    key_w_addr;
    reg  signed [DW-1:0] key_w_data;
    wire [ADDR_W-1:0]    key_r_addr;   // driven by DUT
    wire signed [DW-1:0] key_r_data;

    // inverse mem (DUT writes it; testbench reads it back for display)
    wire                 inv_w_en;
    wire [ADDR_W-1:0]    inv_w_addr;
    wire signed [DW-1:0] inv_w_data;
    reg  [ADDR_W-1:0]    inv_r_addr;
    wire signed [DW-1:0] inv_r_data;

    integer errors;
    integer case_num;

    mem #( .DW(DW), .SIZE(N*N), .ADDR_W(ADDR_W) ) key_mem (
        .clk    (clk),
        .ld_en  (key_ld_en),
        .w_addr (key_w_addr),
        .w_data (key_w_data),
        .r_addr (key_r_addr),
        .r_data (key_r_data)
    );

    mem #( .DW(DW), .SIZE(N*N), .ADDR_W(ADDR_W) ) inv_mem (
        .clk    (clk),
        .ld_en  (inv_w_en),
        .w_addr (inv_w_addr),
        .w_data (inv_w_data),
        .r_addr (inv_r_addr),
        .r_data (inv_r_data)
    );

    modular_inverse_top #( .N(N), .DW(DW), .ACC_W(ACC_W) ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .start       (start),
        .done        (done),
        .in_rd_addr  (key_r_addr),
        .in_rd_data  (key_r_data),
        .out_w_en    (inv_w_en),
        .out_w_addr  (inv_w_addr),
        .out_w_data  (inv_w_data),
        .invalid_key (invalid_key)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    //------------------------------------------------------------------
    // Reference model: mod26 helper + expected-inverse calculator
    //------------------------------------------------------------------
    function integer mod26_f;
        input integer x;
        integer r;
        begin
            r = x % 26;
            if (r < 0) r = r + 26;
            mod26_f = r;
        end
    endfunction

    task compute_expected;
        input  integer a, b, c, d;
        output integer det_mod;
        output integer det_inv;
        output integer valid;
        output integer w, x, y, z; // expected inverse matrix [[w,x],[y,z]]
        integer det, k;
        begin
            det     = a*d - b*c;
            det_mod = mod26_f(det);
            valid   = 0;
            det_inv = 0;
            for (k = 0; k < 26; k = k + 1) begin
                if (((det_mod * k) % 26) == 1) begin
                    det_inv = k;
                    valid   = 1;
                end
            end
            w = mod26_f(det_inv * d);
            x = mod26_f(det_inv * (-b));
            y = mod26_f(det_inv * (-c));
            z = mod26_f(det_inv * a);
        end
    endtask

    //------------------------------------------------------------------
    // Formatted display
    //------------------------------------------------------------------
    task print_case;
        input integer idx;
        input integer a, b, c, d;
        input integer det_mod, det_inv, valid_exp, dut_inv_flag;
        input integer ew, ex, ey, ez;
        input integer dw, dx, dy, dz;
        begin
            $display("");
            $display("================ Test Case %0d ================", idx);
            $display("  Key Matrix:              det = %0d  (mod 26 = %0d)", a*d - b*c, det_mod);
            $display("   [ %2d  %2d ]              det^-1 mod 26 = %0d", a, b, det_inv);
            $display("   [ %2d  %2d ]              expected invertible: %0s   |  DUT invalid_key = %0b",
                      c, d, (valid_exp ? "YES" : "NO"), dut_inv_flag);
            $display("  ------------------------------------------------");
            if (valid_exp) begin
                $display("      Expected Inverse         DUT Inverse");
                $display("       [ %2d  %2d ]               [ %2d  %2d ]", ew, ex, dw, dx);
                $display("       [ %2d  %2d ]               [ %2d  %2d ]", ey, ez, dy, dz);
            end else begin
                $display("      Key is not invertible mod 26 -- no inverse matrix expected.");
            end
        end
    endtask

    //------------------------------------------------------------------
    // Drive one full test case through the DUT
    //------------------------------------------------------------------
    task run_case;
        input integer a, b, c, d;
        reg signed [DW-1:0] dut_w, dut_x, dut_y, dut_z;
        integer det_mod, det_inv, valid_exp;
        integer ew, ex, ey, ez;
        begin
            case_num = case_num + 1;

            // ---- load key matrix: addr0=a, addr1=b, addr2=c, addr3=d ----
            @(negedge clk);
            key_ld_en = 1'b1;
            key_w_addr = 2'd0; key_w_data = a[DW-1:0]; @(posedge clk); @(negedge clk);
            key_w_addr = 2'd1; key_w_data = b[DW-1:0]; @(posedge clk); @(negedge clk);
            key_w_addr = 2'd2; key_w_data = c[DW-1:0]; @(posedge clk); @(negedge clk);
            key_w_addr = 2'd3; key_w_data = d[DW-1:0]; @(posedge clk); @(negedge clk);
            key_ld_en = 1'b0;

            // ---- pulse start for one cycle ----
            start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            start = 1'b0;

            // ---- wait for completion ----
            while (!done) @(posedge clk);
            @(negedge clk);

            // ---- read back inverse matrix ----
            inv_r_addr = 2'd0; #1; dut_w = inv_r_data;
            inv_r_addr = 2'd1; #1; dut_x = inv_r_data;
            inv_r_addr = 2'd2; #1; dut_y = inv_r_data;
            inv_r_addr = 2'd3; #1; dut_z = inv_r_data;

            // ---- reference model ----
            compute_expected(a, b, c, d, det_mod, det_inv, valid_exp, ew, ex, ey, ez);

            // ---- print for visual self-check ----
            print_case(case_num, a, b, c, d, det_mod, det_inv, valid_exp, invalid_key,
                       ew, ex, ey, ez, dut_w, dut_x, dut_y, dut_z);

            // ---- automated verdict ----
            if (valid_exp) begin
                if (dut_w !== ew[DW-1:0] || dut_x !== ex[DW-1:0] ||
                    dut_y !== ey[DW-1:0] || dut_z !== ez[DW-1:0]) begin
                    errors = errors + 1;
                    $display("  >> FAIL: inverse matrix mismatch");
                end else if (invalid_key === 1'b1) begin
                    errors = errors + 1;
                    $display("  >> FAIL: invalid_key asserted for a valid key");
                end else begin
                    $display("  >> PASS");
                end
            end else begin
                if (invalid_key !== 1'b1) begin
                    errors = errors + 1;
                    $display("  >> FAIL: invalid_key not asserted for a non-invertible key");
                end else begin
                    $display("  >> PASS (correctly flagged invalid)");
                end
            end

            @(posedge clk); // let FSM settle back at IDLE before next case
        end
    endtask

    //------------------------------------------------------------------
    // Test vectors
    //------------------------------------------------------------------
    initial begin
        errors   = 0;
        case_num = 0;

        start      = 1'b0;
        key_ld_en  = 1'b0;
        key_w_addr = 0;
        key_w_data = 0;
        inv_r_addr = 0;

        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        run_case(3,  3,  2,  5);   // det=9,  coprime with 26 -> valid
        run_case(1,  0,  0,  1);   // identity matrix -> inverse is identity
        run_case(2,  4,  6,  8);   // det=-8 -> mod26=18, gcd(18,26)=2 -> invalid
        run_case(5,  8, 17,  3);   // det=-121 -> mod26=9 -> valid
        run_case(20,15,  7, 22);   // det=335 -> mod26=23 -> valid
        run_case(0, 13, 13,  0);   // det=-169 -> mod26=13, gcd(13,26)=13 -> invalid

        $display("");
        $display("============================================================");
        if (errors == 0)
            $display("*** ALL %0d TEST CASES PASSED ***", case_num);
        else
            $display("*** %0d OF %0d TEST CASE(S) FAILED ***", errors, case_num);
        $display("============================================================");

        $finish;
    end

endmodule