`default_nettype none

// Tests sync_pulse from clk_74a to clk_core_12288, the crossing core_clocks uses, with the
// destination clock at a seeded random phase. Every event must arrive exactly once, as a
// one-cycle pulse, including events at the minimum spacing of 4 destination cycles.
module tb_sync_pulse;
  timeunit 1ns; timeprecision 1ps;

  localparam int unsigned EVENTS = 500;
  localparam int unsigned MIN_SPACING = 25;  // clk_74a cycles, just over 4 clk_core_12288 cycles

  var logic clk_src;
  var logic clk_dst;
  var logic pulse_src = 1'b0;
  wire logic pulse_dst;

  // Pulses count once the synchronizer has flushed its start values. Registers power up at 0 on
  // the FPGA, but Verilator can start synch_3 with any value, which makes a pulse.
  logic counting = 1'b0;
  int unsigned received = 0;
  int unsigned long_pulses = 0;
  logic pulse_dst_q = 1'b0;

  sync_pulse dut (
      .clk_src,
      .pulse_src,
      .clk_dst,
      .pulse_dst
  );

  initial begin
    clk_src <= 1'b0;
    forever begin
      #6.734ns clk_src <= ~clk_src;
    end
  end

  initial begin
    clk_dst <= 1'b0;
    #($urandom_range(1, 80_000) * 1ps);
    forever begin
      #40.690ns clk_dst <= ~clk_dst;
    end
  end

  always @(posedge clk_dst) begin
    pulse_dst_q <= pulse_dst === 1'b1;
    if (counting && pulse_dst === 1'b1) begin
      received++;
      if (pulse_dst_q) begin
        long_pulses++;
      end
    end
  end

  initial begin
    // Let the synchronizer flush its power-up state.
    repeat (10) @(posedge clk_dst);
    counting = 1'b1;

    for (int i = 0; i < EVENTS; i++) begin
      @(posedge clk_src);
      pulse_src <= 1'b1;
      @(posedge clk_src);
      pulse_src <= 1'b0;
      repeat ((i % 4 == 0 ? MIN_SPACING : $urandom_range(MIN_SPACING, 80)) - 1) @(posedge clk_src);
    end
    repeat (10) @(posedge clk_dst);

    $display("SUMMARY tb_sync_pulse checks=2 errors=%0d",
             int'(received != EVENTS) + int'(long_pulses != 0));
    if (received != EVENTS) begin
      $error("ERROR events: sent %0d, received %0d", EVENTS, received);
    end
    if (long_pulses != 0) begin
      $error("ERROR pulse_width: %0d pulses lasted more than one cycle", long_pulses);
    end
    if (received != EVENTS || long_pulses != 0) begin
      $fatal(1, "tb_sync_pulse failed");
    end
    $finish;
  end
endmodule

`default_nettype wire
