// tb_price_register.sv
// Testbench for price_register.sv
//   Test 1: reset = 1                  -> price_out = 0
//   Test 2: valid = 1, price_in = 100  -> price_out = 100
//   Test 3: valid = 0, price_in = 200  -> price_out stays 100
//   Test 4: valid = 1, price_in = 105  -> price_out = 105

`timescale 1ns/1ps

module tb_price_register;

    localparam int PRICE_WIDTH = 32;

    logic                   clk;
    logic                   reset;
    logic                   valid;
    logic [PRICE_WIDTH-1:0] price_in;
    logic [PRICE_WIDTH-1:0] price_out;

    int errors = 0;

    // Device under test
    price_register #(.PRICE_WIDTH(PRICE_WIDTH)) dut (
        .clk      (clk),
        .reset    (reset),
        .valid    (valid),
        .price_in (price_in),
        .price_out(price_out)
    );

    // 100 MHz clock (10 ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Compare price_out to the expected value and report PASS/FAIL
    task automatic check(input string name, input logic [PRICE_WIDTH-1:0] expected);
        if (price_out === expected)
            $display("[PASS] %s: price_out = %0d", name, price_out);
        else begin
            $display("[FAIL] %s: price_out = %0d, expected %0d", name, price_out, expected);
            errors++;
        end
    endtask

    // Drive inputs, wait one rising edge, then let outputs settle
    task automatic apply(input logic r, input logic v, input logic [PRICE_WIDTH-1:0] p);
        reset    = r;
        valid    = v;
        price_in = p;
        @(posedge clk);
        #1;
    endtask

    initial begin
        $dumpfile("tb_price_register.vcd");
        $dumpvars(0, tb_price_register);

        // Start with a nonzero price so reset has something to clear
        reset = 0; valid = 1; price_in = 999;
        @(posedge clk); #1;

        // Test 1: reset
        apply(1'b1, 1'b0, '0);
        check("Test 1 (reset)", 0);

        // Test 2: valid price is captured
        apply(1'b0, 1'b1, 100);
        check("Test 2 (valid=1, price_in=100)", 100);

        // Test 3: invalid price is ignored
        apply(1'b0, 1'b0, 200);
        check("Test 3 (valid=0, price_in=200)", 100);

        // Test 4: new valid price is captured
        apply(1'b0, 1'b1, 105);
        check("Test 4 (valid=1, price_in=105)", 105);

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
