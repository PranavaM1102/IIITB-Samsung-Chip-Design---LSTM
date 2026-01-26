`timescale 1ns/1ps

module tb_tanh_sigmoid;

    localparam WIDTH = 18;
    localparam real SCALE = 2048.0;

    reg  signed [WIDTH-1:0] x;
    wire signed [WIDTH-1:0] tanh_y;
    wire signed [WIDTH-1:0] sig_y;

    integer fd_in;
    integer fd_csv;
    integer exp_tanh_q, exp_sig_q;

    real x_real;
    real tanh_dut_real, tanh_exp_real;
    real sig_dut_real,  sig_exp_real;
    real tanh_abs_err,  sig_abs_err;
    integer sig_abs_err_lsb;

    tanh_q6_11    dut_tanh (.x(x), .y(tanh_y));
    sigmoid_q6_11 dut_sig  (.x(x), .y(sig_y));

    // -------------------------
    // Absolute value helpers
    // -------------------------
    function real abs_real(input real v);
        if (v < 0.0) abs_real = -v;
        else         abs_real =  v;
    endfunction

    function integer abs_int(input integer v);
        if (v < 0) abs_int = -v;
        else       abs_int =  v;
    endfunction

    initial begin
        fd_in  = $fopen("golden_q611.txt", "r");
        fd_csv = $fopen("results.csv", "w");

        if (fd_in == 0 || fd_csv == 0) begin
            $display("ERROR: file open failed");
            $finish;
        end

        // CSV header
        $fwrite(fd_csv,"x_q611,x_real,tanh_dut_q611,tanh_dut_real,tanh_golden_real,tanh_abs_err_real,sig_dut_q611,sig_dut_real,sig_golden_real,sig_abs_err_real,sig_abs_err_lsb\n");

        while (!$feof(fd_in)) begin
            $fscanf(fd_in, "%d %d %d\n", x, exp_tanh_q, exp_sig_q);
            #1;

            // Convert to real
            x_real        = x / SCALE;

            tanh_dut_real = tanh_y / SCALE;
            tanh_exp_real = exp_tanh_q / SCALE;

            sig_dut_real  = sig_y / SCALE;
            sig_exp_real  = exp_sig_q / SCALE;

            // Errors
            tanh_abs_err  = abs_real(tanh_dut_real - tanh_exp_real);
            sig_abs_err   = abs_real(sig_dut_real  - sig_exp_real);
            sig_abs_err_lsb = abs_int(sig_y - exp_sig_q);

            // Write CSV row
            $fwrite(fd_csv,
                "%0d,%f,%0d,%f,%f,%e,%0d,%f,%f,%e,%0d\n",
                x, x_real,
                tanh_y, tanh_dut_real, tanh_exp_real, tanh_abs_err,
                sig_y,  sig_dut_real,  sig_exp_real,  sig_abs_err,
                sig_abs_err_lsb
            );
        end

        $fclose(fd_in);
        $fclose(fd_csv);

        $display("====================================");
        $display(" CSV GENERATED : results.csv ");
        $display(" NO FATALS, FULL DATA DUMP ");
        $display("====================================");

        $finish;
    end

endmodule
