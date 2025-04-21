import uvm;
import esdl;
import std.format;

enum kind_e: bool {
  READ,
  WRITE
}

class apb_seq_item: uvm_sequence_item {
  mixin uvm_object_utils;

  this(string name="apb_seq_item") {
    super(name);
  }

  @UVM_DEFAULT {
    @rand ubvec!12 addr;
    @rand ubvec!32 data;
    @rand kind_e   kind;
    @rand ubvec!1 pwrite;
  }

  constraint! q{
    addr % 4 == 0;
    addr < 64;
  } cst_addr;
}

class apb_seq: uvm_sequence!apb_seq_item {
  mixin uvm_object_utils;

  this(string name="apb_seq_item") {
    super(name);
  }

  @UVM_DEFAULT {
    @rand uint size;
  }

  constraint! q{
    size < 128;
  } cst_seq_size;

  override void body() {
    req = apb_seq_item.type_id.create("req");
    for (size_t i=0; i!=size; ++i) {
      wait_for_grant();
      req.randomize();
      apb_seq_item cloned = cast(apb_seq_item) req.clone();
      uvm_info("SEQ", cloned.sprint(), UVM_NONE);
      send_request(cloned);
    }
  }
}

class apb_sequencer: uvm_sequencer!apb_seq_item {
  mixin uvm_component_utils;

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class apb_driver: uvm_driver!(apb_seq_item) {
  mixin uvm_component_utils;

  ApbIf apb_if;
  apb_seq_item req;

  this(string name, uvm_component parent = null) {
    super(name, parent);
    uvm_config_db!ApbIf.get(this, "", "apb_if", apb_if);
    assert (apb_if !is null);
    req = apb_seq_item.type_id.create("req");
  }

  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    get_and_drive(phase);
  }

  void get_and_drive(uvm_phase phase) {
    while (true) {
      seq_item_port.get_next_item(req);

      while (apb_if.PRESETn == false)
        wait(apb_if.PCLK.posedge());

      assert(req !is null);

      uvm_info("DRV", req.sprint(), UVM_NONE);

      wait(apb_if.PCLK.posedge());
      apb_if.PADDR   = req.addr;
      apb_if.PWRITE  = req.pwrite;
      apb_if.PSEL    = true;
      apb_if.PENABLE = false;

      if (req.pwrite)
        apb_if.PWDATA = req.data;

      wait(apb_if.PCLK.posedge());
      apb_if.PENABLE = true;

      while (!apb_if.PREADY)
        wait(apb_if.PCLK.posedge());

      if (!req.pwrite)
        req.data = apb_if.PRDATA;

      wait(apb_if.PCLK.posedge());
      apb_if.PSEL    = false;
      apb_if.PENABLE = false;

      seq_item_port.item_done();
    }
  }
}

class apb_monitor: uvm_component {
  mixin uvm_component_utils;

  ApbIf apb_if;
  uvm_analysis_port!(apb_seq_item) item_port;

  this(string name, uvm_component parent = null) {
    super(name, parent);
    item_port = new uvm_analysis_port!(apb_seq_item)("item_port", this);
    uvm_config_db!ApbIf.get(this, "", "apb_if", apb_if);
    assert (apb_if !is null);
  }

  override void run_phase(uvm_phase phase) {
    super.run_phase(phase);
    while (true) {
      wait(apb_if.PCLK.posedge());
      if (apb_if.PSEL && apb_if.PENABLE && apb_if.PREADY) {
        auto tx = apb_seq_item.type_id.create("mon_tx");
        tx.addr = apb_if.PADDR;
        tx.pwrite = apb_if.PWRITE;
        tx.data = apb_if.PWRITE ? apb_if.PWDATA : apb_if.PRDATA;
        uvm_info("MON", tx.sprint(), UVM_NONE);
        item_port.write(tx);
      }
    }
  }
}

class apb_scoreboard: uvm_component {
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  uvm_analysis_imp!(apb_seq_item, apb_scoreboard) mon_export;
  uint[16] memory;

  override void build_phase(uvm_phase phase) {
    super.build_phase(phase);
    mon_export = new uvm_analysis_imp!(apb_seq_item, apb_scoreboard)("mon_export", this);
  }

  void write(apb_seq_item item) {
    uvm_info("SB", item.sprint(), UVM_NONE);
    uint index = item.addr >> 2;
    if (item.pwrite) {
      memory[index] = item.data;
      uvm_info("SB", format("WRITE confirmed: addr=0x%X data=0x%X", item.addr, item.data), UVM_NONE);
    } else {
      uint expected = memory[index];
      if (expected != item.data) {
        uvm_error("SB", format("READ mismatch at addr=0x%X: expected=0x%X, got=0x%X", item.addr, expected, item.data));
      } else {
        uvm_info("SB", format("READ verified: addr=0x%X data=0x%X", item.addr, item.data), UVM_NONE);
      }
    }
  }
}

class apb_agent: uvm_agent {
  @UVM_BUILD {
    apb_sequencer sequencer;
    apb_driver    driver;
    apb_monitor   monitor;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    driver.seq_item_port.connect(sequencer.seq_item_export);
  }
}

class apb_env: uvm_env {
  mixin uvm_component_utils;

  @UVM_BUILD {
    apb_agent agent;
    apb_scoreboard scoreboard;
  }

  override void connect_phase(uvm_phase phase) {
    agent.monitor.item_port.connect(scoreboard.mon_export);
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }
}

class ApbIf: VlInterface {
  Port!(Signal!(ubvec!1)) PCLK;
  Port!(Signal!(ubvec!1)) PRESETn;

  VlPort!(1) PSEL;
  VlPort!(1) PENABLE;
  VlPort!(1) PWRITE;
  VlPort!(1) PREADY;
  VlPort!(1) PSLVERR;
  VlPort!(12) PADDR;
  VlPort!(32) PWDATA;
  VlPort!(32) PRDATA;
}

class apb_tb_top: Entity {
  import Vapb_design_euvm;
  import esdl.intf.verilator.verilated;
  import esdl.intf.verilator.trace;

  ApbIf apbSlave;
  VerilatedVcdD _trace;
  Signal!(ubvec!1) clk;
  Signal!(ubvec!1) rstn;
  DVapb_design dut;

  void opentrace(string vcdname) {
    if (_trace is null) {
      _trace = new VerilatedVcdD();
      dut.trace(_trace, 99);
      _trace.open(vcdname);
    }
  }

  void closetrace() {
    if (_trace !is null) {
      _trace.close();
      _trace = null;
    }
  }

  override void doConnect() {
    apbSlave.PCLK(clk);
    apbSlave.PRESETn(rstn);

    apbSlave.PSEL(dut.PSEL);
    apbSlave.PENABLE(dut.PENABLE);
    apbSlave.PWRITE(dut.PWRITE);
    apbSlave.PREADY(dut.PREADY);
    apbSlave.PSLVERR(dut.PSLVERR);
    apbSlave.PADDR(dut.PADDR);
    apbSlave.PWDATA(dut.PWDATA);
    apbSlave.PRDATA(dut.PRDATA);
  }

  override void doBuild() {
    dut = new DVapb_design();
    traceEverOn(true);
    opentrace("apb_design.vcd");
  }

  Task!stimulateClk stimulateClkTask;
  Task!stimulateRst stimulateRstTask;

  void stimulateClk() {
    clk = false;
    for (size_t i=0; i!=1000000; ++i) {
      clk = false;
      dut.PCLK = false;
      wait (2.nsec);
      dut.eval();
      if (_trace !is null)
        _trace.dump(getSimTime().getVal());
      wait (8.nsec);
      clk = true;
      dut.PCLK = true;
      wait (2.nsec);
      dut.eval();
      if (_trace !is null) {
        _trace.dump(getSimTime().getVal());
        _trace.flush();
      }
      wait (8.nsec);
    }
  }

  void stimulateRst() {
    rstn = false;
    dut.PRESETn = false;
    wait (100.nsec);
    rstn = true;
    dut.PRESETn = true;
  }
}

class random_test: uvm_test {
  mixin uvm_component_utils;

  this(string name="", uvm_component parent=null) {
    super(name, parent);
  }

  @UVM_BUILD {
    apb_env env;
  }

  override void run_phase(uvm_phase phase) {
    phase.get_objection().set_drain_time(this, 100.nsec);
    phase.raise_objection(this);
    apb_seq rand_sequence = apb_seq.type_id.create("apb_seq");

    for (size_t i=0; i!=1; ++i) {
      rand_sequence.randomize();
      auto sequence = cast(apb_seq) rand_sequence.clone();
      sequence.start(env.agent.sequencer, null);
    }
    phase.drop_objection(this);
  }
}

class apb_tb: uvm_tb {

  apb_tb_top top = new apb_tb_top();

  override void initial() {
    uvm_config_db!(ApbIf).set(null, "uvm_test_top.env.agent.driver", "apb_if", top.apbSlave);
    uvm_config_db!(ApbIf).set(null, "uvm_test_top.env.agent.monitor", "apb_if", top.apbSlave);
  }
}

void main(string[] args) {
  import std.stdio;
  uint random_seed;

  CommandLine cmdl = new CommandLine(args);

  if (cmdl.plusArgs("random_seed=" ~ "%d", random_seed))
    writeln("Using random_seed: ", random_seed);
  else random_seed = 1;

  auto tb = new apb_tb;
  tb.multicore(0, 1);
  tb.elaborate("tb", args);
  tb.set_seed(random_seed);
  tb.start();
}
