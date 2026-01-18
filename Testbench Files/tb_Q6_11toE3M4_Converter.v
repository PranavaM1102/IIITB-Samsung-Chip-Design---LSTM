`timescale 1ns/1ps

module tb_Q6_11toE3M4_Sweep;

    reg  signed [17:0] q;
    wire        [7:0]  fp;

    // DUT
    Q6_11toE3M4_Converter dut (
        .q(q),
        .fp(fp)
    );

    integer i;
    integer total_count;
    integer underflow_count;
    integer saturation_count;
    integer error_count;

    real q_real;
    real fp_real;
    real rel_error;
    real error_sum;

    integer csv;

    // ---------------------------------
    // FP8 decode (E3M4)
    // ---------------------------------
    task decode_fp8;
        input  [7:0] f;
        output real  val;
        integer exp;
        real mant;
        begin
            if (f[6:4] == 0) begin
                val = 0.0;
            end else begin
                exp  = f[6:4] - 3;
                mant = 1.0 + (f[3:0] / 16.0);
                val  = mant * (2.0 ** exp);
                if (f[7]) val = -val;
            end
        end
    endtask

    // ---------------------------------
    // Sweep
    // ---------------------------------
    initial begin
        total_count      = 0;
        underflow_count  = 0;
        saturation_count = 0;
        error_count      = 0;
        error_sum        = 0.0;

        csv = $fopen("q6_11_to_e3m4_sweep.csv", "w");
        if (csv == 0) begin
            $display("ERROR: Could not open CSV file");
            $finish;
        end

        // CSV header
        $fdisplay(csv,
            "q_raw,q_real,fp8_hex,fp_real,category,relative_error");

        $display("==============================================");
        $display(" Q6.11 → E3M4 FULL SWEEP TEST ");
        $display("==============================================");

        for (i = -131072; i <= 131071; i = i + 1) begin
            q = i[17:0];
            #1;

            q_real = q / 2048.0;
            decode_fp8(fp, fp_real);

            // -----------------------------
            // ZERO
            // -----------------------------
            if (q_real == 0.0) begin
                $fdisplay(csv,
                    "%0d,%f,%02x,%f,ZERO,0.0",
                    q, q_real, fp, fp_real);
            end
            else begin
                total_count = total_count + 1;

                // -----------------------------
                // UNDERFLOW
                // -----------------------------
                if (fp[6:4] == 0) begin
                    underflow_count = underflow_count + 1;

                    $fdisplay(csv,
                        "%0d,%f,%02x,%f,UNDERFLOW,1.0",
                        q, q_real, fp, fp_real);
                end
                // -----------------------------
                // SATURATION
                // -----------------------------
                else if (fp[6:4] == 3'b111 && fp[3:0] == 4'b1111) begin
                    saturation_count = saturation_count + 1;

                    $fdisplay(csv,
                        "%0d,%f,%02x,%f,SATURATION,0.0",
                        q, q_real, fp, fp_real);
                end
                // -----------------------------
                // NORMALIZED
                // -----------------------------
                else begin
                    rel_error = fp_real - q_real;
                    if (rel_error < 0) rel_error = -rel_error;

                    if (q_real < 0)
                        rel_error = rel_error / (-q_real);
                    else
                        rel_error = rel_error / q_real;

                    error_sum   = error_sum + rel_error;
                    error_count = error_count + 1;

                    $fdisplay(csv,
                        "%0d,%f,%02x,%f,NORMAL,%e",
                        q, q_real, fp, fp_real, rel_error);
                end
            end
        end

        $fclose(csv);

        $display("==============================================");
        $display(" Total nonzero inputs     : %0d", total_count);
        $display(" Underflow count          : %0d", underflow_count);
        $display(" Saturation count         : %0d", saturation_count);
        $display(" Normalized samples       : %0d", error_count);

        if (error_count > 0)
            $display(" Average relative error   : %e",
                     error_sum / error_count);
        else
            $display(" Average relative error   : N/A");

        $display(" CSV written: q6_11_to_e3m4_sweep.csv");
        $display("==============================================");

        $finish;
    end

endmodule
