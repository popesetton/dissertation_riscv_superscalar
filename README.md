
# Pipelined Dual-Issue Superscalar RISC-V Processor

## Overview

This project presents the RTL design, implementation and FPGA deployment of a 32-bit, four-stage pipelined RISC-V processor.

A single-issue, in-order RV32I processor was initially designed and verified before being extended into a dual-issue superscalar architecture capable of issuing up to two instructions per clock cycle.

The project investigates the performance improvements and hardware trade-offs associated with dual-issue execution, with both implementations benchmarked under identical conditions.

Both processors were developed in SystemVerilog using AMD Vivado and deployed onto a Digilent Basys 3 FPGA.

## Processor Architecture

Both implementations share a four-stage pipeline:

1. **Instruction Fetch (IF):** Program counter management and instruction memory access.
2. **Instruction Decode (ID):** Instruction decoding, immediate generation and register file access.
3. **Execute (EX):** ALU operations, branch comparison and target address calculation.
4. **Writeback (WB):** Register file writeback and load/store operations.

The processors support the RV32I base integer instruction set, including arithmetic, logical, branch, jump, load and store instructions.

### Single-Issue Implementation

The baseline processor features:

- In-order, single-issue execution.
- A 32-entry, 32-bit register file.
- RAW hazard detection and data forwarding.
- Pipeline stalls for load-use and branch dependencies.
- Pipeline flushing following taken branches and jumps.

### Dual-Issue Implementation

The superscalar extension introduces a second instruction datapath, allowing up to two independent instructions to be issued per clock cycle.

Key architectural additions include:

- **Instruction Decision Unit (IDU):** Determines whether two fetched instructions can be issued simultaneously based on instruction compatibility and register dependencies.
- **Reduced Secondary Issue Path:** Supports R-type and I-type ALU instructions, AUIPC and LUI, reducing the hardware overhead of full datapath duplication.
- **Expanded Register File:** Four read ports and two write ports to support simultaneous execution.
- **Extended Hazard Logic:** Cross-issue RAW dependency detection and additional forwarding paths.
- **Dynamic Next-Fetch Selection:** Advances the PC by 4 or 8 bytes depending on whether one or two instructions are issued.

## Verification and Validation

Both implementations were verified through SystemVerilog simulation using an RV32I instruction test program and dedicated hazard test scenarios.

Testing focused on:

- Correct execution of supported RV32I instructions.
- Data forwarding and RAW hazard handling.
- Load-use dependencies and pipeline stalls.
- Control hazards and pipeline flushing.
- Same-cycle instruction dependencies in dual-issue execution.
- Correct instruction pairing and secondary issue activation.

A RISC-V assembly program generating the Fibonacci sequence was additionally developed to demonstrate processor functionality and benchmark both architectures.

## FPGA Implementation and Results

Both processors were synthesised and implemented using AMD Vivado, targeting the Digilent Basys 3 FPGA.

The following results compare both implementations using the same Fibonacci benchmark.

| Metric | Single-Issue | Dual-Issue |
|---|---:|---:|
| Execution cycles | 72 | 53 |
| Slice LUTs | 661 | 1,823 |
| Slice registers | 351 | 794 |
| Estimated total power | 93 mW | 110 mW |
| Timing slack | 2.719 ns | 1.330 ns |

The dual-issue processor achieved a **26.3% reduction in execution cycles**, at the expense of increased FPGA resource utilisation and an 18.3% increase in estimated total power consumption.

## Tools and Technologies

- **HDL:** SystemVerilog
- **ISA:** RISC-V RV32I
- **Development Environment:** AMD Vivado
- **Target Hardware:** Digilent Basys 3 FPGA
- **Assembly and Machine Code Generation:** RARS

## Repository Structure

- `single-issue/` - Single-issue processor RTL and associated files.
- `dual-issue/` - Dual-issue processor RTL and associated files.
- `images/` - FPGA implementation and project images.
- `testprograms/` - Verification testbench and Fibonacci programs in assembler and hex machine code. 