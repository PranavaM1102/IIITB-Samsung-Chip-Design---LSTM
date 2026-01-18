`timescale 1ns/1ps

module tb_E4M4_to_Q6_11_exhaustive;

    // DUT I/O
    reg  [8:0] fp;
    wire signed [17:0] q_dut;

    // Instantiate DUT
    E4M4_9b_to_Q6_11 dut (
        .fp(fp),
        .q(q_dut)
    );

    // Testbench variables
    integer i;
    integer csv;
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    real fp_real;
    real q_real;
    integer q_ref;

    reg sign;
    integer exp;
    integer mant;

    initial begin
        csv = $fopen("E4M4_to_Q6_11_exhaustive.csv", "w");
        if (csv == 0) begin
            $display("ERROR: Could not open CSV file");
            $finish;
        end

        // CSV header
        $fwrite(csv,
            "fp_hex,sign,exp,mant,fp_real,q_dut,q_ref,result\n"
        );

        // Exhaustive sweep
        for (i = 0; i < 512; i = i + 1) begin
            fp = i[8:0];
            #1;

            sign = fp[8];
            exp  = fp[7:4];
            mant = fp[3:0];

            // -------------------------
            // Golden FP real value
            // -------------------------
            if (exp == 0) begin
                fp_real = 0.0;
            end else begin
                fp_real = (sign ? -1.0 : 1.0)
                        * (2.0 ** (exp - 8))
                        * (1.0 + mant / 16.0);
            end

            // -------------------------
            // Golden Q6.11
            // -------------------------
            q_real = fp_real * 2048.0;

            // round-to-nearest
            if (q_real >= 0)
                q_ref = $rtoi(q_real + 0.5);
            else
                q_ref = $rtoi(q_real - 0.5);

            // -------------------------
            // Compare
            // -------------------------
            if (q_dut === q_ref[17:0]) begin
                pass_cnt++;
                $fwrite(csv,
                    "%03h,%0d,%0d,%0d,%f,%0d,%0d,PASS\n",
                    fp, sign, exp, mant, fp_real,
                    q_dut, q_ref
                );
            end else begin
                fail_cnt++;
                $fwrite(csv,
                    "%03h,%0d,%0d,%0d,%f,%0d,%0d,FAIL\n",
                    fp, sign, exp, mant, fp_real,
                    q_dut, q_ref
                );
            end
        end

        $fclose(csv);

        // -------------------------
        // Summary
        // -------------------------
        $display("======================================");
        $display(" E4M4 -> Q6.11 Exhaustive Verification ");
        $display("======================================");
        $display("Total cases : 512");
        $display("PASS        : %0d", pass_cnt);
        $display("FAIL        : %0d", fail_cnt);
        $display("======================================");

        if (fail_cnt == 0)
            $display("OVERALL RESULT: PASS");
        else
            $display("OVERALL RESULT: FAIL");

        $finish;
    end

endmodule
