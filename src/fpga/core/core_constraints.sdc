#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#

# The PLL outputs in core_clocks.sv share a VCO, so they form one group whatever the instance
# path. Logic crosses between clk_74a and them only through the synchronizers in core_clocks.sv
# and the dual-clock FIFO in sound_i2s.
set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group [get_clocks {*|mf_pllbase_inst|altera_pll_i|general[*].gpll~PLL_OUTPUT_COUNTER|divclk}]
