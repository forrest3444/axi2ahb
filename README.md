# AXI2AHB-Lite Bridge UVM Verification Project

This repository contains a parameterized AXI Slave to AHB-Lite Master bridge and a UVM-based verification environment for functional, exception, stress, and reset validation.

The implementation and verification scope are described in:
- `doc/spec.pdf`
- `doc/axi2ahb_vtrack_v1.xlsx`

## Overview

The DUT accepts AXI read and write requests, buffers them through configurable FIFOs, converts AXI bursts into serialized AHB-Lite beats, and returns AXI-compliant B/R responses.

According to the specification, the bridge supports:
- AXI burst types: `FIXED`, `INCR`, `WRAP`
- Aligned transfers within the configured bus width
- Narrow transfers on a wider data bus
- Configurable FIFO depths for `AW`, `W`, `AR`, and `R`
- In-order completion with serialized execution compatible with AHB-Lite

The bridge does not implement:
- AXI IDs
- Out-of-order completion
- Interleaving or reordering
- Unaligned start-address support

Illegal requests are expected to return `SLVERR`. Illegal reads do not issue AHB traffic. Illegal writes drain write beats and return `SLVERR` without executing on AHB.

## DUT Architecture

Top-level DUT:
- `dut/axi2ahb_bridge/axi2ahb_bridge_top.sv`

Main blocks:
- `dut/axi2ahb_bridge/axi_frontend/axi_frontend.sv`
  Captures AXI requests and generates AXI responses
- `dut/axi2ahb_bridge/fifo/fifo_wrapper.sv`
  Provides independent synchronous FIFOs for `AW`, `W`, `AR`, and `R`
- `dut/axi2ahb_bridge/bridge_core/bridge_core.sv`
  Arbitrates requests, expands bursts, and controls execution
- `dut/axi2ahb_bridge/ahb_backend/ahb_backend.sv`
  Drives the AHB-Lite bus one beat at a time

Important submodules called out in the spec:
- `axi_req_capture.sv`
- `axi_bresp_gen.sv`
- `axi_rresp_gen.sv`
- `bridge_fifo_ctrl.sv`
- `bridge_arbiter.sv`
- `bridge_controller.sv`
- `ahb_beat_executor.sv`

## Repository Layout

- `agent/`
  AXI master and AHB slave agents
- `config/`
  Global macros and configuration objects
- `doc/`
  Specification and verification tracker documents
- `dut/`
  RTL for the AXI-to-AHB bridge
- `env/`
  UVM environment, scoreboard, subscribers, and coverage
- `seq_lib/`
  Virtual sequences and traffic generators
- `sim/`
  Build, run, waveform, and coverage flow
- `tb/`
  Top-level testbench and interfaces
- `tests/`
  UVM test classes

## Verification Environment

The testbench is UVM-based and instantiates:
- an AXI master agent to drive DUT inputs
- an AHB slave agent to respond on the backend side
- a reusable memory model for backdoor checking
- functional coverage and scoreboard components
- DUT debug signal plumbing used by stress and recovery tests

Top-level testbench:
- `tb/top_tb.sv`

## Test Suite

The current specification lists the following tests as part of the project verification plan:
- `single_write_read_test`
- `bd_write_fd_read_test`
- `fd_write_bd_read_test`
- `incr_random_len_size_wr_test`
- `wrap_random_len_size_wr_test`
- `fixed_random_len_size_wr_test`
- `random_traffic_test`
- `mixed_random_traffic_test`
- `frontend_exception_test`
- `backend_exception_test`
- `fifo_full_stress_test`
- `reset_recovery_test`

These tests cover:
- basic legal read/write behavior
- burst conversion for `FIXED`, `INCR`, and `WRAP`
- random traffic and mixed traffic robustness
- frontend illegal-request handling
- backend exception handling
- FIFO full/backpressure behavior
- reset and post-reset recovery

## Simulation Flow

Simulation is driven by `sim/Makefile`.

### Main variables

- `TESTNAME`
  UVM test name to run
- `SEED`
  Random seed, default `1`
- `VERB`
  UVM verbosity, default `UVM_MEDIUM`
- `RUN_TIME`
  Simulation timeout argument passed to the executable, default `1`
- `OUT`
  Output directory root, default `out`

### Main targets

From `sim/`:

```bash
make TESTNAME=single_write_read_test all
```

Useful targets:
- `make all`
  Prepare directories, compile, and run
- `make prepare`
  Create output directories
- `make elab`
  Build the simulation executable with VCS
- `make run`
  Run the previously built executable
- `make verdi`
  Open Verdi with the generated FSDB
- `make clean`
  Remove generated simulation and coverage artifacts

### Example runs

```bash
cd sim
make TESTNAME=single_write_read_test all
make TESTNAME=fifo_full_stress_test VERB=UVM_LOW RUN_TIME=5 all
make TESTNAME=reset_recovery_test VERB=UVM_LOW RUN_TIME=5 all
```

### Output structure

Each test run is written under:

```text
sim/out/<TESTNAME>_seed_<SEED>/
```

Typical subdirectories:
- `log/`
  Compile and run logs
- `wave/`
  FSDB waveforms
- `cov/`
  Per-test coverage database
- `simv/`
  Compiled VCS executable

## Tools and Prerequisites

The simulation flow assumes availability of Synopsys tools used by the Makefile and generated artifacts:
- VCS
- Verdi
- URG

The flow also uses:
- SystemVerilog with UVM 1.2
- `pdftotext` or equivalent tools if you want to inspect the PDF spec from the command line

## Coverage Notes

Coverage collection is enabled in the VCS command line for:
- line
- condition
- FSM
- branch
- toggle
- assertion

Merged coverage is typically written to:
- `sim/out.vdb`

HTML reports are generated under:
- `sim/urgReport/`

The verification tracker in `doc/axi2ahb_vtrack_v1.xlsx` records uncovered items and documents cases filtered as unreachable or defensive logic.

## Current Verification Summary

Per `doc/spec.pdf`, the intended conclusion for this project is:
- AXI-to-AHB-Lite conversion is functionally correct
- burst splitting and response generation are correct
- protocol behavior is compliant for the supported feature set
- illegal requests, FIFO stress, and reset recovery are handled as specified

## Notes

- The DUT is designed around serialized AHB-Lite execution, so throughput behavior is intentionally constrained by a single active backend transaction at a time.
- The provided `merge_cov` target in `sim/Makefile` reflects an older coverage merge list. When adding or rerunning tests, it is safer to invoke `urg` with the current set of `cov.vdb` directories.
