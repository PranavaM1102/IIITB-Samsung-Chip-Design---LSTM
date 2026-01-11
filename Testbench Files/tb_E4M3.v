`timescale 1ns/1ps

module tb_lfp_ae_fp64_e4m3;

    logic [7:0] a_q, b_q;
    logic [8:0] y;

    lfp_mult_e4m3_fig3 dut (
        .x1(a_q),
        .x2(b_q),
        .y (y)
    );

    integer i;
    integer N = 1_000_000;

    real x1_64, x2_64;
    real true_mul, lfp_mul, ae;
    real min_ae, max_ae;

    real min_x1, min_x2, min_true, min_lfp;
    real max_x1, max_x2, max_true, max_lfp;
    logic [7:0] min_aq, min_bq, max_aq, max_bq;

    // FP64 → E4M3 (safe truncation)
    function logic [7:0] fp64_to_e4m3(input real x);
        int E;
        real frac;
        int Mi;
        logic [2:0] M;
        begin
            if (x <= 0.0) begin
                fp64_to_e4m3 = 8'b0;
            end
            else begin
                // [1,2) → exponent = 8
                E = 8;
                frac = x - 1.0;

                Mi = $floor(frac * 8.0);
                if (Mi < 0) Mi = 0;
                if (Mi > 7) Mi = 7;

                M = Mi[2:0];
                fp64_to_e4m3 = {1'b0, E[3:0], M};
            end
        end
    endfunction

    // E5M3 → real
    function real e5m3_to_real(input logic [8:0] x);
        int E;
        real M;
        begin
            if (x[7:3] == 0)
                e5m3_to_real = 0.0;
            else begin
                E = x[7:3];
                M = x[2:0] / 8.0;
                e5m3_to_real =
                    ((x[8]) ? -1.0 : 1.0) *
                    (2.0 ** (E - 16)) *
                    (1.0 + M);
            end
        end
    endfunction

    initial begin
        min_ae =  1e9;
        max_ae = -1e9;

        for (i = 0; i < N; i++) begin
            x1_64 = 1.0 + ($urandom() / 4294967296.0);
            x2_64 = 1.0 + ($urandom() / 4294967296.0);

            true_mul = x1_64 * x2_64;

            a_q = fp64_to_e4m3(x1_64);
            b_q = fp64_to_e4m3(x2_64);
            #1;

            lfp_mul = e5m3_to_real(y);
            ae = lfp_mul - true_mul;

            if (ae < min_ae) begin
                min_ae = ae;
                min_x1 = x1_64; min_x2 = x2_64;
                min_true = true_mul; min_lfp = lfp_mul;
                min_aq = a_q; min_bq = b_q;
            end

            if (ae > max_ae) begin
                max_ae = ae;
                max_x1 = x1_64; max_x2 = x2_64;
                max_true = true_mul; max_lfp = lfp_mul;
                max_aq = a_q; max_bq = b_q;
            end
        end

        $display("==============================================");
        $display("E4M3 LFP MULTIPLIER AE STUDY");
        $display("Samples   : %0d", N);
        $display("Range(AE) : %e ~ %e", min_ae, max_ae);

        $display("\n--- MIN AE ---");
        $display("AE=%e  x1=%e x2=%e  a_q=%b b_q=%b",
                  min_ae, min_x1, min_x2, min_aq, min_bq);

        $display("\n--- MAX AE ---");
        $display("AE=%e  x1=%e x2=%e  a_q=%b b_q=%b",
                  max_ae, max_x1, max_x2, max_aq, max_bq);

        $display("==============================================");
        $finish;
    end

endmodule
