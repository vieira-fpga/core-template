#!/usr/bin/env bash
# Lints the RTL with Verilator, then builds each Verilator testbench and runs it with every start
# value: +verilator+rand+reset+0 (zeros), +1 (ones), and +2 (random), each with seeds 1 to 5. Run
# from src/fpga, where testbenches write their files to sim/build/:
#
#   sim/verilator.sh                  # lint and every testbench
#   sim/verilator.sh tb_demo_video    # lint and one testbench
#
# On Windows, run it from the MSYS2 UCRT64 shell. From another shell:
#
#   MSYSTEM=UCRT64 /c/msys64/usr/bin/bash -lc 'cd <repo>/src/fpga && sim/verilator.sh'
#
# Exits with the number of failed steps. Each run's log is in sim/build/verilator/.
#
# tb_core_clocks, tb_core_bridge, and tb_core_top run in Questa only (sim/run.do). They need
# Intel's simulation models of the PLL and the datatable RAM, from Quartus's altera_lnsim and
# altera_mf libraries, which CI doesn't have.
set -uo pipefail

build=sim/build/verilator
seeds=(1 2 3 4 5)
common=(--timescale 1ns/1ps)

# Our RTL, with the core's top last. Lint replaces vendor modules and Intel IP with the null
# modules in sim/lint/, so it reports only on our code. sim/verilator.vlt holds the few warnings
# lint turns off, each with its reason. PINCONNECTEMPTY is off everywhere: an output left
# unconnected by name, such as .rise(), is how the RTL says it doesn't use that output.
rtl=(
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
)
null_modules=(sim/lint/*.sv)

# The files each testbench builds from, testbench last.
declare -A sources=(
  [tb_sync_pulse]="apf/common.v core/sync_pulse.sv sim/tb_sync_pulse.sv"
  [tb_demo_video]="core/demo_video.sv sim/video_checker.sv sim/tb_demo_video.sv"
)
all_tests=(tb_sync_pulse tb_demo_video)
tests=("${@:-${all_tests[@]}}")

failed=0
rm -rf "$build"
mkdir -p "$build"

if verilator --lint-only -Wall -Wno-PINCONNECTEMPTY "${common[@]}" sim/verilator.vlt \
  "${rtl[@]}" "${null_modules[@]}" --top-module core_top >"$build/lint.log" 2>&1; then
  echo "PASS lint"
else
  cat "$build/lint.log"
  echo "FAIL lint"
  failed=$((failed + 1))
fi

for tb in "${tests[@]}"; do
  if [[ -z "${sources[$tb]:-}" ]]; then
    echo "FAIL $tb: not a Verilator testbench"
    failed=$((failed + 1))
    continue
  fi

  # apf/common.v is vendor code, so sim/verilator.vlt turns off lint warnings in it. Testbench
  # delays are never #0, which --no-sched-zero-delay tells Verilator.
  # shellcheck disable=SC2086
  if ! verilator --binary -j 0 --x-assign unique --no-sched-zero-delay "${common[@]}" \
    sim/verilator.vlt ${sources[$tb]} --top-module "$tb" --Mdir "$build/$tb" \
    >"$build/$tb.build.log" 2>&1; then
    cat "$build/$tb.build.log"
    echo "FAIL $tb: build"
    failed=$((failed + 1))
    continue
  fi

  runs=0
  bad=()
  for mode in 0 1 2; do
    for seed in "${seeds[@]}"; do
      log="$build/$tb.reset$mode.seed$seed.log"
      runs=$((runs + 1))
      if ! "$build/$tb/V$tb" "+verilator+rand+reset+$mode" "+verilator+seed+$seed" >"$log" 2>&1 \
        || ! grep -q "^SUMMARY" "$log"; then
        bad+=("reset$mode.seed$seed")
      fi
    done
  done

  if [[ ${#bad[@]} -eq 0 ]]; then
    echo "PASS $tb: $runs runs, $(grep -h "^SUMMARY" "$build/$tb.reset2.seed1.log")"
  else
    echo "FAIL $tb: ${#bad[@]} of $runs runs failed: ${bad[*]} (logs in $build/)"
    failed=$((failed + 1))
  fi
done

exit "$failed"
