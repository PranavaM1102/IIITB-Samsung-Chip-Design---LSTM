module lstm_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire signed [7:0]  x_t,        // FP8
    input  wire signed [7:0]  h_prev,     // FP8
    input  wire signed [15:0] c_prev,     // FP16

    input  wire signed [7:0]  w_in,        // FloatSD8
    input  wire signed [15:0] bias,        // FP16

    output wire signed [15:0] h_out,       // FP16
    output wire signed [15:0] c_next,      // FP16
    output wire               ready
);

    wire signed [15:0] mac_out;

    floatSD8_mac u_mac (
        .clk(clk), .rst_n(rst_n),
        .weight(w_in),
        .activation(x_t),
        .bias(bias),
        .psum_out(mac_out)
    );

    lstm_controller u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start),
        .mac_in(mac_out),
        .c_prev(c_prev),
        .h_out(h_out),
        .c_next(c_next),
        .done(ready)
    );

endmodule

module lstm_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire signed [15:0] mac_in,
    input  wire signed [15:0] c_prev,

    output reg  signed [15:0] h_out,
    output reg  signed [15:0] c_next,
    output reg               done
);

    // ---------- STATE ENCODING (IVERILOG SAFE) ----------
    localparam IDLE   = 3'd0;
    localparam F_GATE = 3'd1;
    localparam I_GATE = 3'd2;
    localparam G_GATE = 3'd3;
    localparam O_GATE = 3'd4;
    localparam C_UPD  = 3'd5;
    localparam H_UPD  = 3'd6;

    reg [2:0] state;

    // ---------- GATES ----------
    reg signed [7:0] f_gate, i_gate, g_gate, o_gate;

    // ---------- ACTIVATIONS ----------
    wire signed [7:0]  sig_sd;
    wire signed [15:0] tanh_fp;
    wire signed [15:0] tanh_c;

    sigmoid_p2 u_sig (.x(mac_in), .y_sd(sig_sd));
    tanh_p2    u_tnh (.x(mac_in), .y(tanh_fp));
    tanh_p2    u_tnh_c (.x(c_next), .y(tanh_c));

    // ---------- SD8 × FP16 MULTIPLY (INLINE) ----------
    function [15:0] sd8_mul_fp16;
        input signed [7:0]  sd8;
        input signed [15:0] fp16;
        reg   signed [2:0]  exp;
        reg   signed [2:0]  sd1;
        reg   signed [1:0]  sd2;
        begin
            exp = sd8[7:5];
            sd1 = sd8[4:2];
            sd2 = sd8[1:0];
            sd8_mul_fp16 =
                (fp16 <<< exp) +
                (fp16 <<< sd1) +
                (fp16 <<< sd2);
        end
    endfunction

    // ---------- FSM ----------
    always @(posedge clk) begin
        if (!rst_n) begin
            state  <= IDLE;
            done   <= 1'b0;
            h_out  <= 16'sd0;
            c_next <= 16'sd0;
        end else begin
            done <= 1'b0;
            case (state)

                IDLE:
                    if (start) state <= F_GATE;

                F_GATE: begin
                    f_gate <= sig_sd;
                    state  <= I_GATE;
                end

                I_GATE: begin
                    i_gate <= sig_sd;
                    state  <= G_GATE;
                end

                G_GATE: begin
                    g_gate <= tanh_fp[15:8]; // coarse FloatSD8
                    state  <= O_GATE;
                end

                O_GATE: begin
                    o_gate <= sig_sd;
                    state  <= C_UPD;
                end

                C_UPD: begin
                    c_next <= sd8_mul_fp16(f_gate, c_prev)
                            + sd8_mul_fp16(i_gate, {{8{g_gate[7]}}, g_gate});
                    state  <= H_UPD;
                end

                H_UPD: begin
                    h_out <= sd8_mul_fp16(o_gate, tanh_c);
                    done  <= 1'b1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule

module tanh_p2 (
    input  wire signed [15:0] x,  // FP16
    output reg  signed [15:0] y   // FP16
);
    wire sign = x[15];
    wire signed [15:0] xa = sign ? -x : x;
    reg  signed [31:0] x2;
    reg  signed [15:0] yp;

    localparam signed [15:0] ONE = 16'h3C00; // 1.0

    always @(*) begin
        x2 = xa * xa;
        if (xa < 16'h3C00) begin
            yp = (- (x2 >>> 4)) + ((xa * 16'h3800) >>> 10);
        end else if (xa < 16'h4000) begin
            yp = (- (x2 >>> 6)) + ((xa * 16'h2E00) >>> 10) + 16'h3400;
        end else begin
            yp = ONE;
        end
        y = sign ? -yp : yp;
    end
endmodule

module sigmoid_p2 (
    input  wire signed [15:0] x,     // FP16
    output reg  signed [7:0]  y_sd   // FloatSD8
);
    wire sign = x[15];
    wire signed [15:0] xa = sign ? -x : x;
    reg  signed [31:0] x2;
    reg  signed [15:0] yfp;

    always @(*) begin
        x2 = xa * xa;
        if (xa < 16'h3C00) begin
            yfp = (- (x2 >>> 5)) + ((xa * 16'h2000) >>> 10) + 16'h3800;
        end else if (xa < 16'h4000) begin
            yfp = (- (x2 >>> 7)) + ((xa * 16'h1700) >>> 10) + 16'h3900;
        end else begin
            yfp = 16'h3C00;
        end
        if (sign) yfp = 16'h3C00 - yfp;

        // coarse FP16→FloatSD8 quantization (gate-friendly)
        if (yfp > 16'h3A00)      y_sd = 8'h30; // ~1
        else if (yfp > 16'h3800) y_sd = 8'h20; // ~0.5
        else if (yfp > 16'h3400) y_sd = 8'h10; // ~0.25
        else                     y_sd = 8'h00;
    end
endmodule

module floatSD8_mac (
    input  wire        clk,
    input  wire        rst_n,
    input  wire signed [7:0]  weight,      // FloatSD8
    input  wire signed [7:0]  activation,  // FP8
    input  wire signed [15:0] bias,        // FP16
    output reg  signed [15:0] psum_out     // FP16
);
    wire signed [15:0] p1, p2;

    sd8_decoder u_dec (
        .weight(weight),
        .activation(activation),
        .p_prod1(p1),
        .p_prod2(p2)
    );

    always @(posedge clk) begin
        if (!rst_n) psum_out <= 16'sd0;
        else        psum_out <= p1 + p2 + bias;
    end
endmodule

module sd8_decoder (
    input  wire signed [7:0]  weight,
    input  wire signed [7:0]  activation,
    output wire signed [15:0] p_prod1,
    output wire signed [15:0] p_prod2
);
    wire signed [2:0] exp = weight[7:5];
    wire signed [2:0] sd1 = weight[4:2];
    wire signed [1:0] sd2 = weight[1:0];

    assign p_prod1 = ({{8{activation[7]}},activation} <<< exp)
                   + ({{8{activation[7]}},activation} <<< sd1);
    assign p_prod2 = ({{8{activation[7]}},activation} <<< sd2);
endmodule
