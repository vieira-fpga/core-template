#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#

# The I2S silence generator in core_top.sv divides clk_74a in fabric. audgen_mclk toggles every 3
# or 4 clk_74a cycles, 12.288 MHz on average, so constrain it at its fastest: clk_74a / 6. SCLK is
# bit 1 of a counter on MCLK: MCLK / 4. apf_constraints.sdc and ap_core.qsf both load this file,
# so create the clocks once.
if {[get_collection_size [get_clocks -nowarn audio_mclk]] == 0} {
  create_generated_clock -name audio_mclk -source [get_ports clk_74a] -divide_by 6 \
   [get_registers {*|audgen_mclk}]
  create_generated_clock -name audio_sclk -source [get_registers {*|audgen_mclk}] -divide_by 4 \
   [get_registers {*|aud_mclk_divider[1]}]
}

# The PLL outputs in core_clocks.sv share a VCO, so they form one group whatever the instance
# path. Logic crosses between clk_74a and them only through the synchronizers in core_clocks.sv.
# No data passes between clk_74a and the audio clocks either. In one group, the analyzer times
# audgen_mclk feeding itself as an audio_mclk to clk_74a path and reports a false hold failure.
set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { audio_mclk audio_sclk } \
 -group { clk_74b } \
 -group [get_clocks {*|mf_pllbase_inst|altera_pll_i|general[*].gpll~PLL_OUTPUT_COUNTER|divclk}]
