//=================================================================
//  LSTM Cell with LFP MAC
//  - Inputs / states : Q6.11
//  - Weights         : E3M4
//  - Biases          : Q6.11
//  - Activations     : LUT-based (unchanged)
//=================================================================

module lstm_cell_q6_11 #(
    parameter WIDTH = 18,
    parameter FRAC  = 11
)(
    input  wire                     clk,
    input  wire                     rst,

    input  wire signed [WIDTH-1:0]  x_t,
    input  wire signed [WIDTH-1:0]  c_prev,
    input  wire signed [WIDTH-1:0]  h_prev,

    // -------- E3M4 weights --------
    input  wire [7:0]  W_fx, W_fh,
    input  wire [7:0]  W_ix, W_ih,
    input  wire [7:0]  W_gx, W_gh,
    input  wire [7:0]  W_ox, W_oh,

    // -------- Q6.11 biases --------
    input  wire signed [WIDTH-1:0]  b_f,
    input  wire signed [WIDTH-1:0]  b_i,
    input  wire signed [WIDTH-1:0]  b_g,
    input  wire signed [WIDTH-1:0]  b_o,

    output reg  signed [WIDTH-1:0]  c_t,
    output reg  signed [WIDTH-1:0]  h_t
);

    // =============================================================
    // 1) Gate pre-activations using LFP MAC
    // =============================================================

    wire signed [WIDTH-1:0] f_mac;
    wire signed [WIDTH-1:0] i_mac;
    wire signed [WIDTH-1:0] g_mac;
    wire signed [WIDTH-1:0] o_mac;

    lfp_mac_top_q6_11 u_mac_f (
        .in0_q   (x_t),
        .in1_q   (h_prev),
        .weight1 (W_fx),
        .weight2 (W_fh),
        .out_q   (f_mac)
    );

    lfp_mac_top_q6_11 u_mac_i (
        .in0_q   (x_t),
        .in1_q   (h_prev),
        .weight1 (W_ix),
        .weight2 (W_ih),
        .out_q   (i_mac)
    );

    lfp_mac_top_q6_11 u_mac_g (
        .in0_q   (x_t),
        .in1_q   (h_prev),
        .weight1 (W_gx),
        .weight2 (W_gh),
        .out_q   (g_mac)
    );

    lfp_mac_top_q6_11 u_mac_o (
        .in0_q   (x_t),
        .in1_q   (h_prev),
        .weight1 (W_ox),
        .weight2 (W_oh),
        .out_q   (o_mac)
    );

    // Add bias (Q6.11, unchanged)
    wire signed [WIDTH-1:0] f_pre = f_mac + b_f;
    wire signed [WIDTH-1:0] i_pre = i_mac + b_i;
    wire signed [WIDTH-1:0] g_pre = g_mac + b_g;
    wire signed [WIDTH-1:0] o_pre = o_mac + b_o;

    // =============================================================
    // 2) Activations (UNCHANGED)
    // =============================================================

    wire signed [WIDTH-1:0] f_gate;
    wire signed [WIDTH-1:0] i_gate;
    wire signed [WIDTH-1:0] g_gate;
    wire signed [WIDTH-1:0] o_gate;

    sigmoid_q6_11 u_sig_f (.x(f_pre), .y(f_gate));
    sigmoid_q6_11 u_sig_i (.x(i_pre), .y(i_gate));
    sigmoid_q6_11 u_sig_o (.x(o_pre), .y(o_gate));
    tanh_q6_11    u_tanh_g(.x(g_pre), .y(g_gate));

    // =============================================================
    // 3) Cell update: C_t = f*C_prev + i*g   (Q6.11)
    // =============================================================

    wire signed [2*WIDTH-1:0] fC_mul = f_gate * c_prev;
    wire signed [2*WIDTH-1:0] iG_mul = i_gate * g_gate;

    wire signed [WIDTH-1:0] c_new =
        (fC_mul >>> FRAC) + (iG_mul >>> FRAC);

    // =============================================================
    // 4) Hidden state: h_t = o * tanh(C_t)
    // =============================================================

    wire signed [WIDTH-1:0] c_tanh;
    tanh_q6_11 u_tanh_c (.x(c_new), .y(c_tanh));

    wire signed [2*WIDTH-1:0] oC_mul = o_gate * c_tanh;
    wire signed [WIDTH-1:0]   h_new  = oC_mul >>> FRAC;

    // =============================================================
    // 5) Registers
    // =============================================================

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_t <= '0;
            h_t <= '0;
        end else begin
            c_t <= c_new;
            h_t <= h_new;
        end
    end

endmodule

/*module sigmoid_lut_wrapper (
    input  wire signed [17:0] x,   // Q6.11
    output wire signed [17:0] y
);
    // LUT range: [-6, +6] → 14-bit index
    wire [13:0] addr;

    assign addr =
        (x <= -18'sd12288) ? 14'd0 :
        (x >=  18'sd12288) ? 14'd16383 :
        (x + 18'sd12288) >>> 1;

    sigmoid_lut lut (
        .addr(addr),
        .y(y)
    );
endmodule
module tanh_lut_wrapper (
    input  wire signed [17:0] x,   // Q6.11
    output wire signed [17:0] y
);
    // LUT range: [-3, +3] → 13-bit index
    wire [12:0] addr;

    assign addr =
        (x <= -18'sd6144) ? 13'd0 :
        (x >=  18'sd6144) ? 13'd8191 :
        (x + 18'sd6144) >>> 1;

    tanh_lut lut (
        .addr(addr),
        .y(y)
    );
endmodule
//===========================================================
// Sigmoid LUT ROM
// addr : 14-bit unsigned
// y    : Q6.11 signed
//===========================================================
module sigmoid_lut (
    input  wire [13:0] addr,
    output reg  signed [17:0] y
);

    // 16384-entry ROM
    reg signed [17:0] rom [0:16383];

    initial begin
        $readmemh("sigmoid_lut.hex", rom);
    end

    always @(*) begin
        y = rom[addr];
    end

endmodule
//===========================================================
// Tanh LUT ROM
// addr : 13-bit unsigned
// y    : Q6.11 signed
//===========================================================
module tanh_lut (
    input  wire [12:0] addr,
    output reg  signed [17:0] y
);

    // 8192-entry ROM
    reg signed [17:0] rom [0:8191];

    initial begin
        $readmemh("tanh_lut.hex", rom);
    end

    always @(*) begin
        y = rom[addr];
    end

endmodule*/
