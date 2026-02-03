`timescale 1ns/1ps

module tb_lstm_exhaustive;

    parameter WIDTH = 18;
    parameter FRAC  = 11;

    reg clk, rst;
    reg signed [WIDTH-1:0] x_t, c_prev, h_prev;
    
    // Weights (StatQuest Constants)
    reg signed [WIDTH-1:0] W_fx = 18'sd3338, W_fh = 18'sd5529, b_f = 18'sd3318;
    reg signed [WIDTH-1:0] W_ix = 18'sd3379, W_ih = 18'sd4096, b_i = 18'sd1269;
    reg signed [WIDTH-1:0] W_gx = 18'sd1926, W_gh = 18'sd2889, b_g = -18'sd655;
    reg signed [WIDTH-1:0] W_ox = -18'sd389, W_oh = 18'sd8970, b_o = 18'sd1209;

    wire signed [WIDTH-1:0] c_t, h_t;

    lstm_cell_q6_11 dut (
        .clk(clk), .rst(rst), .x_t(x_t), .c_prev(c_prev), .h_prev(h_prev),
        .W_fx(W_fx), .W_fh(W_fh), .b_f(b_f),
        .W_ix(W_ix), .W_ih(W_ih), .b_i(b_i),
        .W_gx(W_gx), .W_gh(W_gh), .b_g(b_g),
        .W_ox(W_ox), .W_oh(W_oh), .b_o(b_o),
        .c_t(c_t), .h_t(h_t)
    );

    always #5 clk = ~clk;

    integer f, i;
    initial begin
        clk = 0; rst = 1;
        x_t = 0; c_prev = 0; h_prev = 0;
        
        f = $fopen("hw_results.csv", "w");
        $fdisplay(f, "x_t,c_t,h_t"); // CSV Header

        #20 rst = 0;

        // Exhaustive Sweep: -5.0 to 5.0 in steps of 0.125
        for (i = -10240; i <= 10240; i = i + 256) begin
            @(posedge clk);
            x_t = i;
            #1; // Wait for logic settling
            $fdisplay(f, "%d,%d,%d", x_t, c_t, h_t);
            
            // Feed back for next step
            c_prev = c_t;
            h_prev = h_t;
        end

        $fclose(f);
        $display("Simulation complete. Results saved to hw_results.csv");
        $finish;
    end
endmodule