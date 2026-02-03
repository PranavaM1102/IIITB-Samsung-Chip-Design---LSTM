//=================================================================
//  LSTM Cell (Q6.11, 18-bit signed)  - USING LUT SIGMOID & TANH
//  SAME LOGIC AS YOUR ORIGINAL CODE
//=================================================================

module lstm_cell_q6_11 #(
    parameter WIDTH = 18,
    parameter FRAC  = 11
)(
    input  wire                     clk,
    input  wire                     rst,

    // current input x_t
    input  wire signed [WIDTH-1:0]  x_t,

    // previous memories
    input  wire signed [WIDTH-1:0]  c_prev,   // GREEN (long-term)
    input  wire signed [WIDTH-1:0]  h_prev,   // PURPLE (short-term)

    // Forget gate weights
    input  wire signed [WIDTH-1:0]  W_fx,
    input  wire signed [WIDTH-1:0]  W_fh,
    input  wire signed [WIDTH-1:0]  b_f,

    // Input gate weights
    input  wire signed [WIDTH-1:0]  W_ix,
    input  wire signed [WIDTH-1:0]  W_ih,
    input  wire signed [WIDTH-1:0]  b_i,

    // Candidate gate weights
    input  wire signed [WIDTH-1:0]  W_gx,
    input  wire signed [WIDTH-1:0]  W_gh,
    input  wire signed [WIDTH-1:0]  b_g,

    // Output gate weights
    input  wire signed [WIDTH-1:0]  W_ox,
    input  wire signed [WIDTH-1:0]  W_oh,
    input  wire signed [WIDTH-1:0]  b_o,

    // new memories
    output reg  signed [WIDTH-1:0]  c_t,
    output reg  signed [WIDTH-1:0]  h_t
);

    // -------------------------------------------------------------
    // 1) Gate pre-activations
    // -------------------------------------------------------------

    // Forget gate
    wire signed [2*WIDTH-1:0] f_mul_x = x_t    * W_fx;
    wire signed [2*WIDTH-1:0] f_mul_h = h_prev * W_fh;
    wire signed [WIDTH-1:0]   f_pre   = (f_mul_x >>> FRAC) +
                                        (f_mul_h >>> FRAC) + b_f;

    // Input gate
    wire signed [2*WIDTH-1:0] i_mul_x = x_t    * W_ix;
    wire signed [2*WIDTH-1:0] i_mul_h = h_prev * W_ih;
    wire signed [WIDTH-1:0]   i_pre   = (i_mul_x >>> FRAC) +
                                        (i_mul_h >>> FRAC) + b_i;

    // Candidate gate
    wire signed [2*WIDTH-1:0] g_mul_x = x_t    * W_gx;
    wire signed [2*WIDTH-1:0] g_mul_h = h_prev * W_gh;
    wire signed [WIDTH-1:0]   g_pre   = (g_mul_x >>> FRAC) +
                                        (g_mul_h >>> FRAC) + b_g;

    // Output gate
    wire signed [2*WIDTH-1:0] o_mul_x = x_t    * W_ox;
    wire signed [2*WIDTH-1:0] o_mul_h = h_prev * W_oh;
    wire signed [WIDTH-1:0]   o_pre   = (o_mul_x >>> FRAC) +
                                        (o_mul_h >>> FRAC) + b_o;

    // -------------------------------------------------------------
    // 2) Activations using LUT blocks
    // -------------------------------------------------------------

    wire signed [WIDTH-1:0] f_gate;   // forget gate   σ
    wire signed [WIDTH-1:0] i_gate;   // input gate    σ
    wire signed [WIDTH-1:0] g_gate;   // candidate     tanh
    wire signed [WIDTH-1:0] o_gate;   // output gate   σ

    // --- BLUE lines (Sigmoid gates) ---
    sigmoid_lut u_sig_f (.x(f_pre), .y(f_gate));
    sigmoid_lut u_sig_i (.x(i_pre), .y(i_gate));
    sigmoid_lut u_sig_o (.x(o_pre), .y(o_gate));

    // --- ORANGE line (Candidate tanh) ---
    tanh_lut    u_tanh_g(.x(g_pre), .y(g_gate));

    // -------------------------------------------------------------
    // 3) Cell update: C_t = f_t * C_prev + i_t * g_t
    // -------------------------------------------------------------

    wire signed [2*WIDTH-1:0] fC_mul = f_gate * c_prev;
    wire signed [2*WIDTH-1:0] iG_mul = i_gate * g_gate;

    wire signed [WIDTH-1:0] c_new =
        (fC_mul >>> FRAC) + (iG_mul >>> FRAC);

    // -------------------------------------------------------------
    // 4) Short-term memory: h_t = o_t * tanh(C_t)
    // -------------------------------------------------------------

    wire signed [WIDTH-1:0] c_tanh;
    tanh_lut u_tanh_c (.x(c_new), .y(c_tanh));

    wire signed [2*WIDTH-1:0] oC_mul = o_gate * c_tanh;
    wire signed [WIDTH-1:0]   h_new  = oC_mul >>> FRAC;

    // -------------------------------------------------------------
    // 5) Registers (state update)
    // -------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            c_t <= 0;
            h_t <= 0;
        end else begin
            c_t <= c_new;  // GREEN LINE
            h_t <= h_new;  // PURPLE LINE
        end
    end

endmodule


//===========================================================
//  Tanh approximation  (piecewise quadratic, Q6.11)
//  Improved coefficients via least-squares fit
//===========================================================
module tanh_lut (
    input  wire signed [17:0] x,
    output reg  signed [17:0] y
);
    localparam signed [17:0] ONE = 18'sd2048;   // 1.0 in Q6.11
    reg signed [17:0] p0,p1,p2,x_clip;
    reg signed [35:0] x2;

    always @* begin
        // clip input to [-3,3] (Q6.11: [-6144, 6144])
        if (x > 18'sd6144)       x_clip = 18'sd6144;
        else if (x < -18'sd6144) x_clip = -18'sd6144;
        else                     x_clip = x;

        if (x_clip < -18'sd6144) begin
            // effectively unreachable after clip, but keep for safety
            y = -ONE;
        end
        else if (x_clip < -18'sd2048) begin
            // Region ~ [-3, -1]
            // p0 ≈ -0.4359, p1 ≈ 0.4317, p2 ≈ 0.0834
            p0 = -18'sd893;  // -0.4359
            p1 =  18'sd884;  //  0.4317
            p2 =  18'sd171;  //  0.0834
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 0) begin
            // Region ~ [-1, 0]
            // p0 ≈ 0.0070, p1 ≈ 1.1016, p2 ≈ 0.3300
            p0 =  18'sd14;    //  0.0070
            p1 =  18'sd2256;  //  1.1016
            p2 =  18'sd676;   //  0.3300
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 18'sd2048) begin
            // Region ~ [0, 1]
            // p0 ≈ -0.0070, p1 ≈ 1.1016, p2 ≈ -0.3300
            p0 = -18'sd14;    // -0.0070
            p1 =  18'sd2256;  //  1.1016
            p2 = -18'sd676;   // -0.3300
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 18'sd6144) begin
            // Region ~ [1, 3]
            // p0 ≈ 0.4359, p1 ≈ 0.4317, p2 ≈ -0.0834
            p0 =  18'sd893;  //  0.4359
            p1 =  18'sd884;  //  0.4317
            p2 = -18'sd171;  // -0.0834
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else begin
            y = ONE;
        end
    end
endmodule


//===========================================================
//  Sigmoid approximation  (piecewise quadratic, Q6.11)
//  Improved coefficients via least-squares fit
//===========================================================
module sigmoid_lut (
    input  wire signed [17:0] x,
    output reg  signed [17:0] y
);
    localparam signed [17:0] ONE = 18'sd2048;   // 1.0 in Q6.11
    reg signed [17:0] p0,p1,p2,x_clip;
    reg signed [35:0] x2;

    always @* begin
        // clip input to [-6,6] (Q6.11: [-12288, 12288])
        if (x > 18'sd12288)       x_clip = 18'sd12288;
        else if (x < -18'sd12288) x_clip = -18'sd12288;
        else                      x_clip = x;

        if (x_clip < -18'sd6144) begin
            // x < -3 → σ ≈ 0
            y = 0;
        end
        else if (x_clip < -18'sd3072) begin
            // Region ~ [-3, -1.5]
            // p0 ≈ 0.4709, p1 ≈ 0.2453, p2 ≈ 0.0348
            p0 = 18'sd964;   // 0.4709
            p1 = 18'sd502;   // 0.2453
            p2 = 18'sd71;    // 0.0348
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 0) begin
            // Region ~ [-1.5, 0]
            // p0 ≈ 0.5021, p1 ≈ 0.2690, p2 ≈ 0.0366
            p0 = 18'sd1028;  // 0.5021
            p1 = 18'sd551;   // 0.2690
            p2 = 18'sd75;    // 0.0366
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 18'sd3072) begin
            // Region ~ [0, 1.5]
            // p0 ≈ 0.4979, p1 ≈ 0.2690, p2 ≈ -0.0366
            p0 = 18'sd1020;  // 0.4979
            p1 = 18'sd551;   // 0.2690
            p2 = -18'sd75;   // -0.0366
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else if (x_clip < 18'sd6144) begin
            // Region ~ [1.5, 3]
            // p0 ≈ 0.5291, p1 ≈ 0.2453, p2 ≈ -0.0348
            p0 = 18'sd1084;  // 0.5291
            p1 = 18'sd502;   // 0.2453
            p2 = -18'sd71;   // -0.0348
            x2 = (x_clip * x_clip) >>> 11;
            y  = p0 + ((p1 * x_clip) >>> 11) + ((p2 * x2) >>> 11);
        end
        else begin
            // x >= 3 → σ ≈ 1
            y = ONE;
        end
    end
endmodule
