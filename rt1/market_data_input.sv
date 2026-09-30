module market_data_input #(
  parameter int PRICE_WIDTH = 32,
  parameter int QTY_WIDTH = 16
) (
  input logic clk,
  input logic reset,
  input logic valid,
  input logic [PRICE_WIDTH-1:0] price_in,
  input logic [QTY_WIDTH-1:0] quantity_in,
  input logic side_in,
  output logic [PRICE_WIDTH-1:0] price_out,
  output logic [QTY_WIDTH-1:0] quantity_out,
  output logic side_out,
  output logic valid_out
);
  
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      price_out <= '0;
      quantity_out <= '0;
      side_out <= 1'b0;
      valid_out <= 1'b0;
      end else begin
        valid_out <= valid;
        if (valid) begin
          price_out <= price_in;
          quantity_out <= quantity_in;
          side_out <= side_in;
        end
      end
  end
  
endmodule

