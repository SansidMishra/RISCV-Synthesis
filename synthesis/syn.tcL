# =============================================================================
# syn.tcl — Cadence Genus Synthesis Script for RISC-V RV32I Processor
# Tool    : Cadence Genus Synthesis Solution 18.1
# Author  : VLSI Internship Project
# Usage   : genus -files syn.tcl   (run from the synthesis/ directory)
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Search-path configuration
#    Tell Genus where to look for the standard-cell library, RTL sources,
#    and timing-constraint files.
# -----------------------------------------------------------------------------
set_db init_lib_search_path    /home/vlsilab/riscv/lib/
set_db init_hdl_search_path    /home/vlsilab/riscv/rtl/
set_db script_search_path      /home/vlsilab/riscv/constraint/

# -----------------------------------------------------------------------------
# 2. Technology library
#    Low-voltage slow-corner cell library used for worst-case timing analysis.
# -----------------------------------------------------------------------------
set_db library slow_vddlv0_basicCells.lib

# -----------------------------------------------------------------------------
# 3. Read RTL
#    Read the top-level Verilog source (riscv.v includes all sub-modules).
# -----------------------------------------------------------------------------
read_hdl riscv.v

# -----------------------------------------------------------------------------
# 4. Elaboration
#    Analyse the design hierarchy, resolve module references, and build the
#    internal data model.
# -----------------------------------------------------------------------------
elaborate riscv

# -----------------------------------------------------------------------------
# 5. Set current design
# -----------------------------------------------------------------------------
current_design riscv

# -----------------------------------------------------------------------------
# 6. Apply timing constraints
#    Load the SDC file containing clock definition, I/O delays, and loads.
# -----------------------------------------------------------------------------
read_sdc constraint.sdc

# -----------------------------------------------------------------------------
# 7. Synthesis flow
#    Three-pass Genus synthesis:
#      syn_generic — technology-independent (generic gates) optimisation
#      syn_map     — map generic gates to standard cells from the library
#      syn_opt     — post-mapping physical-aware optimisation (timing/area)
# -----------------------------------------------------------------------------
syn_generic
syn_map
syn_opt

# -----------------------------------------------------------------------------
# 8. Write outputs
#    Netlist  : synthesised gate-level Verilog
#    SDC      : propagated constraints (for place & route hand-off)
# -----------------------------------------------------------------------------
write_hdl riscv > riscv_net.v
write_sdc       > constraint_out.sdc

# -----------------------------------------------------------------------------
# 9. Generate reports
#    timing.rpt  — static timing analysis (setup / hold slack)
#    area.rpt    — cell count, combinational & sequential area
#    power.rpt   — dynamic & leakage power breakdown
#    gates.rpt   — gate-level cell utilisation statistics
# -----------------------------------------------------------------------------
report timing       > timing.rpt
report_area  riscv  > area.rpt
report_power riscv  > power.rpt
report_gates riscv  > gates.rpt
