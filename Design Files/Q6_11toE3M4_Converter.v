module Q6_11toE3M4_Converter (
    input  signed [17:0] q,    // Q6.11
    output reg    [7:0]  fp     // E3M4
);

    integer i;

    reg sign;
    reg [17:0] abs_q;
    reg [4:0]  pos;             // MSB position
    reg signed [6:0] unbiased_exp;
    reg [2:0]  exp;
    reg [4:0]  mant;            // 1 extra bit for rounding
    reg [17:0] norm;

    always @(*) begin
        fp = 8'b0;

        // ----------------------------------
        // Sign and absolute value
        // ----------------------------------
        sign  = q[17];
        abs_q = sign ? -q : q;

        // ----------------------------------
        // Zero
        // ----------------------------------
        if (abs_q == 0) begin
            fp = 8'b0;
        end else begin

            // ----------------------------------
            // Correct MSB detection (priority)
            // ----------------------------------
            begin : LOD
                pos = 0;
                for (i = 17; i >= 0; i = i - 1)
                    if (abs_q[i]) begin
                        pos = i;
                        disable LOD;
                    end
            end

            // ----------------------------------
            // Exponent computation
            // real value = abs_q * 2^-11
            // ----------------------------------
            unbiased_exp = pos - 11;
            exp = unbiased_exp + 4;   // bias = 3

            // ----------------------------------
            // Underflow → flush to zero
            // ----------------------------------
            if (exp < 1) begin
                fp = 8'b0;
            end
            // ----------------------------------
            // Overflow → saturate
            // ----------------------------------
            else if (exp > 7) begin
                fp = {sign, 3'b111, 4'b1111};
            end
            else begin
                // ----------------------------------
                // Normalize mantissa
                // ----------------------------------
                norm = abs_q << (17 - pos);

                // mantissa bits
                mant = norm[16:13];

                // round-to-nearest
                if (norm[12])
                    mant = mant + 1;

                // mantissa overflow
                if (mant == 5'b10000) begin
                    mant = 4'b0000;
                    exp  = exp + 1;
                end

                // re-check overflow after rounding
                if (exp > 7)
                    fp = {sign, 3'b111, 4'b1111};
                else
                    fp = {sign, exp, mant[3:0]};
            end
        end
    end
endmodule
