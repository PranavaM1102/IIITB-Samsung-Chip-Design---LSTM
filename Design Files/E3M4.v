module lfp_mult_e3m4_fig3 (
    input  wire [7:0] x1,   // E3M4
    input  wire [7:0] x2,   // E3M4
    output wire [8:0] y     // E4M4 (sign + 4-bit exp + 4-bit man)
);
    // -------------------------------
    // Field extraction
    // -------------------------------
    wire s1 = x1[7];
    wire s2 = x2[7];
    wire sy = s1 ^ s2;

  wire [6:0] p1 = x1[6:0];
  wire [6:0] p2 = x2[6:0];

    

    // -------------------------------
    // Log converters
    // -------------------------------
    wire v1, v2;
  lfp_log4 log1 (.x(x1[3:0]), .v(v1));
  lfp_log4 log2 (.x(x2[3:0]), .v(v2));

    // -------------------------------
    // Core adder (Point A in Fig. 3)
    // y_a[7:0] = x1[6:0] + x2[6:0] + v1 + v2
    // -------------------------------
    wire [7:0] y_a;
  assign y_a = p1 + p2 + v1 + v2 ;

    // -------------------------------
    // Antilog (right block in Fig. 3)
    // -------------------------------
    wire v_out;
  lfp_antilog4 antilog (.x(y_a[3:0]), .v(v_out));

  wire [3:0] m_out = y_a[3:0] - v_out;

    // -------------------------------
    // Zero handling (as per paper)
    // -------------------------------
    assign y = (x1[6:4] == 0 || x2[6:4] == 0) ? 9'b0 :
               {sy, y_a[7:4], m_out};

endmodule
// Code your design here
module lfp_antilog4 (
    input  wire [3:0] x,
    output wire       v
);
  wire vbar = ((~x[3] & ~x[2] & ~x[1]) | ( x[3] &  x[2] &  x[1] & x[0]));
  assign v = ~vbar;

// x − 1 if Eq.3.3 is FALSE
endmodule

module lfp_log4 (
    input  wire [3:0] x,
    output wire       v
);
    // Eq. (3.3)
   // Eq. (3.3)
  wire vbar = ((~x[3] & ~x[2] & ~x[1]) | ( x[3] &  x[2] &  x[1] & x[0]));
  assign v = ~vbar;

// x + 1 if Eq.3.3 is FALSE
endmodule


