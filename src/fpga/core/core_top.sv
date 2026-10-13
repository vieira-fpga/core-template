//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top
  import bridge_pkg::*;
(

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire logic clk_74a,  // mainclk1
    input wire logic clk_74b,  // mainclk1

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout wire logic [7:0] cart_tran_bank2,
    output wire logic cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout wire logic [7:0] cart_tran_bank3,
    output wire logic cart_tran_bank3_dir,

    // GBA A[23:16]
    inout wire logic [7:0] cart_tran_bank1,
    output wire logic cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout wire logic [7:4] cart_tran_bank0,
    output wire logic cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire logic cart_tran_pin30,
    output wire logic cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire logic cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire logic cart_tran_pin31,
    output wire logic cart_tran_pin31_dir,

    // infrared
    input  wire logic port_ir_rx,
    output wire logic port_ir_tx,
    output wire logic port_ir_rx_disable,

    // GBA link port
    inout  wire logic port_tran_si,
    output wire logic port_tran_si_dir,
    inout  wire logic port_tran_so,
    output wire logic port_tran_so_dir,
    inout  wire logic port_tran_sck,
    output wire logic port_tran_sck_dir,
    inout  wire logic port_tran_sd,
    output wire logic port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire logic [21:16] cram0_a,
    inout wire logic [15:0] cram0_dq,
    input wire logic cram0_wait,
    output wire logic cram0_clk,
    output wire logic cram0_adv_n,
    output wire logic cram0_cre,
    output wire logic cram0_ce0_n,
    output wire logic cram0_ce1_n,
    output wire logic cram0_oe_n,
    output wire logic cram0_we_n,
    output wire logic cram0_ub_n,
    output wire logic cram0_lb_n,

    output wire logic [21:16] cram1_a,
    inout wire logic [15:0] cram1_dq,
    input wire logic cram1_wait,
    output wire logic cram1_clk,
    output wire logic cram1_adv_n,
    output wire logic cram1_cre,
    output wire logic cram1_ce0_n,
    output wire logic cram1_ce1_n,
    output wire logic cram1_oe_n,
    output wire logic cram1_we_n,
    output wire logic cram1_ub_n,
    output wire logic cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire logic [12:0] dram_a,
    output wire logic [1:0] dram_ba,
    inout wire logic [15:0] dram_dq,
    output wire logic [1:0] dram_dqm,
    output wire logic dram_clk,
    output wire logic dram_cke,
    output wire logic dram_ras_n,
    output wire logic dram_cas_n,
    output wire logic dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire logic [16:0] sram_a,
    inout wire logic [15:0] sram_dq,
    output wire logic sram_oe_n,
    output wire logic sram_we_n,
    output wire logic sram_ub_n,
    output wire logic sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire logic vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire logic dbg_tx,
    input  wire logic dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire logic user1,
    input  wire logic user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout  wire logic aux_sda,
    output wire logic aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire logic vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire logic [23:0] video_rgb,
    output wire logic video_rgb_clock,
    output wire logic video_rgb_clock_90,
    output wire logic video_de,
    output wire logic video_skip,
    output wire logic video_vs,
    output wire logic video_hs,

    output wire logic audio_mclk,
    input  wire logic audio_adc,
    output wire logic audio_dac,
    output wire logic audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire logic bridge_endian_little,
    input wire logic [31:0] bridge_addr,
    input wire logic bridge_rd,
    output wire logic [31:0] bridge_rd_data,
    input wire logic bridge_wr,
    input wire logic [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    //
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    //   [31:28] type
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire logic [31:0] cont1_key,
    input wire logic [31:0] cont2_key,
    input wire logic [31:0] cont3_key,
    input wire logic [31:0] cont4_key,
    input wire logic [31:0] cont1_joy,
    input wire logic [31:0] cont2_joy,
    input wire logic [31:0] cont3_joy,
    input wire logic [31:0] cont4_joy,
    input wire logic [15:0] cont1_trig,
    input wire logic [15:0] cont2_trig,
    input wire logic [15:0] cont3_trig,
    input wire logic [15:0] cont4_trig

);

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx = 0;
  assign port_ir_rx_disable = 1;

  // bridge endianness
  assign bridge_endian_little = 0;

  // cart is unused, so set all level translators accordingly
  // directions are 0:IN, 1:OUT
  assign cart_tran_bank3 = 8'hzz;
  assign cart_tran_bank3_dir = 1'b0;
  assign cart_tran_bank2 = 8'hzz;
  assign cart_tran_bank2_dir = 1'b0;
  assign cart_tran_bank1 = 8'hzz;
  assign cart_tran_bank1_dir = 1'b0;
  assign cart_tran_bank0 = 4'hf;
  assign cart_tran_bank0_dir = 1'b1;
  assign cart_tran_pin30 = 1'b0;  // reset or cs2, we let the hw control it by itself
  assign cart_tran_pin30_dir = 1'bz;
  assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
  assign cart_tran_pin31 = 1'bz;  // input
  assign cart_tran_pin31_dir = 1'b0;  // input

  // link port is unused, set to input only to be safe
  // each bit may be bidirectional in some applications
  assign port_tran_so = 1'bz;
  assign port_tran_so_dir = 1'b0;  // SO is output only
  assign port_tran_si = 1'bz;
  assign port_tran_si_dir = 1'b0;  // SI is input only
  assign port_tran_sck = 1'bz;
  assign port_tran_sck_dir = 1'b0;  // clock direction can change
  assign port_tran_sd = 1'bz;
  assign port_tran_sd_dir = 1'b0;  // SD is input and not used

  // tie off the rest of the pins we are not using
  assign cram0_a = 'h0;
  assign cram0_dq = {16{1'bZ}};
  assign cram0_clk = 0;
  assign cram0_adv_n = 1;
  assign cram0_cre = 0;
  assign cram0_ce0_n = 1;
  assign cram0_ce1_n = 1;
  assign cram0_oe_n = 1;
  assign cram0_we_n = 1;
  assign cram0_ub_n = 1;
  assign cram0_lb_n = 1;

  assign cram1_a = 'h0;
  assign cram1_dq = {16{1'bZ}};
  assign cram1_clk = 0;
  assign cram1_adv_n = 1;
  assign cram1_cre = 0;
  assign cram1_ce0_n = 1;
  assign cram1_ce1_n = 1;
  assign cram1_oe_n = 1;
  assign cram1_we_n = 1;
  assign cram1_ub_n = 1;
  assign cram1_lb_n = 1;

  assign dram_a = 'h0;
  assign dram_ba = 'h0;
  assign dram_dq = {16{1'bZ}};
  assign dram_dqm = 'h0;
  assign dram_clk = 'h0;
  assign dram_cke = 'h0;
  assign dram_ras_n = 'h1;
  assign dram_cas_n = 'h1;
  assign dram_we_n = 'h1;

  assign sram_a = 'h0;
  assign sram_dq = {16{1'bZ}};
  assign sram_oe_n = 1;
  assign sram_we_n = 1;
  assign sram_ub_n = 1;
  assign sram_lb_n = 1;

  assign dbg_tx = 1'bZ;
  assign user1 = 1'bZ;
  assign aux_scl = 1'bZ;
  assign vpll_feed = 1'bZ;


  //
  // clocks and resets
  //
  wire logic reset_n;  // from host commands, synchronous to clk_74a
  wire logic clk_core_12288;
  wire logic clk_core_12288_90deg;
  wire logic pll_core_locked;  // synchronized to clk_74a
  wire logic reset_n_12288;  // reset_n for clk_core_12288 logic

  // Bridge outputs for clk_core_12288 logic. The demo video doesn't use them.
  wire logic dataslot_allcomplete_12288;
  wire logic osnotify_inmenu_12288;
  wire logic dataslot_update_12288;
  wire logic rtc_valid_12288;

  var dataslot_to_core_t dataslot_to_core;
  var rtc_osnotify_to_core_t rtc_osnotify_to_core;

  // Each pulse needs its own host command write, and bridge transactions are at least 88 clk_74a
  // cycles apart (apf/io_bridge_peripheral.v), so they meet the 25-cycle spacing core_clocks needs.
  core_clocks #(
      .LEVEL_WIDTH(2),
      .PULSE_WIDTH(2)
  ) clocks (
      .clk_74a,
      .reset_n,
      .clk_core_12288,
      .clk_core_12288_90deg,
      .pll_core_locked,
      .reset_n_12288,
      .level_74a  ({dataslot_to_core.allcomplete, rtc_osnotify_to_core.osnotify_inmenu}),
      .level_12288({dataslot_allcomplete_12288, osnotify_inmenu_12288}),
      .pulse_74a  ({dataslot_to_core.update, rtc_osnotify_to_core.rtc_valid}),
      .pulse_12288({dataslot_update_12288, rtc_valid_12288})
  );


  //
  // bridge: host and target commands, data slots, savestates, and the datatable
  // bridge_defaults answers for the parts this core doesn't use
  //
  var dataslot_from_core_t dataslot_from_core;
  var savestate_from_core_t savestate_from_core;
  var target_request_t target_request;
  var datatable_from_core_t datatable_from_core;

  bridge_defaults defaults (
      .dataslot_from_core,
      .savestate_from_core,
      .target_request,
      .datatable_from_core
  );

  core_bridge bridge (
      .clk(clk_74a),
      .reset_n,
      .bridge_endian_little,
      .bridge_addr,
      .bridge_rd,
      .bridge_rd_data,
      .bridge_wr,
      .bridge_wr_data,

      // Devices at 0x10xxxxxx go here. Register read data on user_rd and hold it until the next
      // user_rd, as bridge_map.sv describes.
      .user_rd(),
      .user_wr(),
      .user_rd_data('0),

      .status_boot_done(pll_core_locked),
      .status_setup_done(pll_core_locked),  // rising edge sends "ready to run"
      .status_running(reset_n),  // we are running as soon as reset_n goes high

      .dataslot_to_core,
      .dataslot_from_core,
      .savestate_to_core(),
      .savestate_from_core,
      .rtc_osnotify_to_core,
      .target_request,
      .target_response(),
      .datatable_from_core,
      .datatable_q()
  );



  ////////////////////////////////////////////////////////////////////////////////////////



  // video generation
  // ~12,288,000 hz pixel clock
  //
  // we want our video mode of 320x240 @ 60hz, this results in 204800 clocks per frame
  // we need to add hblank and vblank times to this, so there will be a nondisplay area.
  // it can be thought of as a border around the visible area.
  // to make numbers simple, we can have 400 total clocks per line, and 320 visible.
  // dividing 204800 by 400 results in 512 total lines per frame, and 240 visible.
  // this pixel clock is fairly high for the relatively low resolution, but that's fine.
  // PLL output has a minimum output frequency anyway.

  localparam logic [9:0] VID_V_BPORCH = 10'd10;
  localparam logic [9:0] VID_V_ACTIVE = 10'd240;
  localparam logic [9:0] VID_V_TOTAL  = 10'd512;
  localparam logic [9:0] VID_H_BPORCH = 10'd10;
  localparam logic [9:0] VID_H_ACTIVE = 10'd320;
  localparam logic [9:0] VID_H_TOTAL  = 10'd400;

  var logic  [15:0] frame_count;

  var logic  [ 9:0] x_count;
  var logic  [ 9:0] y_count;

  wire logic [ 9:0] visible_x = x_count - VID_H_BPORCH;
  wire logic [ 9:0] visible_y = y_count - VID_V_BPORCH;

  var logic  [23:0] vidout_rgb;
  var logic vidout_de, vidout_de_1;
  var logic vidout_skip;
  var logic vidout_vs;
  var logic vidout_hs, vidout_hs_1;

  var logic [9:0] square_x = 10'd135;
  var logic [9:0] square_y = 10'd95;

  assign video_rgb_clock = clk_core_12288;
  assign video_rgb_clock_90 = clk_core_12288_90deg;
  assign video_rgb = vidout_rgb;
  assign video_de = vidout_de;
  assign video_skip = vidout_skip;
  assign video_vs = vidout_vs;
  assign video_hs = vidout_hs;

  always_ff @(posedge clk_core_12288) begin
    // Every output defaults to idle, in reset too. Inactive screen areas are black.
    vidout_de   <= 0;
    vidout_skip <= 0;
    vidout_vs   <= 0;
    vidout_hs   <= 0;
    vidout_rgb  <= 24'h0;

    if (!reset_n_12288) begin

      x_count <= 0;
      y_count <= 0;

    end else begin
      vidout_hs_1 <= vidout_hs;
      vidout_de_1 <= vidout_de;

      // x and y counters
      x_count <= x_count + 1'b1;
      if (x_count == VID_H_TOTAL - 1) begin
        x_count <= 0;

        y_count <= y_count + 1'b1;
        if (y_count == VID_V_TOTAL - 1) begin
          y_count <= 0;
        end
      end

      // generate sync
      if (x_count == 0 && y_count == 0) begin
        // sync signal in back porch
        // new frame
        vidout_vs   <= 1;
        frame_count <= frame_count + 1'b1;
      end

      // we want HS to occur a bit after VS, not on the same cycle
      if (x_count == 3) begin
        // sync signal in back porch
        // new line
        vidout_hs <= 1;
      end

      // generate active video
      if (x_count >= VID_H_BPORCH && x_count < VID_H_ACTIVE + VID_H_BPORCH) begin

        if (y_count >= VID_V_BPORCH && y_count < VID_V_ACTIVE + VID_V_BPORCH) begin
          // data enable. this is the active region of the line
          vidout_de <= 1;

          vidout_rgb[23:16] <= 8'd60;
          vidout_rgb[15:8] <= 8'd60;
          vidout_rgb[7:0] <= 8'd60;

        end
      end
    end
  end




  //
  // audio: silence. sound_i2s sends signed 16-bit stereo samples from clk_core_12288 as 48 kHz
  // I2S. It runs on clk_74a and derives no clocks. Drive audio_l and audio_r with the core's sound.
  //
  sound_i2s #(
      .CHANNEL_WIDTH(16),
      .SIGNED_INPUT (1)
  ) audio (
      .clk_74a,
      .clk_audio(clk_core_12288),
      .audio_l  ('0),
      .audio_r  ('0),
      .audio_mclk,
      .audio_lrck,
      .audio_dac
  );
endmodule

`default_nettype wire
