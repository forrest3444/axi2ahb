`ifndef AXI2AHB_RESET_RECOVERY_VIRT_SEQ_SV
`define AXI2AHB_RESET_RECOVERY_VIRT_SEQ_SV

class reset_recovery_virt_seq extends base_virtual_sequence;

  `uvm_object_utils(reset_recovery_virt_seq)

  localparam string RESET_PATH = "top_tb.rstn";
  localparam int unsigned BEAT_NUM = 4;
  localparam int unsigned RESET_HOLD_CYCLES = 4;

  localparam bit [`ADDR_WIDTH-1:0] PRE_RESET_ADDR  = `ADDR_WIDTH'(32'h0000_1200);
  localparam bit [`ADDR_WIDTH-1:0] POST_RESET_ADDR = `ADDR_WIDTH'(32'h0000_2200);

  function new(string name = "reset_recovery_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    run_write_read_case(PRE_RESET_ADDR, 16'h1001, "pre-reset");
    trigger_mid_test_reset();
    check_dut_initial_state("after reset release");
    run_write_read_case(POST_RESET_ADDR, 16'h2001, "post-reset");

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag(
      "reset_recovery",
      "A triggered reset must return the DUT to an idle empty state and allow legal traffic again after reset release"
    );
  endfunction

  virtual task run_write_read_case(
    input bit [`ADDR_WIDTH-1:0] addr,
    input bit [15:0]            seed,
    input string                phase_name
  );
    axi_resp_e           bresp;
    axi_resp_e           rresp[];
    bit [`DATA_WIDTH-1:0] exp_data[];
    bit [`DATA_WIDTH-1:0] act_data[];
    bit [`DATA_WIDTH-1:0] bd_data[];

    build_data(seed, BEAT_NUM, exp_data);

    fd_write_num_beats(addr, BEAT_NUM, exp_data, bresp);
    if (bresp != axi_pkg::OKAY) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("%s write returned %s at addr 0x%0h", phase_name, bresp.name(), addr))
    end

    bd_read_num_beats(addr, BEAT_NUM, bd_data);
    compare_beat_arrays({phase_name, " backdoor"}, exp_data, bd_data);

    fd_read_num_beats(addr, BEAT_NUM, act_data, rresp);

    if (rresp.size() != BEAT_NUM) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("%s read response size mismatch: expected=%0d actual=%0d",
                  phase_name, BEAT_NUM, rresp.size()))
    end
    else begin
      foreach (rresp[beat]) begin
        if (rresp[beat] != axi_pkg::OKAY) begin
          cfg.seq_check_error++;
          `uvm_error(get_type_name(),
            $sformatf("%s read beat %0d returned %s", phase_name, beat, rresp[beat].name()))
        end
      end
    end

    compare_beat_arrays({phase_name, " frontdoor"}, exp_data, act_data);
  endtask

  virtual task trigger_mid_test_reset();
    uvm_hdl_data_t rst_val;

    `uvm_info(get_type_name(), "Triggering mid-test reset", UVM_LOW)

    rst_val = '0;
    if (!uvm_hdl_force(RESET_PATH, rst_val)) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), $sformatf("Failed to force reset via %s", RESET_PATH))
      return;
    end

    wait_reset_signal_asserted();
    wait_cycles(RESET_HOLD_CYCLES);
    check_dut_initial_state("while reset asserted");

    rst_val = '1;
    if (!uvm_hdl_force(RESET_PATH, rst_val)) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), $sformatf("Failed to drive reset release via %s", RESET_PATH))
      return;
    end

    wait_reset_signal_released();

    if (!uvm_hdl_release(RESET_PATH)) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), $sformatf("Failed to release reset override via %s", RESET_PATH))
      return;
    end

    wait_cycles(10);
  endtask

  virtual task check_dut_initial_state(input string phase_name);
    if (dvif.aw_count != 0 ||
        dvif.w_count  != 0 ||
        dvif.ar_count != 0 ||
        dvif.r_count  != 0 ||
        dvif.aw_wr_fire_dbg ||
        dvif.w_wr_fire_dbg  ||
        dvif.ar_wr_fire_dbg ||
        dvif.r_wr_fire_dbg  ||
        dvif.core_beat_launch_fire_dbg ||
        dvif.core_grant_accept_dbg     ||
        dvif.frontend_wr_req_illegal_dbg ||
        dvif.frontend_b_fire_dbg ||
        dvif.frontend_r_fire_dbg) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("DUT not in initial state %s: aw=%0d w=%0d ar=%0d r=%0d aw_fire=%0d w_fire=%0d ar_fire=%0d r_fire=%0d core_launch=%0d core_grant=%0d illegal=%0d b_fire=%0d r_fire=%0d",
                  phase_name,
                  dvif.aw_count, dvif.w_count, dvif.ar_count, dvif.r_count,
                  dvif.aw_wr_fire_dbg, dvif.w_wr_fire_dbg, dvif.ar_wr_fire_dbg, dvif.r_wr_fire_dbg,
                  dvif.core_beat_launch_fire_dbg, dvif.core_grant_accept_dbg,
                  dvif.frontend_wr_req_illegal_dbg, dvif.frontend_b_fire_dbg, dvif.frontend_r_fire_dbg))
    end
  endtask

  virtual function void build_data(
    input bit [15:0]             seed,
    input int unsigned           beat_num,
    output bit [`DATA_WIDTH-1:0] data[]
  );
    data = new[beat_num];

    foreach (data[beat]) begin
      data[beat] = {16'(seed), 16'(beat), 32'((seed << 8) ^ beat)};
    end
  endfunction

  virtual task compare_beat_arrays(
    input string                 phase_name,
    input bit [`DATA_WIDTH-1:0] exp_data[],
    input bit [`DATA_WIDTH-1:0] act_data[]
  );
    if (act_data.size() != exp_data.size()) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("%s data size mismatch: expected=%0d actual=%0d",
                  phase_name, exp_data.size(), act_data.size()))
      return;
    end

    foreach (exp_data[beat]) begin
      if (act_data[beat] != exp_data[beat]) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("%s data mismatch on beat %0d: exp=0x%0h act=0x%0h",
                    phase_name, beat, exp_data[beat], act_data[beat]))
      end
    end
  endtask

endclass

`endif
