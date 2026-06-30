# =============================================================================
# constraint.sdc — Synopsys Design Constraints for RISC-V RV32I Processor
# Tool    : Cadence Genus Synthesis Solution 18.1
# Library : slow_vddlv0_basicCells
# Author  : VLSI Internship Project
# =============================================================================
# Clock specification
#   Period   : 20 ns  →  50 MHz target frequency
#   Waveform : rises at 0 ns, falls at 10 ns (50 % duty cycle)
# -----------------------------------------------------------------------------
create_clock -name clk -period 20 -waveform {0 10} [get_ports clk]

# -----------------------------------------------------------------------------
# Clock transition times (slew)
#   Rise / fall edges modelled at 0.1 ns for accurate hold-time analysis
# -----------------------------------------------------------------------------
set_clock_transition -rise 0.1 [get_clocks clk]
set_clock_transition -fall 0.1 [get_clocks clk]

# -----------------------------------------------------------------------------
# Clock network uncertainty
#   Accounts for clock skew across the design (0.05 ns)
# -----------------------------------------------------------------------------
set_clock_uncertainty 0.05 [get_clocks clk]

# -----------------------------------------------------------------------------
# Input constraints
#   max input delay  : 2.0 ns before clock edge
#   input transition : 0.1 ns (slew on all primary inputs)
# -----------------------------------------------------------------------------
set_input_delay  -max 2.0 -clock clk [all_inputs]
set_input_transition 0.1 [all_inputs]

# -----------------------------------------------------------------------------
# Output constraints
#   max output delay : 2.0 ns after clock edge
#   output load      : 0.01 pF on all primary outputs
# -----------------------------------------------------------------------------
set_output_delay -max 2.0 -clock clk [all_outputs]
set_load 0.01 [all_outputs]

