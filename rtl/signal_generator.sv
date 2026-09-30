// signal_generator.sv
// Pipeline stage 3: compares price to its moving average.
//   price > avg + THRESHOLD  -> BUY
//   price < avg - THRESHOLD  -> SELL
//   otherwise                -> HOLD
// Outputs HOLD until the moving-average window is full.

`timescale 1ns/1ps

module signal_generator #(
    parameter int PRICE_W   = 32,
    parameter int THRESHOLD = 20
) (
    input  logic               clk,
    input  logic               reset,
    input  logic               in_valid,
    input  logic [PRICE_W-1:0] in_price,
    input  logic [PRICE_W-1:0] in_avg,
    input  logic               in_full,
    output logic               out_valid,
    output logic [PRICE_W-1:0] out_price,
    output logic [PRICE_W-1:0] out_avg,
    output logic [1:0]         out_signal
);

    localparam logic [1:0] HOLD = 2'd0;
    localparam logic [1:0] BUY  = 2'd1;
    localparam logic [1:0] SELL = 2'd2;

    // One extra bit so "avg + THRESHOLD" can never overflow.
    // Written as "price + TH < avg" instead of "price < avg - TH" to avoid
    // unsigned underflow.
    logic [PRICE_W:0] price_ext, avg_ext, th_ext;
    assign price_ext = {1'b0, in_price};
    assign avg_ext   = {1'b0, in_avg};
    assign th_ext    = THRESHOLD;

    always_ff @(posedge clk) begin
        if (reset) begin
            out_valid  <= 1'b0;
            out_price  <= '0;
            out_avg    <= '0;
            out_signal <= HOLD;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                out_price <= in_price;
                out_avg   <= in_avg;
                if (!in_full)                          out_signal <= HOLD;
                else if (price_ext > avg_ext + th_ext) out_signal <= BUY;
                else if (price_ext + th_ext < avg_ext) out_signal <= SELL;
                else                                   out_signal <= HOLD;
            end
        end
    end

endmodule
