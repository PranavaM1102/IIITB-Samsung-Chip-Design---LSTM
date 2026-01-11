module lfp_mult_e4m3_fig3 (
    input  wire [7:0] x1,   // E4M3
    input  wire [7:0] x2,   // E4M3
    output wire [8:0] y     // E5M3
);
    // Sign
    wire sy = x1[7] ^ x2[7];

    // Packed exponent + mantissa
    wire [6:0] p1 = {x1[6:3], x1[2:0]};
    wire [6:0] p2 = {x2[6:3], x2[2:0]};

    // Log converters
    wire v1, v2;
    lfp_log3 log1 (.x(x1[2:0]), .v(v1));
    lfp_log3 log2 (.x(x2[2:0]), .v(v2));

    // Packed add (Fig.3 Point A)
    wire [7:0] y_a;
    assign y_a = p1 + p2 + v1 + v2;

    // Antilog
    wire v_out;
    lfp_antilog3 antilog (.x(y_a[2:0]), .v(v_out));
    wire [2:0] m_out = y_a[2:0] - v_out;

    // Zero handling
    assign y = (x1[6:3] == 0 || x2[6:3] == 0) ? 9'b0 :
               {sy, y_a[7:3], m_out};
endmodule
module lfp_antilog3 (
    input  wire [2:0] x,
    output wire       v   // v=1 → subtract 1
);
    wire cond;
    assign cond = (~x[2] & ~x[1]) |
                  ( x[2] &  x[1] & x[0]) |
                  (~x[2] &  x[1] & ~x[0]);
    assign v = ~cond;   // x−1 if Eq.3.2 is FALSE
endmodule
module lfp_log3 (
    input  wire [2:0] x,
    output wire       v   // v=1 → add 1
);
    wire cond;
    assign cond = (~x[2] & ~x[1]) | (x[2] & x[1]);
    assign v = ~cond;   // x+1 if Eq.3.1 is FALSE
endmodule
