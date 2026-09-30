// market_data_input.sv
// Pipeline stage 1: registers one market transaction per clock.
// Transaction fields update only when valid = 1; valid_out reports whether
// a transaction was accepted on the last clock edge.

`timescale 1ns/1ps

module market_data_input #(
    parameter int PRICE_W = 32,
    parameter int QTY_W   = 16
) (
    input  logic               clk,
    input  logic               reset,
    input  logic               valid,
    input  logic [PRICE_W-1:0] price_in,
    input  logic [QTY_W-1:0]   quantity_in,
    input  logic               side_in,      // 1 = BUY, 0 = SELL
    output logic [PRICE_W-1:0] price_out,
    output logic [QTY_W-1:0]   quantity_out,
    output logic               side_out,
    output logic               valid_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            price_out    <= '0;
            quantity_out <= '0;
            side_out     <= 1'b0;
            valid_out    <= 1'b0;
        end else begin
            valid_out <= valid;
            if (valid) begin
                price_out    <= price_in;
                quantity_out <= quantity_in;
                side_out     <= side_in;
            end
        end
    end

endmodule
