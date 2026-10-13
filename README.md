# Core template

LLMs wrote most of the SystemVerilog, testbenches, and scripts that this repository adds to Analogue's template. Claude Opus 5.5 in Claude Code, run through T3 Code, wrote the changes from the Quartus 25.1std migration onward. The model and harness behind the earlier commits that split the bridge by concept, set up Verible, and idled the video in reset still need to be named here.

This is an Analogue Pocket openFPGA core that shows a gray 320x240 screen. It answers APF over the bridge and is a starting point for new cores. This version has run only in simulation, not on a Pocket.

## Build the core

You need Quartus Prime Lite or Standard 25.1std with Cyclone V support.

To compile the core and write `output/bitstream.rbf_r`, run the build script from the repository root:

```powershell
./build.ps1
```

If Quartus isn't in `C:\altera_lite\25.1std`, pass its `bin64` folder with `-QuartusBin`. The script stops when the compile fails. The timing and fit reports are in `src/fpga/output_files/`.

## Test the core

Run every command from `src/fpga`.

Questa runs all five testbenches. Set `SALT_LICENSE_SERVER` to your Questa license file first:

```powershell
vsim -c -do sim/run.do
```

Verilator lints the RTL and runs `tb_sync_pulse` and `tb_demo_video` with zeros, ones, and random start values. On Windows, run it from the MSYS2 UCRT64 shell:

```sh
sim/verilator.sh
```

Verible formats and lints our SystemVerilog. It never touches vendor code:

```sh
verible-verilog-format --verify --inplace core/*.sv sim/*.sv sim/lint/*.sv
verible-verilog-lint --rules_config_search core/*.sv sim/*.sv sim/lint/*.sv
```

The GitHub Actions workflow in `.github/workflows/` runs Verible and Verilator on each push and pull request. Questa needs a license, so it doesn't run in CI.

## Find your way around

- `src/fpga/core/core_top.sv` connects the core to APF: the pins, the bridge, video, and audio.
- `src/fpga/core/demo_video.sv` draws the gray screen. It uses no openFPGA signals. Replace it with the core's own logic.
- `src/fpga/core/core_bridge.sv` and the modules it instantiates answer APF's host commands and send target commands. `GLOSSARY.md` defines the bridge terms.
- `src/fpga/core/core_clocks.sv` holds the PLL, the reset for the core clock, and the clock domain crossings.
- `src/fpga/sim/` holds the testbenches and the simulation scripts.
- `src/fpga/apf/` is Analogue's framework, and `src/fpga/core/vendor/` holds modules from other projects. Don't edit either.

## Credits

- [Analogue](https://www.analogue.co/developer) wrote [`open-fpga/core-template`](https://github.com/open-fpga/core-template), which this repository starts from, and the APF framework in `src/fpga/apf/`.
- Adam Gastineau wrote `sound_i2s.sv` and `sync_fifo.sv`, from [`agg23/analogue-pocket-utils`](https://github.com/agg23/analogue-pocket-utils) at commit 598c753, under the MIT license. The copy in `src/fpga/core/vendor/analogue-pocket-utils/` declares two signals before their first use, so Questa accepts it. His [analogue-pocket-utils wiki](https://github.com/agg23/analogue-pocket-utils/wiki) documents parts of the Pocket that Analogue's docs leave out.
- Intel's Quartus parameter editor generated the PLL in `src/fpga/core/mf_pllbase*`.
- Didier Malenfant's [openFPGA tutorials](https://code.malenfant.net/didier/openFPGA-tutorials) set the rules this core follows for resets, clocks, and `initial` blocks.
- Will Green's [Project F](https://projectf.io) is the source of the signed beam coordinates and the frame and line strobes in `demo_video.sv`.

## License

Each vendored module keeps its own license, next to its files. The repository's own license isn't chosen yet.

## Legal

Analogue’s Development program was created to further video game hardware preservation with FPGA technology. Analogue Developers have access to Analogue Pocket I/O’s so Developers can utilize cartridge adapters or interface with other pieces of original or bespoke hardware to support legacy media. Analogue does not support or endorse the unauthorized use or distribution of material protected by copyright or other intellectual property rights.
