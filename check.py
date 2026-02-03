import math
import pandas as pd

# ------------------------------------------------------------
# 1. Exact activations (REAL sigmoid and tanh)
# ------------------------------------------------------------
def sigmoid(x: float) -> float:
    if x >= 0:
        z = math.exp(-x)
        return 1.0 / (1.0 + z)
    else:
        z = math.exp(x)
        return z / (1.0 + z)

def tanh(x: float) -> float:
    return math.tanh(x)

# ------------------------------------------------------------
# 2. One LSTM step (Provided Model)
# ------------------------------------------------------------
def lstm_step(x_t: float, h_prev: float, c_prev: float,
              W_fx, W_fh, b_f, W_ix, W_ih, b_i,
              W_gx, W_gh, b_g, W_ox, W_oh, b_o):
    f_pre = W_fx * x_t + W_fh * h_prev + b_f
    i_pre = W_ix * x_t + W_ih * h_prev + b_i
    g_pre = W_gx * x_t + W_gh * h_prev + b_g
    o_pre = W_ox * x_t + W_oh * h_prev + b_o

    f_t = sigmoid(f_pre)
    i_t = sigmoid(i_pre)
    g_t = tanh(g_pre)
    o_t = sigmoid(o_pre)

    c_t = f_t * c_prev + i_t * g_t
    h_t = o_t * tanh(c_t)

    return c_t, h_t

# ------------------------------------------------------------
# 3. Verification & Comparison
# ------------------------------------------------------------
# Load data and setup weights
df = pd.read_csv('hw_results.csv')
frac = 2048.0 # Q6.11 divisor

W_fx, W_fh, b_f = 1.63, 2.70, 1.62
W_ix, W_ih, b_i = 1.65, 2.00, 0.62
W_gx, W_gh, b_g = 0.94, 1.41, -0.32
W_ox, W_oh, b_o = -0.19, 4.38, 0.59

# State Trackers
c_float, h_float = 0.0, 0.0
float_c_results = [0.0] # Row 0 is reset
float_h_results = [0.0]

# Process sequence (aligning hardware latency)
for i in range(len(df) - 1):
    x_val = df.loc[i, 'x_t'] / frac
    c_float, h_float = lstm_step(x_val, h_float, c_float,
                                W_fx, W_fh, b_f, W_ix, W_ih, b_i,
                                W_gx, W_gh, b_g, W_ox, W_oh, b_o)
    float_c_results.append(c_float)
    float_h_results.append(h_float)

# Add to dataframe
df['float_c_t'] = float_c_results
df['float_h_t'] = float_h_results
df['hw_c_float'] = df['c_t'] / frac
df['hw_h_float'] = df['h_t'] / frac

# Calculate Errors
df['diff_c'] = df['hw_c_float'] - df['float_c_t']
df['diff_h'] = df['hw_h_float'] - df['float_h_t']

# Output results
df.to_csv('hw_vs_float_comparison.csv', index=False)
print("Comparison saved to: hw_vs_float_comparison.csv")
print(df[['diff_c', 'diff_h']].describe())