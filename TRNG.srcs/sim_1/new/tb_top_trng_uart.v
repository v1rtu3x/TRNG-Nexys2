`timescale 1ns/1ps

module tb_top_trng_uart;

  // ------------------------------------------------------------
  // Parameters (match DUT)
  // ------------------------------------------------------------
  localparam integer BAUD          = 115200;
  localparam integer CLK_PERIOD_NS = 20;                  // 50MHz
  localparam integer BIT_TIME_NS   = 1000000000 / BAUD;   // ~8680ns

  // For forcing entropy: choose a period that is NOT a multiple of 20ns
  // so it "slides" relative to the clk (gives better variation)
  localparam integer ENTROPY_STEP_NS = 17;

  // ------------------------------------------------------------
  // DUT signals
  // ------------------------------------------------------------
  reg  clk_50mhz;
  reg  rst_n;
  wire uart_tx;

  top_trng_uart dut (
    .clk_50mhz(clk_50mhz),
    .rst_n    (rst_n),
    .uart_tx  (uart_tx)
  );

  // ------------------------------------------------------------
  // Clock generation
  // ------------------------------------------------------------
  initial begin
    clk_50mhz = 1'b0;
    forever #(CLK_PERIOD_NS/2) clk_50mhz = ~clk_50mhz;
  end

  // ------------------------------------------------------------
  // Reset
  // ------------------------------------------------------------
  initial begin
    rst_n = 1'b0;
    repeat (50) @(posedge clk_50mhz);
    rst_n = 1'b1;
  end

  // ------------------------------------------------------------
  // ENTROPY INJECTION via force (Verilog, ISim-friendly)
  // ------------------------------------------------------------
  reg forced_entropy;
  reg [31:0] lfsr;

  initial begin
    forced_entropy = 1'b0;
    lfsr = 32'h1ACE_B00C;

    @(posedge rst_n);

    // Force the internal entropy_raw signal
    // If this path doesn't match your hierarchy, ISim will error.
    force dut.u_entropy.entropy_raw = forced_entropy;

    forever begin
      // LFSR step (taps)
      lfsr = {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
      forced_entropy = lfsr[0];

      // Fixed delay (ISim-safe)
      #ENTROPY_STEP_NS;
    end
  end

  // ------------------------------------------------------------
  // Expected byte queue (ring buffer)
  // Capture dut.tx_data whenever dut.tx_start pulses
  // ------------------------------------------------------------
  reg [7:0] exp_mem [0:1023];
  integer exp_wr, exp_rd, exp_count;

  initial begin
    exp_wr = 0;
    exp_rd = 0;
    exp_count = 0;
  end

  always @(posedge clk_50mhz) begin
    if (!rst_n) begin
      exp_wr    <= 0;
      exp_rd    <= 0;
      exp_count <= 0;
    end else begin
      // If your signals are named differently, change these two:
      if (dut.tx_start) begin
        exp_mem[exp_wr] <= dut.tx_data;
        exp_wr <= (exp_wr + 1) & 1023;
        if (exp_count < 1024) exp_count <= exp_count + 1;
      end
    end
  end

  // ------------------------------------------------------------
  // UART RX model (8N1, LSB-first)
  // ------------------------------------------------------------
  task uart_rx_one_byte;
    output [7:0] b;
    integer i;
    begin
      b = 8'h00;

      // Wait for start bit
      @(negedge uart_tx);

      // sample in the middle of the first data bit
      #(BIT_TIME_NS + (BIT_TIME_NS/2));

      // 8 data bits
      for (i = 0; i < 8; i = i + 1) begin
        b[i] = uart_tx;
        #(BIT_TIME_NS);
      end

      // stop bit should be high
      if (uart_tx !== 1'b1) begin
        $display("[%0t] ERROR: stop bit not high", $time);
      end

      #(BIT_TIME_NS);
    end
  endtask

  // ------------------------------------------------------------
  // Test loop: receive bytes and compare to expected
  // ------------------------------------------------------------
  integer n;
  integer mismatches;
  reg [7:0] rx_b;
  reg [7:0] exp_b;

  initial begin
    mismatches = 0;

    @(posedge rst_n);

    // Wait for idle-high
    wait (uart_tx == 1'b1);

    // Receive and check 50 bytes
    for (n = 0; n < 50; n = n + 1) begin
      uart_rx_one_byte(rx_b);

      if (exp_count == 0) begin
        $display("[%0t] ERROR: got %02x but expected queue empty", $time, rx_b);
        mismatches = mismatches + 1;
      end else begin
        exp_b = exp_mem[exp_rd];
        exp_rd = (exp_rd + 1) & 1023;
        exp_count = exp_count - 1;

        if (rx_b !== exp_b) begin
          $display("[%0t] MISMATCH: got %02x expected %02x", $time, rx_b, exp_b);
          mismatches = mismatches + 1;
        end else begin
          $display("[%0t] OK: %02x", $time, rx_b);
        end
      end
    end

    $display("--------------------------------------------------");
    $display("Done. Mismatches = %0d", mismatches);
    if (mismatches == 0) $display("PASS");
    else                 $display("FAIL");

    release dut.u_entropy.entropy_raw;
    $finish;
  end

  // ------------------------------------------------------------
  // Timeout safety (give it plenty of time)
  // 50 frames * ~87us = 4.35ms, plus TRNG/queue effects -> use 50ms
  // ------------------------------------------------------------
  initial begin
    #(50_000_000); // 50 ms in ns
    $display("[%0t] TIMEOUT (50ms) - check force path / tx_start activity", $time);
    $finish;
  end

endmodule
