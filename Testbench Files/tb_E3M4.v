`timescale 1ns/1ps

module tb_lfp_ae_fp64_full;

    // ---------------- DUT IO ----------------
    logic [7:0] a_q, b_q;
    logic [8:0] y;

    lfp_mult_e3m4_fig3 dut (
        .x1(a_q),
        .x2(b_q),
        .y (y)
    );

    // ---------------- Simulation control ----------------
    integer i;
    integer N = 10_000_000;   // set to 10_000_000 for paper-scale run

    // ---------------- Real values ----------------
    real x1_64, x2_64;
    real true_mul;
    real lfp_mul;
    real ae;

    real min_ae, max_ae;

    // Store extreme cases
    real min_x1, min_x2, min_true, min_lfp;
    real max_x1, max_x2, max_true, max_lfp;
    logic [7:0] min_aq, min_bq;
    logic [7:0] max_aq, max_bq;

    // ------------------------------------------------------------
    // FP64 → E3M4 quantizer (SAFE truncation, paper-faithful)
    // ------------------------------------------------------------
    function logic [7:0] fp64_to_e3m4(input real x);
        int E;
        real frac;
        int Mi;
        logic [3:0] M;
        begin
            if (x <= 0.0) begin
                fp64_to_e3m4 = 8'b0;
            end
            else begin
                // Inputs constrained to [1,2)
                E = 4;

                frac = x - 1.0;

                // Safe truncation (no rounding to 16!)
                Mi = $floor(frac * 16.0);

                if (Mi < 0)  Mi = 0;
                if (Mi > 15) Mi = 15;

                M = Mi[3:0];
                fp64_to_e3m4 = {1'b0, E[2:0], M};
            end
        end
    endfunction

    // ------------------------------------------------------------
    // E4M4 → real
    // ------------------------------------------------------------
    function real e4m4_to_real(input logic [8:0] x);
        int E;
        real M;
        begin
            if (x[7:4] == 4'b0000)
                e4m4_to_real = 0.0;
            else begin
                E = x[7:4];
                M = x[3:0] / 16.0;
                e4m4_to_real =
                    ((x[8]) ? -1.0 : 1.0) *
                    (2.0 ** (E - 8)) *
                    (1.0 + M);
            end
        end
    endfunction

    // ------------------------------------------------------------
    // Test
    // ------------------------------------------------------------
    initial begin
        min_ae =  1e9;
        max_ae = -1e9;

        for (i = 0; i < N; i++) begin

            // Random FP64 values in [1,2)
            x1_64 = 1.0 + ($urandom() / 4294967296.0);
            x2_64 = 1.0 + ($urandom() / 4294967296.0);

            true_mul = x1_64 * x2_64;

            // Quantize inputs
            a_q = fp64_to_e3m4(x1_64);
            b_q = fp64_to_e3m4(x2_64);
            #1;

            // LFP output
            lfp_mul = e4m4_to_real(y);

            // Signed absolute error (Table III definition)
            ae = lfp_mul - true_mul;

            // Track MIN AE
            if (ae < min_ae) begin
                min_ae   = ae;
                min_x1   = x1_64;
                min_x2   = x2_64;
                min_true = true_mul;
                min_lfp  = lfp_mul;
                min_aq   = a_q;
                min_bq   = b_q;
            end

            // Track MAX AE
            if (ae > max_ae) begin
                max_ae   = ae;
                max_x1   = x1_64;
                max_x2   = x2_64;
                max_true = true_mul;
                max_lfp  = lfp_mul;
                max_aq   = a_q;
                max_bq   = b_q;
            end
        end

        // ---------------- Results ----------------
        $display("==============================================");
        $display("FP64 [1,2) → E3M4 → LFP MULTIPLIER ERROR STUDY");
        $display("Samples      : %0d", N);

        $display("\n--- MIN AE (Worst Under-estimation) ---");
        $display("AE           : %e", min_ae);
        $display("x1_64        : %e", min_x1);
        $display("x2_64        : %e", min_x2);
        $display("a_q          : %b", min_aq);
        $display("b_q          : %b", min_bq);
        $display("true_mul     : %e", min_true);
        $display("lfp_mul      : %e", min_lfp);

        $display("\n--- MAX AE (Worst Over-estimation) ---");
        $display("AE           : %e", max_ae);
        $display("x1_64        : %e", max_x1);
        $display("x2_64        : %e", max_x2);
        $display("a_q          : %b", max_aq);
        $display("b_q          : %b", max_bq);
        $display("true_mul     : %e", max_true);
        $display("lfp_mul      : %e", max_lfp);

        $display("\nRange(AE)    : %e  ~  %e", min_ae, max_ae);
        $display("==============================================");

        $finish;
    end

endmodule

