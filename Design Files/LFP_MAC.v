module lfp_mac_top_q6_11 (
    input  signed [17:0] in0_q,   // Input 0 (Q6.11)
    input  signed [17:0] in1_q,   // Input 1 (Q6.11)
    output signed [17:0] out_q    // Output (Q6.11)
);

    // -------------------------------------------------
    // Wires
    // -------------------------------------------------

    // Q6.11 -> E3M4
    wire [7:0] in0_e3m4;
    wire [7:0] in1_e3m4;

    // LFP multiplier outputs (E4M4)
    wire [8:0] mul0_e4m4;
    wire [8:0] mul1_e4m4;

    // E4M4 -> Q6.11
    wire signed [17:0] mul0_q;
    wire signed [17:0] mul1_q;

    // -------------------------------------------------
    // Constant weight = 1.0 (E3M4)
    // -------------------------------------------------
    localparam [7:0] E3M4_ONE = 8'b0_100_0000;

    // -------------------------------------------------
    // Q6.11 → E3M4 converters
    // -------------------------------------------------
    Q6_11toE3M4_Converter u_q_to_e3m4_0 (
        .q  (in0_q),
        .fp (in0_e3m4)
    );

    Q6_11toE3M4_Converter u_q_to_e3m4_1 (
        .q  (in1_q),
        .fp (in1_e3m4)
    );

    // -------------------------------------------------
    // LFP E3M4 multipliers
    // -------------------------------------------------
    lfp_mult_e3m4_fig3 u_mul0 (
        .x1 (in0_e3m4),
        .x2 (E3M4_ONE),
        .y  (mul0_e4m4)
    );

    lfp_mult_e3m4_fig3 u_mul1 (
        .x1 (in1_e3m4),
        .x2 (E3M4_ONE),
        .y  (mul1_e4m4)
    );

    // -------------------------------------------------
    // E4M4 → Q6.11 converters
    // -------------------------------------------------
    E4M4_9b_to_Q6_11 u_e4m4_to_q_0 (
        .fp (mul0_e4m4),
        .q  (mul0_q)
    );

    E4M4_9b_to_Q6_11 u_e4m4_to_q_1 (
        .fp (mul1_e4m4),
        .q  (mul1_q)
    );

    // -------------------------------------------------
    // Adder (Q6.11)
    // -------------------------------------------------
    assign out_q = mul0_q + mul1_q;

endmodule
