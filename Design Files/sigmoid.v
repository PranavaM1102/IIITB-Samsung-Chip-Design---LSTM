module sigmoid_q6_11 (
    input  signed [17:0] x,
    output reg signed [17:0] y
);

    localparam signed [17:0] Q6 = 18'sd12288;  // 6.0
    localparam signed [17:0] Q1 = 18'sd2048;   // 1.0

    wire sign = x[17];
    wire signed [17:0] x_abs = sign ? -x : x;

    wire signed [17:0] sig_lut_out;

    sigmoid_lut lut (
        .addr(x_abs),
        .y(sig_lut_out)
    );

    always @(*) begin
        // ---- HARD SATURATION FIRST ----
        if (x <= -Q6)
            y = 18'sd0;
        else if (x >= Q6)
            y = Q1;
        // ---- LUT REGION ONLY ----
        else if (sign)
            y = Q1 - sig_lut_out;
        else
            y = sig_lut_out;
    end

endmodule


module sigmoid_lut (
    input  [17:0] addr,
    output reg signed [17:0] y
);

    reg signed [17:0] rom [0:383];
    wire [8:0] raw_index;
    wire [8:0] index;

    assign raw_index = addr >> 5;
    assign index = (raw_index > 9'd383) ? 9'd383 : raw_index;

    initial begin
        $readmemh("sigmoid_lut.mem", rom);
    end

    always @(*) begin
        y = rom[index];
    end

endmodule

