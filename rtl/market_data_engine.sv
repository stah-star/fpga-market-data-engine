// market_data_engine.sv
// Top level: 3-stage pipeline, accepts one transaction per clock.
//
//   market data -> [1] market_data_input -> [2] moving_average -> [3] signal_generator -> out
//
// Latency: 3 clock cycles. Throughput: 1 transaction per cycle.

`timescale 1ns/1ps

module market_data_engine #(
    parameter int PRICE_W     = 32,
    parameter int QTY_W       = 16,
    parameter int LOG2_WINDOW = 3,
    parameter int THRESHOLD   = 20
) (
    input  logic               clk,
    input  logic               reset,
    // input stream
    input  logic               in_valid,
    input  logic [PRICE_W-1:0] in_price,
    input  logic [QTY_W-1:0]   in_quantity,
    input  logic               in_side,
    // output stream
    output logic               out_valid,
    output logic [PRICE_W-1:0] out_price,
    output logic [PRICE_W-1:0] out_avg,
    output logic [1:0]         out_signal,   // 0 = HOLD, 1 = BUY, 2 = SELL
    output logic [QTY_W-1:0]   out_quantity,
    output logic               out_side
);

    // ---- Stage 1: input register ----
    logic               s1_valid, s1_side;
    logic [PRICE_W-1:0] s1_price;
    logic [QTY_W-1:0]   s1_qty;

    market_data_input #(.PRICE_W(PRICE_W), .QTY_W(QTY_W)) u_input (
        .clk(clk), .reset(reset),
        .valid(in_valid), .price_in(in_price), .quantity_in(in_quantity), .side_in(in_side),
        .price_out(s1_price), .quantity_out(s1_qty), .side_out(s1_side), .valid_out(s1_valid)
    );

    // ---- Stage 2: moving average ----
    logic               s2_valid, s2_full;
    logic [PRICE_W-1:0] s2_price, s2_avg;

    moving_average #(.PRICE_W(PRICE_W), .LOG2_WINDOW(LOG2_WINDOW)) u_avg (
        .clk(clk), .reset(reset),
        .in_valid(s1_valid), .in_price(s1_price),
        .out_valid(s2_valid), .out_price(s2_price), .out_avg(s2_avg), .out_full(s2_full)
    );

    // ---- Stage 3: signal ----
    signal_generator #(.PRICE_W(PRICE_W), .THRESHOLD(THRESHOLD)) u_signal (
        .clk(clk), .reset(reset),
        .in_valid(s2_valid), .in_price(s2_price), .in_avg(s2_avg), .in_full(s2_full),
        .out_valid(out_valid), .out_price(out_price), .out_avg(out_avg), .out_signal(out_signal)
    );

    // Carry quantity/side alongside the price so they stay aligned (2 more stages).
    logic [QTY_W-1:0] s2_qty;
    logic             s2_side;
    always_ff @(posedge clk) begin
        if (reset) begin
            s2_qty <= '0; s2_side <= 1'b0; out_quantity <= '0; out_side <= 1'b0;
        end else begin
            if (s1_valid) begin s2_qty <= s1_qty;  s2_side  <= s1_side; end
            if (s2_valid) begin out_quantity <= s2_qty; out_side <= s2_side; end
        end
    end

endmodule
