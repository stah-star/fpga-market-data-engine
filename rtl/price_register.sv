// price_register.sv
// Day 1 module for the FPGA Market Data Processing Engine.
// Captures price_in into price_out on a rising clock edge when valid is high.
// Holds the last captured price when valid is low. Synchronous, active-high reset.

`timescale 1ns/1ps

module price_register #(
    parameter int PRICE_WIDTH = 32
) (
    input  logic                   clk,
    input  logic                   reset,
    input  logic                   valid,
    input  logic [PRICE_WIDTH-1:0] price_in,
    output logic [PRICE_WIDTH-1:0] price_out
);

    always_ff @(posedge clk) begin
        if (reset)
            price_out <= '0;
        else if (valid)
            price_out <= price_in;
        // else: hold previous value
    end

endmodule
