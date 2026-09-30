// tb_market_data_input.sv -- self-checking unit test for market_data_input
`timescale 1ns/1ps

module tb_market_data_input;

    logic        clk = 0, reset, valid, side_in;
    logic [31:0] price_in;
    logic [15:0] quantity_in;
    logic [31:0] price_out;
    logic [15:0] quantity_out;
    logic        side_out, valid_out;
    int          errors = 0;

    market_data_input dut (.*);

    always #5 clk = ~clk;

    task automatic send(input logic r, v, input logic [31:0] p, input logic [15:0] q, input logic s);
        @(negedge clk);
        reset = r; valid = v; price_in = p; quantity_in = q; side_in = s;
        @(posedge clk); #1;
    endtask

    task automatic check(input string name, input logic [31:0] p, input logic [15:0] q,
                         input logic s, input logic v);
        if (price_out === p && quantity_out === q && side_out === s && valid_out === v)
            $display("%-22s PASS", name);
        else begin
            $display("%-22s FAIL  got p=%0d q=%0d s=%0b v=%0b  expected p=%0d q=%0d s=%0b v=%0b",
                     name, price_out, quantity_out, side_out, valid_out, p, q, s, v);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("tb_market_data_input.vcd");
        $dumpvars(0, tb_market_data_input);
        $display("==============================");
        $display("MARKET DATA INPUT TEST");
        $display("==============================");

        send(1, 0, 0, 0, 0);            check("Test 1: RESET",   0,     0,   0, 0);
        send(0, 1, 18025, 100, 1);      check("Test 2: BUY",     18025, 100, 1, 1);
        send(0, 1, 18050, 200, 0);      check("Test 3: SELL",    18050, 200, 0, 1);
        send(0, 0, 99999, 999, 1);      check("Test 4: INVALID", 18050, 200, 0, 0);
        send(0, 1, 18100, 500, 1);      check("Test 5: BUY",     18100, 500, 1, 1);

        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
