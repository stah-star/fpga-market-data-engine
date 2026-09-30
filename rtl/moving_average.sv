// moving_average.sv
// Pipeline stage 2: rolling average of the last WINDOW valid prices.
//
// Hardware choices:
//   * WINDOW is a power of two (default 8), so "divide by 8" is a right
//     shift by 3 -- no divider needed.
//   * A running sum is kept: sum_new = sum + newest - oldest. That is one
//     add and one subtract per sample instead of re-adding all 8 prices.
//   * out_full goes high once WINDOW samples have arrived; before that the
//     average still includes the reset zeros and should not be trusted.

`timescale 1ns/1ps

module moving_average #(
    parameter int PRICE_W     = 32,
    parameter int LOG2_WINDOW = 3            // window = 2**3 = 8 samples
) (
    input  logic               clk,
    input  logic               reset,
    input  logic               in_valid,
    input  logic [PRICE_W-1:0] in_price,
    output logic               out_valid,
    output logic [PRICE_W-1:0] out_price,   // price this average belongs to
    output logic [PRICE_W-1:0] out_avg,
    output logic               out_full     // window has WINDOW samples
);

    localparam int WINDOW = 1 << LOG2_WINDOW;
    localparam int SUM_W  = PRICE_W + LOG2_WINDOW;   // wide enough, no overflow

    logic [PRICE_W-1:0] window_buf [WINDOW];          // [0] newest, [WINDOW-1] oldest
    logic [SUM_W-1:0]   sum;
    logic [SUM_W-1:0]   sum_next;
    logic [LOG2_WINDOW:0] count;                      // saturates at WINDOW

    assign sum_next = sum
                    + {{LOG2_WINDOW{1'b0}}, in_price}
                    - {{LOG2_WINDOW{1'b0}}, window_buf[WINDOW-1]};

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < WINDOW; i++) window_buf[i] <= '0;
            sum       <= '0;
            count     <= '0;
            out_valid <= 1'b0;
            out_price <= '0;
            out_avg   <= '0;
            out_full  <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                // shift register of recent prices
                window_buf[0] <= in_price;
                for (int i = 1; i < WINDOW; i++) window_buf[i] <= window_buf[i-1];

                sum       <= sum_next;
                if (count != WINDOW) count <= count + 1'b1;

                out_price <= in_price;
                out_avg   <= sum_next[SUM_W-1:LOG2_WINDOW];   // sum >> LOG2_WINDOW
                out_full  <= (count >= WINDOW - 1);
            end
        end
    end

endmodule
