# Compiles the core and runs its testbenches in Questa. Run from src/fpga, so the datatable model
# finds ./apf/build_id.mif:
#
#   vsim -c -do sim/run.do
#   vsim -c -do "set tests tb_core_bridge; do sim/run.do"
#   vsim -c -do "set seed 7; do sim/run.do"
#
# Logs go to sim/build/. vsim exits with the number of failed testbenches.

if {![info exists tests]} {
  set tests {tb_sync_pulse tb_core_clocks tb_bridge_map tb_core_bridge tb_demo_video tb_core_top}
}
if {![info exists seed]} {
  set seed 1
}

set build sim/build
set work $build/work

# Vendor code compiles one file at a time, so a `default_nettype from one file can't leak into
# the next.
set vendor {
  apf/common.v
  apf/mf_datatable.v
  core/mf_pllbase.v
  core/mf_pllbase/mf_pllbase_0002.v
  core/vendor/analogue-pocket-utils/sync_fifo.sv
  core/vendor/analogue-pocket-utils/sound_i2s.sv
}

set core {
  core/bridge_pkg.sv
  core/bridge_map.sv
  core/host_cmd.sv
  core/dataslot_requests.sv
  core/savestate.sv
  core/rtc_osnotify.sv
  core/target_cmd.sv
  core/core_bridge.sv
  core/bridge_defaults.sv
  core/sync_pulse.sv
  core/core_clocks.sv
  core/demo_video.sv
  core/core_top.sv
  sim/apf_bridge_model.sv
  sim/video_checker.sv
  sim/tb_sync_pulse.sv
  sim/tb_core_clocks.sv
  sim/tb_bridge_map.sv
  sim/tb_core_bridge.sv
  sim/tb_demo_video.sv
  sim/tb_core_top.sv
}

onerror {echo "ERROR compile failed"; quit -code 1 -f}

file delete -force $build
file mkdir $build
vlib $work

foreach file $vendor {
  vlog -quiet -timescale 1ns/1ps -work $work $file
}
vlog -quiet -sv -timescale 1ns/1ps -work $work {*}$core

# Each testbench runs in its own vsim, so one that fails to load can't stop the others.
# It passes when it prints SUMMARY and its log has no error or fatal message.
set failed {}
foreach name $tests {
  set log $build/$name.log

  catch {
    exec vsim -c -quiet -onfinish stop -L altera_mf_ver -L altera_lnsim_ver -sv_seed $seed \
      -lib $work $name -do "run -all; quit -f" -l $log
  }

  set text ""
  if {[file exists $log]} {
    set handle [open $log]
    set text [read $handle]
    close $handle
  }

  if {![regexp {SUMMARY[^\n]*} $text summary] || [regexp {\*\* (Error|Fatal)} $text]} {
    lappend failed $name
    echo "FAIL $name (see $log)"
  } else {
    echo "PASS $summary"
  }
}

if {[llength $failed] != 0} {
  echo "ERROR [llength $failed] of [llength $tests] testbenches failed: $failed"
} else {
  echo "All [llength $tests] testbenches passed with seed $seed."
}
quit -code [llength $failed] -f
