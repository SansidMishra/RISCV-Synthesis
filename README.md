# RISC-V Single Cycle Processor — Synthesis & GLS Flow

This repository documents the complete process of taking a single-cycle RISC-V processor from RTL (Verilog source code) all the way through **logic synthesis** and **gate-level simulation (GLS)**, using industry-standard EDA tools (Cadence Genus and ncverilog) on a 45nm standard cell technology.

This was done as part of an academic VLSI/digital design internship. The same flow was first validated on a simpler mod-10 counter design before being applied here to a full RISC-V core, so if anything is unclear, that simpler project is a good reference point.

This README is written so that someone with little or no prior exposure to the digital ASIC/VLSI flow can follow along and understand not just *what* commands were run, but *why*.

---

## Table of Contents

1. [Background: What is this project actually doing?](#background-what-is-this-project-actually-doing)
2. [Key Terms Explained](#key-terms-explained)
3. [Tools Used](#tools-used)
4. [Directory Structure](#directory-structure)
5. [Flow Overview (Step by Step)](#flow-overview-step-by-step)
6. [Setup Instructions](#setup-instructions)
7. [Running Synthesis](#running-synthesis)
8. [Reading the Reports](#reading-the-reports)
9. [Running Gate-Level Simulation (GLS)](#running-gate-level-simulation-gls)
10. [Viewing Waveforms](#viewing-waveforms)
11. [Results Summary](#results-summary)
12. [Common Errors and Fixes](#common-errors-and-fixes)
13. [Deliverables for Physical Design Handoff](#deliverables-for-physical-design-handoff)
14. [Notes](#notes)

---

## Background: What is this project actually doing?

When you design a digital circuit (like a processor), you usually start by describing its behavior in a hardware description language like **Verilog**. This Verilog code is called **RTL** (Register Transfer Level) — it describes *what* the circuit should do (e.g. "on every clock edge, update the program counter"), but it isn't yet a physical circuit.

To turn that RTL into something that can actually be manufactured as a chip, it has to go through a process called **logic synthesis**. A synthesis tool (here, Cadence Genus) reads the RTL and converts it into a netlist made of real, physical standard logic cells (AND gates, flip-flops, multiplexers, etc.) that exist in a specific manufacturing technology — in this project, a 45nm process.

Once that gate-level netlist exists, it's important to check that it still behaves the way the original RTL did. This is done with **Gate-Level Simulation (GLS)** — simulating the synthesized netlist (instead of the original RTL) and confirming the outputs still match expectations.

So in short, this project takes:

```
RTL (riscv.v)  →  Synthesis (Genus)  →  Gate-level netlist (riscv_net.v)  →  GLS (ncverilog)  →  Waveform check
```

---

## Key Terms Explained

If you're new to this flow, here's a quick glossary of terms used throughout this README and the scripts:

| Term | Meaning |
|---|---|
| **RTL** | Register Transfer Level — the Verilog source code describing circuit behavior |
| **Synthesis** | The process of converting RTL into a gate-level netlist using a standard cell library |
| **Netlist** | A text file listing the actual logic gates and how they're wired together |
| **Standard Cell Library (.lib)** | A file describing all the basic logic gates (AND, OR, flip-flops, etc.) available in a given manufacturing technology, including their timing, power, and area characteristics |
| **45nm** | The manufacturing process node — refers to the approximate transistor feature size. Smaller nodes are newer/denser; 45nm is an older, simpler node commonly used for teaching |
| **SDC (Synopsys Design Constraints)** | A file that tells the synthesis tool the timing requirements: clock speed, input/output delays, etc. Without constraints, the tool doesn't know how fast the circuit needs to run |
| **Clock period** | The time for one clock cycle. A 20 ns period means the clock runs at 1 / 20ns = 50 MHz |
| **Slack** | The difference between the required time and the actual time a signal takes to travel through logic. Positive slack = timing requirement met. Negative slack = timing violation (circuit may not work at the target speed) |
| **GLS (Gate-Level Simulation)** | Simulating the post-synthesis netlist (instead of RTL) to verify the synthesized circuit still behaves correctly |
| **Testbench** | A separate piece of Verilog code that doesn't represent real hardware — its job is to feed inputs (like clock and reset) into the design and observe the outputs during simulation |
| **VCD (Value Change Dump)** | A file format that records how every signal's value changes over time during simulation, used for waveform viewing |
| **Schematic Viewer** | A GUI tool inside Genus that lets you visually see the logic gates and connections, rather than just reading the netlist as text |

---

## Tools Used

- **Synthesis:** Cadence Genus 18.10 — converts RTL into a gate-level netlist
- **Simulation:** ncverilog (part of Cadence Incisive) — runs gate-level simulation
- **Waveform viewer:** SimVision — visualizes signal behavior over time from the VCD file
- **Technology library:** 45nm GPDK standard cell library (`slow_vdd1v0_basicCells.lib`)

All of these tools were run on a remote lab server (`vlsiws24`), accessed via a Linux terminal. If you're following this on your own machine, you'll need access to a licensed Cadence toolchain — these are not free/open-source tools.

---

## Directory Structure

```
.
├── rtl/                     RTL source and testbench
│   ├── riscv.v               the processor design itself
│   └── riscv_tb.v            testbench that drives clk/rst and observes pc_out
├── constraint/                SDC timing constraints
│   └── constraint.sdc
├── synthesis/                  Genus synthesis script and reports
│   ├── syn.tcl                the script that drives the whole synthesis run
│   ├── riscv_net.v            synthesized gate-level netlist (output)
│   ├── constraint_out.sdc     back-annotated constraints (output)
│   ├── area.rpt               cell count / area report (output)
│   ├── timing.rpt             timing slack report (output)
│   ├── power.rpt               power estimate report (output)
│   └── gates.rpt               gate count breakdown (output)
├── gls/                         gate-level simulation outputs
│   └── riscv.vcd                waveform dump from GLS run
└── README.md
```

Files marked "(output)" are generated automatically when you run the scripts — you don't need to create them by hand.

> **Note:** the foundry standard cell library (`.lib`/`.v` model files) is **not included** in this repo, since it is typically restricted IP under the lab/foundry license agreement. You'll need to supply these yourself — see [Setup Instructions](#setup-instructions) below.

---

## Flow Overview (Step by Step)

This is the full sequence of what happens, from start to finish:

1. **Write/obtain the RTL** — `riscv.v`, a single-cycle RISC-V core with ports `clk`, `rst`, and `pc_out`.
2. **Define timing constraints** — `constraint.sdc` tells Genus the clock runs at 20 ns (50 MHz), and specifies how inputs/outputs interact with that clock.
3. **Write the synthesis script** — `syn.tcl` tells Genus where to find the RTL, the library, and the constraints, and what commands to run.
4. **Run synthesis** in three stages:
   - `syn_generic` — converts RTL into generic, technology-independent logic gates
   - `syn_map` — maps those generic gates onto real 45nm library cells
   - `syn_opt` — optimizes the mapped netlist for timing/area
5. **Export reports** — area, timing, power, and gate count are written out for analysis.
6. **Set up GLS** — copy the synthesized netlist and the library's simulation models into the `gls/` folder, and write a testbench.
7. **Run gate-level simulation** with `ncverilog`, simulating the actual synthesized gates (not the original RTL) to confirm correct behavior.
8. **View waveforms** in SimVision to visually confirm the processor behaves as expected (e.g. `pc_out` incrementing every clock cycle).

---

## Setup Instructions

### 1. Clone this repository

```bash
git clone https://github.com/<your-username>/<repo-name>.git
cd <repo-name>
```

### 2. Supply the foundry library files (not included in this repo)

These files contain proprietary technology information and must be obtained separately from your lab/foundry license — they are **not** distributed in this repository.

```bash
mkdir -p lib
cp /path/to/slow_vdd1v0_basicCells.lib lib/
cp /path/to/slow_vdd1v0_basicCells.v gls/
```

If you don't already know where these files live on your system, you can search for them:

```bash
find /cad/FOUNDRY/digital/45nm -name "*.lib" |& head -20
```

You can confirm a `.lib` file actually contains usable logic cells (and isn't just filler/decap cells) with:

```bash
grep "cell (" library.lib | head -10
```

---

## Running Synthesis

Make sure the Cadence environment is loaded into your shell first (this sets up tool paths and licenses):

```bash
source /cad/cshrc
```

Then run Genus with the provided script:

```bash
cd synthesis
genus -f syn.tcl |& tee synthesis.log
```

`tee synthesis.log` saves a copy of everything printed to the terminal into a log file, so you can review it later even if the terminal window closes.

As it runs, watch for these milestone messages confirming each synthesis stage completed successfully:

```
Info : Done synthesizing. [SYNTH-2]
       Done synthesizing 'riscv' to generic gates.        (after syn_generic)

Info : Done incrementally optimizing. [SYNTH-8]
       Done incrementally optimizing 'riscv'.              (after syn_opt)
```

If you don't see these messages, something went wrong earlier in the run — check the [Common Errors and Fixes](#common-errors-and-fixes) table below, or scroll up in the log for the first `Error` message.

---

## Reading the Reports

After synthesis finishes, four report files are generated automatically in `synthesis/`. You can view any of them with `cat`:

```bash
cat area.rpt
cat timing.rpt
cat power.rpt
cat gates.rpt
```

### Area Report (`area.rpt`)

Tells you how big the synthesized circuit is, in terms of standard cell area (not yet physical layout area):

| Field | Meaning |
|---|---|
| Cell Count | Total number of standard cells (gates/flip-flops) used |
| Cell Area | Area occupied by the logic cells themselves |
| Net Area | Area occupied by interconnect wiring (usually 0 at this stage, since physical wiring hasn't happened yet) |
| Total Area | Cell Area + Net Area |

### Timing Report (`timing.rpt`)

Tells you whether the circuit can run at the clock speed you specified in `constraint.sdc`.

- **Positive slack** → timing is **met** (the circuit is fast enough)
- **Negative slack** → timing **violation** (some path takes longer than the clock period allows; the design may not work correctly at this speed)

If `timing.rpt` is empty (0 bytes), it usually means some inputs/outputs weren't properly constrained. Diagnose this inside Genus with:

```tcl
report_timing -lint
```

### Power Report (`power.rpt`)

Breaks down estimated power consumption into:
- **Leakage Power** — power consumed even when the circuit is idle
- **Dynamic Power** — power consumed due to signal switching activity
- **Total Power** — sum of the two

A processor like this RISC-V core will show noticeably higher dynamic power than a simple design (like a counter), because it has more logic and more switching activity per clock cycle.

### Gates Report (`gates.rpt`)

Lists the breakdown of which specific standard cells (gate types) were used and how many of each.

---

## Running Gate-Level Simulation (GLS)

GLS confirms that the synthesized netlist — the actual gates that will be manufactured — still behaves correctly, not just the original RTL.

### 1. Copy the necessary files into `gls/`

```bash
cp ../synthesis/riscv_net.v .
cp /cad/FOUNDRY/digital/45nm/svt/verilog/slow_vdd1v0_basicCells.v .
```

### 2. The testbench (`riscv_tb.v`)

The testbench is *not* part of the real hardware — it's a Verilog wrapper used only for simulation, whose job is to:
- Generate a clock signal (toggling every 10 ns, giving a 20 ns period to match the SDC)
- Apply and release reset (`rst`)
- Instantiate the actual design (`riscv`) and connect its ports
- Dump signal changes to a `.vcd` file for waveform viewing
- Print live status updates to the terminal via `$monitor`

If your RTL reads a program from a hex file using `$readmemh`, you'll need to provide a placeholder instruction memory file before simulating (a file full of NOP instructions, opcode `0x00000013`):

```bash
python3 -c "print(chr(10).join(['00000013']*256))" > program.hex
```

### 3. Run the simulation

```bash
source /cad/cshrc
ncverilog slow_vdd1v0_basicCells.v riscv_net.v riscv_tb.v +access+r
```

**Important:** the file order matters here — list the cell model file first, then the synthesized netlist, then the testbench. Reversing this order is a common cause of "module not found" type errors.

`+access+r` grants read access to internal signals, which is required for waveform viewing afterward.

A successful run ends with a line like:

```
Simulation complete via $finish(1) at time 540 NS
```

---

## Viewing Waveforms

Once `riscv.vcd` has been generated, open it in SimVision:

```bash
simvision riscv.vcd &
```

Steps inside the SimVision GUI:

1. If a database is already open and locked, reopen it from the console with:
   ```
   database open -overwrite riscv.vcd
   ```
2. In the **Design Browser** panel (left side), click the small triangle/arrow next to the top module (e.g. `riscv > riscv_tb`) to expand the hierarchy.
3. Click on `riscv_tb` — its signals (`clk`, `rst`, `pc_out`) will appear in the panel below.
4. Select all signals (`Ctrl+A`), then click **"Click and add to waveform area"**.
5. Press **F** (or go to `View > Zoom > Full X`) to fit the entire simulation timeline on screen.

### What to expect

For a correctly working single-cycle RISC-V core, you should see `pc_out` incrementing by 4 every clock cycle once `rst` goes low — for example:

```
00000000 → 00000004 → 00000008 → 0000000C → ...
```

This makes sense because RISC-V instructions are 4 bytes wide, and a single-cycle processor (with no branches taken) simply advances the program counter by one instruction each cycle.

If no expand arrow appears next to the top module in the Design Browser, the VCD likely only dumped a "flat" scope rather than the full hierarchy. Double-check the `$dumpvars` line in the testbench, delete the old `.vcd` file, and re-run the simulation.

---

## Results Summary

| Metric | Value |
|---|---|
| Clock period | 20 ns (50 MHz) |
| Target slack | 397 ps (clk cost group) |
| Total cell area | 304 (post-optimization) |
| GLS result | `pc_out` increments by 4 per cycle after reset, as expected |

*(Replace/expand this table with your own final numbers pulled directly from `area.rpt`, `timing.rpt`, and `power.rpt` once your run is finalized.)*

---

## Common Errors and Fixes

These are real issues encountered while building this flow, along with what caused them and how they were resolved:

| Error Message | Cause | Fix |
|---|---|---|
| `Multiple designs are available. Specify the design you want to use.` | `read_sdc` / `report_*` commands run without an explicit "current" design selected | Add `set_db design:riscv .current 1` before `read_sdc`, or pass the design name directly, e.g. `report_area riscv` |
| `Cannot perform synthesis because libraries do not have usable inverters. [LBR-171]` | The `.lib` file loaded has no real logic cells (e.g. it's a timing-only or filler-only library) | Use a library confirmed to contain real cells like INV / NAND / NOR / DFF — check with `grep "cell (" library.lib` |
| `An option named '-file' could not be found.` (on `write_hdl`) | Genus 18.10 doesn't support the `-file` flag used in some older tutorials | Use shell redirection instead: `write_hdl riscv > riscv_net.v` |
| `cp: cannot create regular file: No such file or directory` | The target directory wasn't actually created beforehand | Run `ls` to verify the folder exists before copying; recreate with `mkdir -p` if missing |
| Abnormal exit / Segmentation fault (after `gui_show`) | The Genus GUI crashed due to a display/X11 issue (common over remote/SSH sessions without proper X forwarding) | Avoid `gui_show`; just run `genus -f syn.tcl` — the GUI isn't needed unless you specifically want to view the schematic |
| `Could not interpret SDC command. [SDC-202]` | A bus-style port reference like `out[0]` was misinterpreted by Tcl (square brackets have special meaning in Tcl) | Wrap the reference in curly braces, e.g. `{out[0]}` — or better, just use `all_inputs` / `all_outputs` to avoid the issue entirely |

---

## Deliverables for Physical Design Handoff

Once synthesis and GLS are both verified, these are the files that would be handed off to the next stage of the flow (physical design / place-and-route):

- `synthesis/riscv_net.v` — the gate-level netlist
- `synthesis/constraint_out.sdc` — back-annotated timing constraints
- `synthesis/area.rpt`, `timing.rpt`, `power.rpt` — for lab report documentation and as a reference baseline for physical design

---

## Notes

- `set_db design:riscv .current 1` is required before `read_sdc` to avoid the "Multiple designs are available" error in Genus.
- Genus 18.10 does not support `write_hdl -file`; use shell redirection (`write_hdl riscv > riscv_net.v`) instead.
- Bus-style port references in SDC (e.g. `out[0]`) should be wrapped in `{}`, or avoided in favor of `all_inputs`/`all_outputs`.
- This flow was first validated end-to-end on a simpler mod-10 counter design before being applied to this RISC-V core — if something here is confusing, working through that simpler example first may help.
- A 20 ns (50 MHz) clock period was chosen as a safe, conservative starting point for a single-cycle 45nm RISC-V design. If `report_timing -lint` reports failing paths, try increasing the clock period (i.e. slowing down the clock) to give the logic more time per cycle.
