module testbench;
  
  logic clk;
  logic reset;
  logic valid;
  logic [31:0] price_in;
  logic [15:0] quantity_in;
  logic side_in;
  
  logic [31:0] price_out;
  logic [15:0] quantity_out;
  logic side_out;
  logic valid_out;
  
  int errors = 0;
  
  market_data_input dut (
    .clk(clk),
    .reset(reset),
    .valid(valid),
    .price_in(price_in),
    .quantity_in(quantity_in),
    .side_in(side_in),
    .price_out(price_out),
    .quantity_out(quantity_out),
    .side_out(side_out),
    .valid_out(valid_out)
  );
  
  // 10ns clock
  always #5 clk = ~clk;
  
  task check(string test_name, logic [31:0] exp_price, logic [15:0] exp_qty, logic exp_side, logic exp_valid);
    if (price_out !== exp_price || quantity_out !== exp_qty || side_out !== exp_side || valid_out !== exp_valid) begin
      $display("Test %s: FAIL (price=%0d qty=%0d side=%0b valid=%0b)", test_name, price_out, quantity_out, side_out, valid_out);
      errors++;
      end else begin
        $display("Test %s: PASS", test_name);
      end
  endtask
  
  initial begin
    $display("==============================");
    $display("MARKET DATA INPUT TEST");
    $display("==============================");
    
    clk = 0;
    reset = 1;
    valid = 0;
    price_in = 32'd0;
    quantity_in = 16'd0;
    side_in = 1'b0;
    
    @(posedge clk);
    @(negedge clk);
    reset = 0;
    
    // Test 1: Reset
    @(negedge clk);
    check("1: RESET", 32'd0, 16'd0, 1'b0, 1'b0);
    
    // Test 2: BUY transaction
    price_in = 32'd18025;
    quantity_in = 16'd100;
    side_in = 1'b1;
    valid = 1'b1;
    @(negedge clk);
    check("2: BUY", 32'd18025, 16'd100, 1'b1, 1'b1);
    
    // Test 3: SELL transaction
    price_in = 32'd18050;
    quantity_in = 16'd200;
    side_in = 1'b0;
    valid = 1'b1;
    @(negedge clk);
    check("3: SELL", 32'd18050, 16'd200, 1'b0, 1'b1);
    
    // Test 4: Invalid cycle - data should hold, valid_out should drop
    price_in = 32'd99999;
    quantity_in = 16'd999;
    side_in = 1'b1;
    valid = 1'b0;
    @(negedge clk);
    check("4: INVALID", 32'd18050, 16'd200, 1'b0, 1'b0);
    
    // Test 5: Another valid BUY transaction
    price_in = 32'd18100;
    quantity_in = 16'd500;
    side_in = 1'b1;
    valid = 1'b1;
    @(negedge clk);
    check("5: BUY", 32'd18100, 16'd500, 1'b1, 1'b1);
    
    if (errors == 0)
      $display("ALL TESTS PASSED");
    else
      $display("TEST(S) FAILED");
    
    $finish;
  end
  
endmodule
