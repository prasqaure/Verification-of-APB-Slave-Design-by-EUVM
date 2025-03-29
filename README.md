# APB Slave Design with EUVM Verification

Overview
This repository contains an implementation of an APB (Advanced Peripheral Bus) slave module and its corresponding EUVM (Enhanced Universal Verification Methodology) testbench. The APB slave module allows read and write transactions based on the APB protocol, and the EUVM environment is designed to verify its functionality.

APB Slave Module

Features
Supports 32-bit data width and 32-bit address width (configurable via parameters DW and AW).
Implements a simple 16-location memory for data storage.
Supports synchronous read and write operations.
Uses PREADY signal to indicate transaction completion.
APB Slave Code (Verilog)
The APB slave module (apb_slave.sv) includes:
PCLK: Clock signal.
PRESETn: Active-low reset.
PSEL, PENABLE: Control signals for APB transaction.
PWRITE: Indicates write operation.
PADDR: Address bus.
PWDATA: Write data bus.
PRDATA: Read data bus.
PREADY: Ready signal indicating transaction completion.

EUVM Verification Environment
Components
Sequence Item (apb_seq_item)
Defines the transaction structure (address and data fields) for APB transactions.
Sequence (apb_sequence)
Generates and initiates transactions.
Sequencer (apb_sequencer)
Arbitrates sequence items and forwards them to the driver.
Driver (apb_driver)
Drives the APB interface according to the transactions.
Monitor (apb_monitor)
Observes APB transactions and logs information.
Agent (apb_agent)
Instantiates the sequencer, driver, and monitor.
Scoreboard (apb_scoreboard)
Checks data correctness (not included in the given code, but recommended for verification).
Environment (apb_env)
Instantiates the agent and scoreboard.
Test (apb_test)
Runs the EUVM sequence on the APB environment.
Running the EUVM Testbench
The testbench execution starts with:
void main() {
    run_test("apb_test!(32, 32)");
}
This runs the apb_test class, which initializes the environment and executes a test sequence.
