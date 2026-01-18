`timescale 1ns/1ps

module tb_lfp_mac_top_q6_11;

    // -----------------------------------------
    // DUT I/O
    // -----------------------------------------
    reg  signed [17:0] in0_q;
    reg  signed [17:0] in1_q;
    wire signed [17:0] out_q;

    // -----------------------------------------
    // Instantiate DUT
    // -----------------------------------------
    lfp_mac_top_q6_11 dut (
        .in0_q (in0_q),
        .in1_q (in1_q),
        .out_q (out_q)
    );

    // -----------------------------------------
    // TB variables
    // -----------------------------------------
    integer i;
    integer csv;
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    real in0_r, in1_r;
    real out_ref_r, out_dut_r;
    real abs_err;

    integer out_ref_q;

    // Q6.11 LSB tolerance
    real TOL = 1.0 / 2048.0;

    // Q6.11 limits for ±8
    localparam signed [17:0] QMIN = -18'sd16384;
    localparam signed [17:0] QMAX =  18'sd16384;

    // -----------------------------------------
    // Helper: Q6.11 → real
    // -----------------------------------------
    function real q6_11_to_real(input signed [17:0] q);
        q6_11_to_real = q / 2048.0;
    endfunction

    // -----------------------------------------
    // Main test
    // -----------------------------------------
    initial begin
        csv = $fopen("lfp_mac_q6_11_-8_to_8.csv", "w");
        if (csv == 0) begin
            $display("ERROR: could not open CSV");
            $finish;
        end

        $fwrite(csv,
            "in0_q,in1_q,in0_real,in1_real,out_dut,out_ref,abs_err,result\n"
        );

        // --------------------------------------------------
        // Directed tests (edges & sanity)
        // --------------------------------------------------
        run_test( 18'sd0,       18'sd0        );
        run_test( QMAX,         18'sd0        );  // +8 + 0
        run_test(-QMAX,         18'sd0        );  // -8 + 0
        run_test( QMAX,        -QMAX          );  // +8 - 8
        run_test( 18'sd2048,    18'sd2048     );  // 1 + 1
        run_test(-18'sd4096,    18'sd1024     );  // -2 + 0.5

        // --------------------------------------------------
        // Random tests (clipped to ±8)
        // --------------------------------------------------
        for (i = 0; i < 5000; i = i + 1) begin
            in0_q = QMIN + ($random % (QMAX - QMIN + 1));
            in1_q = QMIN + ($random % (QMAX - QMIN + 1));
            #1;
            check();
        end

        // --------------------------------------------------
        // Summary
        // --------------------------------------------------
        $display("======================================");
        $display(" LFP MAC Q6.11 Verification (-8 to +8)");
        $display("======================================");
        $display("PASS : %0d", pass_cnt);
        $display("FAIL : %0d", fail_cnt);
        $display("======================================");

        if (fail_cnt == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $fclose(csv);
        $finish;
    end

    // -----------------------------------------
    // Task: run single directed test
    // -----------------------------------------
    task run_test(
        input signed [17:0] a,
        input signed [17:0] b
    );
    begin
        in0_q = a;
        in1_q = b;
        #1;
        check();
    end
    endtask

    // -----------------------------------------
    // Task: check result
    // -----------------------------------------
    task check;
    begin
        in0_r = q6_11_to_real(in0_q);
        in1_r = q6_11_to_real(in1_q);

        // ideal real reference
        out_ref_r = in0_r + in1_r;
        out_ref_q = $rtoi(out_ref_r * 2048.0);

        out_dut_r = q6_11_to_real(out_q);
        abs_err   = (out_dut_r > out_ref_r) ?
                     (out_dut_r - out_ref_r) :
                     (out_ref_r - out_dut_r);

        if (abs_err <= TOL) begin
            pass_cnt++;
            $fwrite(csv,
                "%0d,%0d,%f,%f,%f,%f,%f,PASS\n",
                in0_q, in1_q,
                in0_r, in1_r,
                out_dut_r, out_ref_r,
                abs_err
            );
        end else begin
            fail_cnt++;
            $fwrite(csv,
                "%0d,%0d,%f,%f,%f,%f,%f,FAIL\n",
                in0_q, in1_q,
                in0_r, in1_r,
                out_dut_r, out_ref_r,
                abs_err
            );
        end
    end
    endtask

endmodule
