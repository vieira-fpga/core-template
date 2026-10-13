`default_nettype none

// Tests bridge_map: which region each address reaches, that a read returns the data of the
// region it strobed even when the next transaction is elsewhere, and the endian swap. The
// testbench plays the devices: each APF region returns a tag and the bus addr, and the user region
// answers 10 cycles after user_rd, like a slow memory.
module tb_bridge_map;
  timeunit 1ns; timeprecision 1ps;

  import bridge_pkg::*;

  localparam int unsigned WATCHDOG_CYCLES = 200_000;
  localparam int unsigned USER_LATENCY = 10;

  var logic clk;
  var logic bridge_endian_little = 1'b0;

  wire logic [31:0] bridge_addr;
  wire logic bridge_rd;
  wire logic [31:0] bridge_rd_data;
  wire logic bridge_wr;
  wire logic [31:0] bridge_wr_data;

  wire logic user_rd;
  wire logic user_wr;
  var logic [31:0] user_rd_data = '0;
  var apf_bus_t host_bus;
  var apf_bus_t target_bus;
  var apf_bus_t datatable_bus;

  int unsigned checks = 0;
  int unsigned errors = 0;

  bridge_map dut (
      .clk,
      .bridge_endian_little,
      .bridge_addr,
      .bridge_rd,
      .bridge_rd_data,
      .bridge_wr,
      .bridge_wr_data,
      .user_rd,
      .user_wr,
      .user_rd_data,
      .host_bus,
      .host_rd_data({8'hA1, 16'h0, host_bus.addr}),
      .target_bus,
      .target_rd_data({8'hB2, 16'h0, target_bus.addr}),
      .datatable_bus,
      .datatable_rd_data({8'hC3, 16'h0, datatable_bus.addr})
  );

  apf_bridge_model host (
      .clk,
      .bridge_addr,
      .bridge_rd,
      .bridge_rd_data,
      .bridge_wr,
      .bridge_wr_data
  );

  initial begin
    clk <= 1'b0;
    forever begin
      #6.734ns clk <= ~clk;
    end
  end

  initial begin
    repeat (WATCHDOG_CYCLES) @(posedge clk);
    $fatal(1, "ERROR watchdog: test did not finish in %0d cycles", WATCHDOG_CYCLES);
  end

  // The user device: latches the address on user_rd and answers USER_LATENCY cycles later.
  initial begin
    forever begin
      logic [31:0] addr;

      @(posedge clk iff user_rd);
      addr = bridge_addr;
      repeat (USER_LATENCY) @(posedge clk);
      user_rd_data <= {8'hD4, addr[23:0]};
    end
  end

  // Strobes seen since the last clear_strobes(), per region.
  int unsigned rd_count[bridge_region_t] = '{
      REGION_USER: 0,
      REGION_HOST: 0,
      REGION_TARGET: 0,
      REGION_DATATABLE: 0
  };
  int unsigned wr_count[bridge_region_t] = '{
      REGION_USER: 0,
      REGION_HOST: 0,
      REGION_TARGET: 0,
      REGION_DATATABLE: 0
  };
  logic [7:0] last_addr;
  logic [31:0] last_wr_data;

  task automatic clear_strobes();
    rd_count = '{REGION_USER: 0, REGION_HOST: 0, REGION_TARGET: 0, REGION_DATATABLE: 0};
    wr_count = '{REGION_USER: 0, REGION_HOST: 0, REGION_TARGET: 0, REGION_DATATABLE: 0};
  endtask

  always @(posedge clk) begin
    rd_count[REGION_USER] += user_rd;
    wr_count[REGION_USER] += user_wr;
    rd_count[REGION_HOST] += host_bus.rd;
    wr_count[REGION_HOST] += host_bus.wr;
    rd_count[REGION_TARGET] += target_bus.rd;
    wr_count[REGION_TARGET] += target_bus.wr;
    rd_count[REGION_DATATABLE] += datatable_bus.rd;
    wr_count[REGION_DATATABLE] += datatable_bus.wr;

    if (host_bus.wr) begin
      last_addr <= host_bus.addr;
      last_wr_data <= host_bus.wr_data;
    end
    if (target_bus.wr) begin
      last_addr <= target_bus.addr;
      last_wr_data <= target_bus.wr_data;
    end
    if (datatable_bus.wr) begin
      last_addr <= datatable_bus.addr;
      last_wr_data <= datatable_bus.wr_data;
    end
  end

  task automatic check(input string name, input logic ok, input string detail);
    checks++;
    if (!ok) begin
      errors++;
      $error("ERROR %s: %s", name, detail);
    end
  endtask

  // The data the testbench's device in region returns for addr.
  function automatic logic [31:0] device_data(input bridge_region_t region,
                                              input logic [31:0] addr);
    unique case (region)
      REGION_USER: return {8'hD4, addr[23:0]};
      REGION_HOST: return {8'hA1, 16'h0, addr[7:0]};
      REGION_TARGET: return {8'hB2, 16'h0, addr[7:0]};
      REGION_DATATABLE: return {8'hC3, 16'h0, addr[9:2]};
      default: return '0;
    endcase
  endfunction

  // Writes and reads addr, and checks that only region's strobes fired, once each.
  task automatic check_decode(input logic [31:0] addr, input bridge_region_t region);
    string name;
    logic [31:0] data;
    logic [7:0] offset;

    name   = $sformatf("decode_%08h", addr);
    offset = region == REGION_DATATABLE ? addr[9:2] : addr[7:0];

    clear_strobes();
    host.write_word(addr, 32'h1234_5678);
    host.read_word(addr, data);

    foreach (wr_count[r]) begin
      check(name, wr_count[r] == (r == region ? 1 : 0), $sformatf(
            "%s got %0d writes", r.name(), wr_count[r]));
      check(name, rd_count[r] == (r == region ? 2 : 0), $sformatf(
            "%s got %0d reads", r.name(), rd_count[r]));
    end
    if (region != REGION_NONE && region != REGION_USER) begin
      check(name, last_addr == offset && last_wr_data == 32'h1234_5678, $sformatf(
            "bus addr %02h data %08h", last_addr, last_wr_data));
    end
    check(name, data == device_data(region, addr), $sformatf(
          "read %08h, expected %08h", data, device_data(region, addr)));
  endtask

  task automatic check_cross_region(input logic [31:0] addr, input bridge_region_t region,
                                    input logic [31:0] next_addr);
    logic [31:0] data;

    host.read_word(addr, data, next_addr);
    check($sformatf("cross_%08h_then_%08h", addr, next_addr), data == device_data(region, addr),
          $sformatf("read %08h, expected %08h", data, device_data(region, addr)));
  endtask

  initial begin
    logic [31:0] data;

    repeat (10) @(posedge clk);

    check_decode(32'h1000_0000, REGION_USER);
    check_decode(32'h10FF_FFFC, REGION_USER);
    check_decode(32'hF800_0000, REGION_HOST);
    check_decode(32'hF800_004C, REGION_HOST);
    check_decode(32'hF8FF_0020, REGION_HOST);
    check_decode(32'hF800_1000, REGION_TARGET);
    check_decode(32'hF800_102C, REGION_TARGET);
    check_decode(32'hF800_2000, REGION_DATATABLE);
    check_decode(32'hF800_23FC, REGION_DATATABLE);
    check_decode(32'hF800_2400, REGION_NONE);
    check_decode(32'hF800_2FFC, REGION_NONE);
    check_decode(32'hF800_0100, REGION_NONE);
    check_decode(32'hF800_3000, REGION_NONE);
    check_decode(32'h2000_0000, REGION_NONE);
    check_decode(32'h0000_0000, REGION_NONE);

    // A read returns its own region's data while the next transaction addresses another region.
    check_cross_region(32'hF800_0040, REGION_HOST, 32'h1000_0100);
    check_cross_region(32'h1000_0200, REGION_USER, 32'hF800_0000);
    check_cross_region(32'hF800_2010, REGION_DATATABLE, 32'hF800_1000);
    check_cross_region(32'hF800_1004, REGION_TARGET, 32'h3000_0000);

    // Little endian: the APF regions see swapped bytes both ways. The user region doesn't.
    bridge_endian_little <= 1'b1;
    host.write_word(32'hF800_0020, 32'h1122_3344);
    check("endian_write_swapped", last_wr_data == 32'h4433_2211, $sformatf(
          "host bus saw %08h", last_wr_data));
    host.read_word(32'hF800_0044, data);
    check("endian_read_swapped", data == 32'h4400_00A1, $sformatf("read %08h", data));
    host.read_word(32'h1000_0300, data);
    check("endian_user_unswapped", data == 32'hD400_0300, $sformatf("read %08h", data));

    $display("SUMMARY tb_bridge_map checks=%0d errors=%0d", checks, errors);
    if (errors != 0) begin
      $fatal(1, "tb_bridge_map failed");
    end
    $finish;
  end
endmodule

`default_nettype wire
