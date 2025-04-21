
# APB Slave Module and EUVM Testbench

## Overview
This repository contains an implementation of an **APB (Advanced Peripheral Bus) slave module** and its corresponding **EUVM (Enhanced Universal Verification Methodology) testbench**.  
The APB slave module allows read and write transactions based on the APB protocol, and the EUVM environment is designed to verify its functionality.

---

## APB Slave Module

### **Features**
- Supports **32-bit data width** and **32-bit address width** (configurable via parameters `DW` and `AW`).
- Implements a simple **16-location memory** for data storage.
- Supports **synchronous read and write operations**.
- Uses the **PREADY** signal to indicate transaction completion.

### **APB Slave Code (Verilog)**
The APB slave module (`apb_slave.sv`) includes the following signals:

| Signal    | Direction | Description |
|-----------|----------|-------------|
| `PCLK`    | Input    | Clock signal |
| `PRESETn` | Input    | Active-low reset |
| `PSEL`    | Input    | APB slave select signal |
| `PENABLE` | Input    | APB transaction enable signal |
| `PWRITE`  | Input    | Write enable (1: Write, 0: Read) |
| `PADDR`   | Input    | Address bus |
| `PWDATA`  | Input    | Write data bus |
| `PRDATA`  | Output   | Read data bus |
| `PREADY`  | Output   | Indicates transaction completion |

---

## EUVM Verification Environment

### **Components**
1. **Sequence Item (`apb_seq_item`)**  
   - Defines the **transaction structure** (address and data fields) for APB transactions.
  
2. **Sequence (`apb_sequence`)**  
   - Generates and initiates APB transactions.
  
3. **Sequencer (`apb_sequencer`)**  
   - Arbitrates sequence items and forwards them to the driver.
  
4. **Driver (`apb_driver`)**  
   - Drives the APB interface based on the received transactions.
  
5. **Monitor (`apb_monitor`)**  
   - Observes APB transactions and logs information.
  
6. **Agent (`apb_agent`)**  
   - Instantiates the **sequencer, driver, and monitor**.
  
7. **Scoreboard (`apb_scoreboard`)** *(Optional but recommended)*  
   - Checks **data correctness** by comparing expected and actual results.
  
8. **Environment (`apb_env`)**  
   - Instantiates the **agent and scoreboard**.
  
9. **Test (`apb_test`)**  
   - Runs the EUVM sequence on the APB environment.

--

