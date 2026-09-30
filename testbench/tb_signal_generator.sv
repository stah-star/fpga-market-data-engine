// tb_signal_generator.sv -- self-checking unit test for signal_generator (THRESHOLD = 20)
`timescale 1ns/1ps

module tb_signal_generator;

    localparam logic [1:0] HOLD = 0, BUY = 1, SELL = 2;

    logic        clk = 0, reset, in_valid, in_full;
    logic [31:0] in_price, in_avg;
    logic        out_valid;
    logic [31:0] out_price, out_avg;
    logic [1:0]  out_signal;
    int          errors = 0;

    signal_generator #(.PRICE_W(32), .THRESHOLD(20)) dut (.*);

    always #5 clk = ~clk;

    function automatic string name_of(input logic [1:0] s);
        return (s == BUY) ? "BUY" : (s == SELL) ? "SELL" : "HOLD";
    endfunction

    task automatic run(input string name, input logic full, input logic [31:0] price, avg,
                       input logic [1:0] expected);
        @(negedge clk);
        in_valid = 1; in_full = full; in_price = price; in_avg = avg;
        @(posedge clk); #1;
        if (out_signal === expected && out_valid === 1'b1)
            $display("%-36s PASS  (%s)", name, name_of(out_signal));
        else begin
            $display("%-36s FAIL  got %s, expected %s", name, name_of(out_signal), name_of(expected));
            errors++;
        end
    endtask

    initial begin
        $display("==============================");
        $display("SIGNAL GENERATOR TEST (TH=20)");
        $display("==============================");
        reset = 1; in_valid = 0; in_full = 0; in_price = 0; in_avg = 0;
        repeat (2) @(posedge clk);
        #1 reset = 0;

        run("Test 1: window not full -> HOLD", 0, 500, 100, HOLD);
        run("Test 2: price 150, avg 100 -> BUY",  1, 150, 100, BUY);
        run("Test 3: price 50, avg 100 -> SELL",  1,  50, 100, SELL);
        run("Test 4: price 110, avg 100 -> HOLD", 1, 110, 100, HOLD);
        run("Test 5: exactly +20 -> HOLD",        1, 120, 100, HOLD);
        run("Test 6: +21 -> BUY",                 1, 121, 100, BUY);
        run("Test 7: exactly -20 -> HOLD",        1,  80, 100, HOLD);
        run("Test 8: -21 -> SELL",                1,  79, 100, SELL);
        run("Test 9: small price, no underflow",  1,   5,  10, HOLD);

        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
