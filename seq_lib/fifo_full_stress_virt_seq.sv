`ifndef AXI2AHB_FIFO_FULL_STRESS_VIRT_SEQ_SV
`define AXI2AHB_FIFO_FULL_STRESS_VIRT_SEQ_SV

class fifo_full_stress_virt_seq extends base_virtual_sequence;

  `uvm_object_utils(fifo_full_stress_virt_seq)

  localparam int unsigned PACKET_NUM           = 9;
  localparam int unsigned FRONT_FIFO_PKT_DEPTH = 8;
  localparam int unsigned FULL_BEAT_NUM        = 16;
  localparam int unsigned DATA_FIFO_BEAT_DEPTH = 128;
  localparam int unsigned OVER_CAP_HOLD_CYCLES = 8;
  localparam axi_size_e   FULL_BEAT_SIZE       = axi_pkg::SIZE_8B;
  localparam axi_burst_type_e FULL_BURST       = axi_pkg::INCR;

  localparam bit [`ADDR_WIDTH-1:0] FRONT_WR_BASE = `ADDR_WIDTH'(32'h0000_1000);
  localparam bit [`ADDR_WIDTH-1:0] FRONT_RD_BASE = `ADDR_WIDTH'(32'h0000_3000);
  localparam bit [`ADDR_WIDTH-1:0] BACK_R_BASE   = `ADDR_WIDTH'(32'h0000_5000);

  function new(string name = "fifo_full_stress_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    run_frontend_write_fifo_full();
    wait_for_dut_idle();

    run_frontend_read_fifo_full();
    wait_for_dut_idle();

    run_backend_return_fifo_full();
    wait_for_dut_idle();

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag(
      "fifo_full_stress",
      "Extreme FIFO backlog on frontend AW/W/AR and backend R paths must drain cleanly without deadlock, response loss, or data corruption"
    );
  endfunction

  virtual task run_frontend_write_fifo_full();
    axi_transaction      rsp;
    axi_resp_e           rsp_q[$];
    bit [`DATA_WIDTH-1:0] wr_data[PACKET_NUM][];
    bit [`DATA_WIDTH-1:0] bd_data[];
    bit [`ADDR_WIDTH-1:0] addr;

    `uvm_info(get_type_name(), "Starting frontend AW/W FIFO full-backpressure stress", UVM_LOW)

    cfg.slv_cfg.force_hready_low = 1'b1;

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      addr = FRONT_WR_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      build_packet_data(pkt, FULL_BEAT_NUM, wr_data[pkt]);
    end

    for (int unsigned pkt = 0; pkt < (PACKET_NUM - 1); pkt++) begin
      addr = FRONT_WR_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      send_write_req_no_rsp(addr, FULL_BEAT_NUM, wr_data[pkt], FULL_BURST, FULL_BEAT_SIZE);
    end

    wait_for_fifo_count("aw_count", FRONT_FIFO_PKT_DEPTH - 1);
    wait_for_fifo_count("w_count", DATA_FIFO_BEAT_DEPTH - 1);

    fork
      begin
        addr = FRONT_WR_BASE + (PACKET_NUM - 1) * FULL_BEAT_NUM * `STRB_WIDTH;
        send_write_req_no_rsp(addr, FULL_BEAT_NUM, wr_data[PACKET_NUM - 1], FULL_BURST, FULL_BEAT_SIZE);
      end
      begin
        wait_for_fifo_pressure("frontend write over-capacity", FRONT_FIFO_PKT_DEPTH, DATA_FIFO_BEAT_DEPTH, 1'b0, 1'b0);
        cfg.slv_cfg.force_hready_low = 1'b0;
      end
    join

    repeat (PACKET_NUM) begin
      get_response(rsp);
      if (rsp == null) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(), "Null write response received in frontend FIFO stress")
      end
      else begin
        rsp_q.push_back(rsp.bresp);
      end
    end

    foreach (rsp_q[idx]) begin
      if (rsp_q[idx] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Frontend write FIFO stress returned non-OKAY response on packet %0d: %s",
                    idx, rsp_q[idx].name()))
      end
    end

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      addr = FRONT_WR_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      bd_read_num_beats(addr, FULL_BEAT_NUM, bd_data);
      if (bd_data.size() != wr_data[pkt].size()) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Frontend write FIFO stress backdoor size mismatch on packet %0d: expected=%0d actual=%0d",
                    pkt, wr_data[pkt].size(), bd_data.size()))
      end
      else begin
        foreach (bd_data[beat]) begin
          if (bd_data[beat] != wr_data[pkt][beat]) begin
            cfg.seq_check_error++;
            `uvm_error(get_type_name(),
              $sformatf("Frontend write FIFO stress data mismatch on packet %0d beat %0d: exp=0x%0h act=0x%0h",
                        pkt, beat, wr_data[pkt][beat], bd_data[beat]))
          end
        end
      end
    end
  endtask

  virtual task run_frontend_read_fifo_full();
    axi_transaction      rsp;
    bit [`DATA_WIDTH-1:0] exp_data[PACKET_NUM][];
    bit [`ADDR_WIDTH-1:0] addr;

    `uvm_info(get_type_name(), "Starting frontend AR FIFO full-backpressure stress", UVM_LOW)

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      addr = FRONT_RD_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      build_packet_data(pkt + PACKET_NUM, FULL_BEAT_NUM, exp_data[pkt]);
      bd_write_num_beats(addr, FULL_BEAT_NUM, exp_data[pkt]);
    end

    cfg.slv_cfg.force_hready_low = 1'b1;

    for (int unsigned pkt = 0; pkt < (PACKET_NUM - 1); pkt++) begin
      addr = FRONT_RD_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      send_read_req_no_rsp(addr, FULL_BEAT_NUM, FULL_BURST, FULL_BEAT_SIZE);
    end

    wait_for_fifo_count("ar_count", FRONT_FIFO_PKT_DEPTH - 1);

    fork
      begin
        addr = FRONT_RD_BASE + (PACKET_NUM - 1) * FULL_BEAT_NUM * `STRB_WIDTH;
        send_read_req_no_rsp(addr, FULL_BEAT_NUM, FULL_BURST, FULL_BEAT_SIZE);
      end
      begin
        wait_for_fifo_pressure("frontend read over-capacity", FRONT_FIFO_PKT_DEPTH, 0, 1'b1, 1'b0);
        cfg.slv_cfg.force_hready_low = 1'b0;
      end
    join

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      get_response(rsp);
      check_read_response(
        $sformatf("Frontend read FIFO stress packet %0d", pkt),
        rsp,
        exp_data[pkt]
      );
    end
  endtask

  virtual task run_backend_return_fifo_full();
    axi_transaction      rsp;
    bit [`DATA_WIDTH-1:0] exp_data[PACKET_NUM][];
    bit [`ADDR_WIDTH-1:0] addr;

    `uvm_info(get_type_name(), "Starting backend R FIFO full-backpressure stress", UVM_LOW)

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      addr = BACK_R_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      build_packet_data(pkt + (2 * PACKET_NUM), FULL_BEAT_NUM, exp_data[pkt]);
      bd_write_num_beats(addr, FULL_BEAT_NUM, exp_data[pkt]);
    end

    cfg.mst_cfg.force_rready_low = 1'b1;

    for (int unsigned pkt = 0; pkt < (PACKET_NUM - 1); pkt++) begin
      addr = BACK_R_BASE + pkt * FULL_BEAT_NUM * `STRB_WIDTH;
      send_read_req_no_rsp(addr, FULL_BEAT_NUM, FULL_BURST, FULL_BEAT_SIZE);
    end

    wait_for_fifo_count("r_count", DATA_FIFO_BEAT_DEPTH - 1);

    fork
      begin
        addr = BACK_R_BASE + (PACKET_NUM - 1) * FULL_BEAT_NUM * `STRB_WIDTH;
        send_read_req_no_rsp(addr, FULL_BEAT_NUM, FULL_BURST, FULL_BEAT_SIZE);
      end
      begin
        wait_for_fifo_pressure("backend return over-capacity", 0, DATA_FIFO_BEAT_DEPTH, 1'b1, 1'b1);
        cfg.mst_cfg.force_rready_low = 1'b0;
      end
    join

    for (int unsigned pkt = 0; pkt < PACKET_NUM; pkt++) begin
      get_response(rsp);
      check_read_response(
        $sformatf("Backend return FIFO stress packet %0d", pkt),
        rsp,
        exp_data[pkt]
      );
    end
  endtask

  virtual task send_write_req_no_rsp(
    bit [`ADDR_WIDTH-1:0] addr,
    int unsigned          no_of_beats,
    bit [`DATA_WIDTH-1:0] data[],
    axi_burst_type_e      burst,
    axi_size_e            size
  );
    axi_transaction tr;
    bit             legal;
    bit [`ADDR_WIDTH-1:0] beat_addr;

    if (data.size() != no_of_beats) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("send_write_req_no_rsp data size mismatch: expect=%0d actual=%0d",
                  no_of_beats, data.size()))
      return;
    end

    check_burst_len_legal(no_of_beats, burst, legal);
    if (!legal) begin
      cfg.seq_check_error++;
      return;
    end

    `uvm_create_on(tr, p_sequencer.axi_seqr)

    tr.xact_type = axi_pkg::WRITE;
    tr.addr      = addr;
    tr.burst     = burst;
    tr.size      = size;
    tr.len       = no_of_beats;
    tr.data      = new[no_of_beats];
    tr.wstrb     = new[no_of_beats];

    foreach (tr.data[i]) begin
      tr.data[i] = data[i];
      beat_addr = calc_beat_addr(addr, i, burst, size, no_of_beats);
      tr.wstrb[i] = calc_wstrb(beat_addr, size);
    end

    `uvm_send(tr)
  endtask

  virtual task send_read_req_no_rsp(
    bit [`ADDR_WIDTH-1:0] addr,
    int unsigned          no_of_beats,
    axi_burst_type_e      burst,
    axi_size_e            size
  );
    axi_transaction tr;
    bit             legal;

    check_burst_len_legal(no_of_beats, burst, legal);
    if (!legal) begin
      cfg.seq_check_error++;
      return;
    end

    `uvm_create_on(tr, p_sequencer.axi_seqr)

    tr.xact_type = axi_pkg::READ;
    tr.addr      = addr;
    tr.burst     = burst;
    tr.size      = size;
    tr.len       = no_of_beats;
    tr.data      = new[no_of_beats];
    tr.rresp     = new[no_of_beats];

    `uvm_send(tr)
  endtask

  virtual task check_read_response(
    input string             check_name,
    input axi_transaction    rsp,
    input bit [`DATA_WIDTH-1:0] exp_data[]
  );
    if (rsp == null) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), {check_name, ": null read response"})
      return;
    end

    if (rsp.data.size() != exp_data.size()) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("%s data beat count mismatch: expected=%0d actual=%0d",
                  check_name, exp_data.size(), rsp.data.size()))
      return;
    end

    if (rsp.rresp.size() != exp_data.size()) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("%s response beat count mismatch: expected=%0d actual=%0d",
                  check_name, exp_data.size(), rsp.rresp.size()))
      return;
    end

    foreach (exp_data[beat]) begin
      if (rsp.rresp[beat] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("%s returned non-OKAY response on beat %0d: %s",
                    check_name, beat, rsp.rresp[beat].name()))
      end
      if (rsp.data[beat] != exp_data[beat]) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("%s data mismatch on beat %0d: exp=0x%0h act=0x%0h",
                    check_name, beat, exp_data[beat], rsp.data[beat]))
      end
    end
  endtask

  virtual function void build_packet_data(
    input int unsigned         packet_idx,
    input int unsigned         no_of_beats,
    output bit [`DATA_WIDTH-1:0] data[]
  );
    data = new[no_of_beats];

    foreach (data[beat]) begin
      data[beat] = {
        16'(packet_idx),
        16'(beat),
        32'((packet_idx * 32'h0101_0001) ^ beat)
      };
    end
  endfunction

  virtual task wait_for_fifo_count(
    input string       fifo_name,
    input int unsigned target_count
  );
    int unsigned sample_count;

    repeat (1024) begin
      @(posedge avif.clk);

      case (fifo_name)
        "aw_count": sample_count = dvif.aw_count;
        "w_count" : sample_count = dvif.w_count;
        "ar_count": sample_count = dvif.ar_count;
        "r_count" : sample_count = dvif.r_count;
        default   : sample_count = '0;
      endcase

      if (sample_count >= target_count)
        return;
    end

    cfg.seq_check_error++;
    `uvm_error(get_type_name(),
      $sformatf("Timed out waiting for %s to reach %0d, current=%0d",
                fifo_name, target_count, sample_count))
  endtask


  virtual task wait_for_fifo_pressure(
    input string       pressure_name,
    input int unsigned target_aw_ar_count,
    input int unsigned target_w_r_count,
    input bit          use_ar_count,
    input bit          use_r_count
  );
    int unsigned pkt_count;
    int unsigned data_count;
    bit          pkt_hit;
    bit          data_hit;

    repeat (1024) begin
      @(posedge avif.clk);

      pkt_count  = use_ar_count ? dvif.ar_count : dvif.aw_count;
      data_count = use_r_count ? dvif.r_count  : dvif.w_count;
      pkt_hit    = (target_aw_ar_count == 0) || (pkt_count  >= target_aw_ar_count);
      data_hit   = (target_w_r_count   == 0) || (data_count >= target_w_r_count);

      if (pkt_hit && data_hit) begin
        repeat (OVER_CAP_HOLD_CYCLES) @(posedge avif.clk);
        return;
      end
    end

    cfg.seq_check_error++;
    `uvm_error(get_type_name(),
      $sformatf("Timed out waiting for %s: pkt_target=%0d data_target=%0d current_pkt=%0d current_data=%0d",
                pressure_name, target_aw_ar_count, target_w_r_count, pkt_count, data_count))
  endtask

  virtual task wait_for_dut_idle();
    int unsigned idle_cycles;

    idle_cycles = 0;

    repeat (512) begin
      @(posedge avif.clk);

      if ((dvif.aw_count == 0) &&
          (dvif.w_count == 0) &&
          (dvif.ar_count == 0) &&
          (dvif.r_count == 0) &&
          !dvif.aw_wr_fire_dbg &&
          !dvif.w_wr_fire_dbg &&
          !dvif.ar_wr_fire_dbg &&
          !dvif.r_wr_fire_dbg &&
          !dvif.core_beat_launch_fire_dbg &&
          !dvif.core_grant_accept_dbg &&
          !dvif.frontend_b_fire_dbg &&
          !dvif.frontend_r_fire_dbg) begin
        idle_cycles++;
        if (idle_cycles >= 4)
          return;
      end
      else begin
        idle_cycles = 0;
      end
    end

    cfg.seq_check_error++;
    `uvm_error(get_type_name(),
      $sformatf("Timed out waiting for DUT idle: aw=%0d w=%0d ar=%0d r=%0d",
                dvif.aw_count, dvif.w_count, dvif.ar_count, dvif.r_count))
  endtask

endclass

`endif
