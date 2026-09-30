// tb_moving_average.sv -- self-checking unit test for moving_average (window = 8)
`timescale 1ns/1ps

module tb_moving_average;

    logic        clk = 0, reset, in_valid;
    logic [31:0] in_price;
    logic        out_valid, out_full;
    logic [31:0] out_price, out_avg;
    int          errors = 0;

    moving_average #(.PRICE_W(32), .LOG2_WINDOW(3)) dut (.*);

    always #5 clk = ~clk;

    task automatic push(input logic v, input logic [31:0] p);
        @(negedge clk);
        in_valid = v; in_price = p;
        @(posedge clk); #1;
    endtask

    task automatic check(input string name, input logic [31:0] avg, input logic full, input logic v);
        if (out_avg === avg && out_full === full && out_valid === v)
            $display("%-34s PASS  (avg=%0d)", name, out_avg);
        else begin
            $display("%-34s FAIL  got avg=%0d full=%0b valid=%0b, expected avg=%0d full=%0b valid=%0b",
                     name, out_avg, out_full, out_valid, avg, full, v);
            errors++;
        end
    endtask

    initial begin
        $dumpfile("tb_moving_average.vcd");
        $dumpvars(0, tb_moving_average);
        $display("==============================");
        $display("MOVING AVERAGE TEST (window=8)");
        $display("==============================");

        reset = 1; in_valid = 0; in_price = 0;
        repeat (2) @(posedge clk);
        #1 reset = 0;
        check("Test 1: reset", 0, 0, 0);

        // 100,102,...,112 -> 7 samples, window not full yet
        for (int i = 0; i < 7; i++) push(1, 100 + 2*i);
        check("Test 2: 7 samples, not full", (100+102+104+106+108+110+112) >> 3, 0, 1);

        // 8th sample 114 -> sum 856, 856 >> 3 = 107
        push(1, 114);
        check("Test 3: 8 samples, avg=107", 107, 1, 1);

        // invalid cycle: average must not change
        push(0, 5000);
        check("Test 4: valid=0 holds avg", 107, 1, 0);

        // 9th sample 116 drops 100 -> (102..116) = 872 >> 3 = 109
        push(1, 116);
        check("Test 5: window slides, avg=109", 109, 1, 1);

        // truncation: add 117 -> drops 102 -> 887 >> 3 = 110 (110.875 truncated)
        push(1, 117);
        check("Test 6: shift truncates, avg=110", 110, 1, 1);

        if (errors == 0) $display("\nALL TESTS PASSED");
        else             $display("\n%0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
