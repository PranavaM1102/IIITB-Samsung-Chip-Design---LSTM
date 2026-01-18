module E4M4_9b_to_Q6_11 (
    input  [8:0] fp,              // fp[8]=S, fp[7:4]=E, fp[3:0]=M
    output reg signed [17:0] q     // Q6.11
);

    reg sign;
    reg [3:0] exp;
    reg [4:0] mant;                // (1.M) * 2^4
    integer shift;
    reg signed [17:0] tmp = 17'd0;

    always @(*) begin
        // default
        q = 18'sd0;

        sign = fp[8];
        exp  = fp[7:4];

        // -----------------------------
        // Zero / underflow
        // -----------------------------
        if (exp == 0) begin
            q = 18'sd0;
        end
        else begin
            // -----------------------------
            // Compute shift = E - 1
            // -----------------------------
            shift = exp - 8 ;

            // -----------------------------
            // Underflow (shift < 0)
            // -----------------------------
// Scale
tmp [17:0] = {6'd0,1'b1, fp[3:0],7'd0};
if ((shift ) >= 0)
    tmp = tmp <<< (shift );
else
begin
    tmp = tmp >>> (-(shift ));
                // -----------------------------
                // Mantissa = (1.M) * 2^4
                // -----------------------------
                

                // -----------------------------
                // Scale
                // -----------------------------
                

                // -----------------------------
                // Apply sign
                // -----------------------------
end
                if (sign)
                    tmp = -tmp;

                // -----------------------------
                // Saturation
                // -----------------------------
                
                    q = tmp[17:0];
            end
        end
   
endmodule
