module tanh_q6_11 (
    input  signed [17:0] x,
    output reg signed [17:0] y
);

    localparam signed [17:0] Q025 = 18'sd512;    // 0.25
    localparam signed [17:0] Q3   = 18'sd6144;   // 3.0
    localparam signed [17:0] Q1   = 18'sd2048;   // 1.0

    wire sign = x[17];
    wire signed [17:0] x_abs = sign ? -x : x;

    // LUT output
    wire signed [17:0] tanh_lut_out;

    // LUT instance (defined later)
    tanh_lut lut (
        .addr(x_abs),
        .y(tanh_lut_out)
    );

    always @(*) begin
        if (sign) begin
            // tanh(-x) = -tanh(x)
            if (x_abs < Q025)
                y = -x_abs;
            else if (x_abs < Q3)
                y = -tanh_lut_out;
            else
                y = -Q1;
        end else begin
            if (x < Q025)
                y = x;
            else if (x < Q3)
                y = tanh_lut_out;
            else
                y = Q1;
        end
    end

endmodule
module tanh_lut (
    input  [17:0] addr,     // Q6.11 input
    output reg signed [17:0] y
);

    reg signed [17:0] rom [0:351];

    initial begin
        $readmemh("tanh_lut.mem", rom);
    end

    wire [8:0] index;
    assign index = (addr - 18'sd512) >> 4; // Δ = 1/128 → shift by 4

    always @(*) begin
        y = rom[index];
    end
endmodule
