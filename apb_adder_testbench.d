import esdl;
import uvm;
import std.stdio;

class apb_seq_item(int DW, int AW): uvm_sequence_item {
  mixin uvm_object_utils;
  this(string name="") {
    super(name);
  }
  enum BW = DW / 8;
  @UVM_DEFAULT {
    @rand UBit!AW addr;
    @rand Bit!DW data;
    @UVM_BIN
    Bit!2 PCLK, PRESET, PSEL, PENABLE, PWDATA;
  }
  constraint! q{
    (addr >> 2) < 4;
    addr % BW == 0;
  }addrCst;
};
class apb_sequence(int DW, int AW): uvm_sequence!(apb_seq_item!(DW, AW)) {
  mixin uvm_object_utils;
  apb_sequencer!(DW, AW) sequencer;
  this(string name = "apb_sequence") {
    super(name);
  }

  override void body() {
    req = apb_seq_item!(DW, AW).type_id.create("req");
    start_item(req);
    finish_item(req);
    uvm_info("APB_SEQ", "Sequence executed", UVM_MEDIUM);
  }
}
class apb_sequencer(int DW, int AW): uvm_sequencer!(apb_seq_item!(DW, AW)) {
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  void transfer_to_driver(apb_driver!(DW, AW) drv) {
    apb_seq_item!(DW, AW) tr;
    
    while (true) {
      // Get the next transaction from the sequence
      seq_item_port.get_next_item(tr);

      // Pass the transaction to the driver
      drv.drive_transaction(tr);

      // Mark the transaction as done
      seq_item_port.item_done();
    }
  }
}

class apb_driver(int DW, int AW): uvm_driver!(apb_seq_item!(DW, AW)) {
  mixin uvm_component_utils;
  REQ tr;
  ApbLiteIntf!(DW, AW) apb_if;
  this(string name, uvm_component parent) {
    super(name, parent);
    uvm_config_db!(ApbLiteIntf!(DW, AW)).get(this, "", "apb_if", apb_if);
    assert(apb_if !is null);
  }
override void run_phase(uvm_phase phase) {
    while (true) {
        seq_item_port.get_next_item(tr);
        
        apb_if.PADDR = tr.addr;
        apb_if.PSEL = 1;
        apb_if.PENABLE = 1;
        apb_if.PWRITE = tr.PWRITE; // Determine if it's a read or write

        if (tr.PWRITE == 1) { // Write transaction
            apb_if.PWDATA = tr.data;
        }

        wait(apb_if.PREADY);

        if (tr.PWRITE == 0) { // Read transaction
            tr.data = apb_if.PRDATA;
        }

        apb_if.PENABLE = 0;
        apb_if.PSEL = 0;

        seq_item_port.item_done();
    }
}

class apb_monitor(int DW, int AW): uvm_monitor {
  mixin uvm_component_utils;
  ApbLiteIntf!(DW, AW) apb_if;
  apb_seq_item!(DW, AW) tr;
  uvm_analysis_port!(apb_seq_item!(DW, AW)) mon_ap;

  this(string name, uvm_component parent) {
    super(name, parent);
    uvm_config_db!(ApbLiteIntf!(DW, AW)).get(this, "", "apb_if", apb_if);
    mon_ap mon_ap_inst = mon_ap.type.create("mon_ap", this);
  }

  override void run_phase(uvm_phase phase) {
    while (true) {
      wait(apb_if.PREADY);  // Wait for the transaction to complete
      
      // Capture transaction fields
      tr = apb_seq_item!(DW, AW).type_id.create("tr");
      tr.addr   = apb_if.PADDR;
      tr.PWRITE = apb_if.PWRITE;
      tr.PWDATA = apb_if.PWDATA;
      tr.data   = apb_if.PRDATA;
      
      // Send transaction to the analysis port
      mon_ap.write(tr);
    }
  }
}

class apb_agent(int DW, int AW): uvm_agent {
  mixin uvm_component_utils;
  apb_sequencer!(DW, AW) seqr;
  apb_driver!(DW, AW) drv;
  apb_monitor!(DW, AW) mon;

  this(string name, uvm_component parent) {
    super(name, parent);
  }
  override void build_phase(uvm_phase phase) {
    seqr = apb_sequencer!(DW, AW).type_id.create("seqr", this);
    drv = apb_driver!(DW, AW).type_id.create("drv", this);
    mon = apb_monitor!(DW, AW).type_id.create("mon", this);
  }
}
class apb_env(int DW, int AW): uvm_env {
  mixin uvm_component_utils;
  apb_agent!(DW, AW) agent;
  apb_scoreboard!(DW, AW) sb;
  this(string name, uvm_component parent) {
    super(name, parent);
  }
  override void build_phase(uvm_phase phase) {
    agent = apb_agent!(DW, AW).type_id.create("agent", this);
    sb = apb_scoreboard!(DW, AW).type_id.create("sb", this);
  }
}
class apb_test(int DW, int AW): uvm_test {
  mixin uvm_component_utils;
  apb_env!(DW, AW) env;
  this(string name, uvm_component parent) {
    super(name, parent);
  }
  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    env = apb_env!(DW, AW).type_id.create("env", this);
  }
  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    phase.raise_objection(this);

    auto seq = apb_sequence!(DW, AW).type_id.create("seq");
    seq.start(env.agent.seqr);

    phase.drop_objection(this);
  }
}
}
void main() {
    run_test("apb_test!(32, 32)");
}



