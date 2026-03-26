`ifndef AHB_SLAVE_MONITOR_SV
`define AHB_SLAVE_MONITOR_SV

typedef struct {
  bit         is_write;
  ahb_burst_e burst;
  ahb_trans_e trans;
  ahb_addr_t  addr;
  ahb_size_e  size;
  int unsigned wait_cycle_cnt;
  time         start_time;
} ahb_ctrl_t;

class ahb_slave_monitor extends uvm_monitor;

  `uvm_component_utils(ahb_slave_monitor)

  virtual ahb_intf                     hvif;
  uvm_analysis_port #(ahb_transaction) out_monitor_port;
  ahb_slave_config                     cfg;

  protected ahb_ctrl_t ctrl_q[$];

  function new(string name = "ahb_slave_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    out_monitor_port = new("out_monitor_port", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (cfg == null)
      `uvm_fatal("NULL_CFG", "ahb_slave_monitor cfg is null")

    this.hvif = cfg.hvif;

    if (this.hvif == null)
      `uvm_fatal("NULL_VIF", "ahb_slave_monitor hvif is null")
  endfunction

  virtual task run_phase(uvm_phase phase);
    init_component();

    forever begin
      @(hvif.mon_cb);

      if (!hvif.mon_mp.rstn) begin
        init_component();
        continue;
      end

      sample_bus();
    end
  endtask

  virtual function void extract_phase(uvm_phase phase);
    super.extract_phase(phase);

    if (ctrl_q.size() != 0) begin
      `uvm_warning("AHB_MON_EXTRACT",
        $sformatf("Monitor exits with %0d pending control entries; incomplete transfers are dropped",
                  ctrl_q.size()))
    end
  endfunction

  extern protected virtual task init_component();
  extern protected virtual task sample_bus();
  extern protected virtual function void enqueue_ctrl();
  extern protected virtual task complete_oldest_ctrl();
  extern protected virtual task send_beat(ahb_ctrl_t ctrl, ahb_data_t data, ahb_resp_e resp);

endclass


task ahb_slave_monitor::init_component();
  ctrl_q.delete();
endtask


task ahb_slave_monitor::sample_bus();

  // ------------------------------------------------------------
  // If HREADY is high, the oldest queued transfer completes in this cycle.
  // Also, a new control phase can be accepted in the same cycle.
  // If HREADY is low, the oldest queued transfer is being stretched.
  // ------------------------------------------------------------

  if (hvif.mon_cb.hready) begin
    if (ctrl_q.size() > 0)
      complete_oldest_ctrl();

    if (hvif.mon_cb.htrans inside {NONSEQ, SEQ})
      enqueue_ctrl();
  end
  else begin
    if (ctrl_q.size() > 0)
      ctrl_q[0].wait_cycle_cnt++;
  end
endtask


function void ahb_slave_monitor::enqueue_ctrl();
  ahb_ctrl_t ctrl;

  ctrl.is_write       = hvif.mon_cb.hwrite;
  ctrl.burst          = ahb_burst_e'(hvif.mon_cb.hburst);
  ctrl.trans          = ahb_trans_e'(hvif.mon_cb.htrans);
  ctrl.addr           = hvif.mon_cb.haddr;
  ctrl.size           = ahb_size_e'(hvif.mon_cb.hsize);
  ctrl.wait_cycle_cnt = 0;
  ctrl.start_time     = $time;

  ctrl_q.push_back(ctrl);

  `uvm_info("AHB_MON",
    $sformatf("AHB control accepted: trans=%s write=%s addr=0x%0h size=%s burst=%s q_depth=%0d",
              ctrl.trans.name(),
              (ctrl.is_write ? "WRITE" : "READ"),
              ctrl.addr,
              ctrl.size.name(),
              ctrl.burst.name(),
              ctrl_q.size()),
    UVM_HIGH)
endfunction


task ahb_slave_monitor::complete_oldest_ctrl();
  ahb_ctrl_t ctrl;
  ahb_data_t data;
  ahb_resp_e resp;

  if (ctrl_q.size() == 0)
    return;

  ctrl = ctrl_q.pop_front();

  if (ctrl.is_write)
    data = hvif.mon_cb.hwdata;
  else
    data = hvif.mon_cb.hrdata;

  resp = ahb_resp_e'(hvif.mon_cb.hresp);

  send_beat(ctrl, data, resp);
endtask


task ahb_slave_monitor::send_beat(ahb_ctrl_t ctrl, ahb_data_t data, ahb_resp_e resp);
  ahb_transaction tr;

  tr = ahb_transaction::type_id::create("ahb_mon_tr", this);

  tr.start_time = ctrl.start_time;
  tr.write      = ctrl.is_write ? WRITE : READ;
  tr.burst      = ctrl.burst;
  tr.size       = ctrl.size;

  // Beat-level transaction:
  // use 1-element arrays to match your current ahb_transaction style
  tr.addr = new[1];
  tr.data = new[1];
  tr.resp = new[1];

  tr.addr[0] = ctrl.addr;
  tr.data[0] = data;
  tr.resp[0] = resp;

  `uvm_info("AHB_MON",
    $sformatf("AHB beat complete: trans=%s write=%s addr=0x%0h size=%s burst=%s resp=%s wait_cycles=%0d",
              ctrl.trans.name(),
              (ctrl.is_write ? "WRITE" : "READ"),
              ctrl.addr,
              ctrl.size.name(),
              ctrl.burst.name(),
              resp.name(),
              ctrl.wait_cycle_cnt),
    UVM_LOW)

  out_monitor_port.write(tr);
endtask

`endif
