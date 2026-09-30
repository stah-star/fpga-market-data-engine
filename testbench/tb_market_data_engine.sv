// tb_market_data_engine.sv
// File-driven testbench for the full pipeline.
//   Reads : data/input_vectors.txt   (one line per clock: valid price quantity side)
//   Writes: results/rtl_output.csv   (one line per valid output)
// scripts/verify_results.py then compares rtl_output.csv to the Python golden model.
//
// Run from the repo root (scripts/run_all.py does this for you).
`timescale 1ns/1ps

module tb_market_data_engine;

    parameter int THRESHOLD = 20;
    localparam int MAX_TX   = 1_000_000;

    logic        clk = 0, reset;
    logic        in_valid, in_side;
    logic [31:0] in_price;
    logic [15:0] in_quantity;
    logic        out_valid, out_side;
    logic [31:0] out_price, out_avg;
    logic [1:0]  out_signal;
    logic [15:0] out_quantity;

    market_data_engine #(.THRESHOLD(THRESHOLD)) dut (.*);

    always #5 clk = ~clk;          // 100 MHz

    // cycle counter + record of when each valid input was presented (for latency)
    longint cycle = 0;
    always @(posedge clk) cycle <= cycle + 1;
    longint in_cycle [MAX_TX];
    int     n_in = 0, n_out = 0;
    longint lat, lat_min = 1 << 30, lat_max = 0;

    int fin, fout, code;
    int v, p, q, s;

    // Called at each negedge: log any output that came out of the pipeline.
    task automatic sample_output();
        if (out_valid) begin
            lat = cycle - in_cycle[n_out];
            if (lat < lat_min) lat_min = lat;
            if (lat > lat_max) lat_max = lat;
            $fdisplay(fout, "%0d,%0d,%0d,%0d,%0d,%0d", out_price, out_avg, out_signal,
                      out_quantity, out_side, lat);
            n_out++;
        end
    endtask

    initial begin
        fin = $fopen("data/input_vectors.txt", "r");
        if (fin == 0) begin
            $display("ERROR: cannot open data/input_vectors.txt (run scripts/generate_market_data.py first)");
            $finish;
        end
        fout = $fopen("results/rtl_output.csv", "w");
        if (fout == 0) begin
            $display("ERROR: cannot open results/rtl_output.csv (does the results/ folder exist?)");
            $finish;
        end
        $fdisplay(fout, "price,avg,signal,quantity,side,latency");

        reset = 1; in_valid = 0; in_price = 0; in_quantity = 0; in_side = 0;
        repeat (3) @(posedge clk);
        @(negedge clk) reset = 0;

        // one transaction per clock
        while (!$feof(fin)) begin
            code = $fscanf(fin, "%d %d %d %d\n", v, p, q, s);
            if (code == 4) begin
                @(negedge clk);
                sample_output();
                in_valid = v[0]; in_price = p; in_quantity = q; in_side = s[0];
                if (v[0]) begin in_cycle[n_in] = cycle; n_in++; end
            end
        end

        // drain the pipeline
        repeat (10) begin
            @(negedge clk);
            sample_output();
            in_valid = 0;
        end

        $fclose(fin);
        $fclose(fout);

        $display("==============================");
        $display("MARKET DATA ENGINE SIMULATION");
        $display("==============================");
        $display("Valid inputs sent   : %0d", n_in);
        $display("Outputs produced    : %0d", n_out);
        $display("Latency (cycles)    : min %0d, max %0d", lat_min, lat_max);
        $display("Wrote results/rtl_output.csv");
        if (n_in != n_out) $display("ERROR: input/output count mismatch");
        $finish;
    end

endmodule
