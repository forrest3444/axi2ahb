`ifndef AXI2AHB_MIXED_RANDOM_TRAFFIC_VIRT_SEQ_SV
`define AXI2AHB_MIXED_RANDOM_TRAFFIC_VIRT_SEQ_SV

class mixed_random_traffic_virt_seq extends base_virtual_sequence;

  typedef enum int unsigned {
    PKT_LEGAL = 0,
    PKT_FRONTEND,
    PKT_BACKEND
  } packet_kind_e;

  typedef enum int unsigned {
    EXC_UNSUPPORTED_SIZE = 0,
    EXC_UNSUPPORTED_BURST,
    EXC_UNALIGNED_INCR,
    EXC_UNALIGNED_FIXED,
    EXC_WRAP_ILLEGAL_LEN,
    EXC_WRAP_UNALIGNED,
    EXC_CROSS_1KB
  } frontend_exc_kind_e;

  `uvm_object_utils(mixed_random_traffic_virt_seq)

  localparam bit [`ADDR_WIDTH-1:0] LEGAL_ADDR_BASE = `ADDR_WIDTH'(32'h0000_0000);
  localparam bit [`ADDR_WIDTH-1:0] LEGAL_ADDR_LAST = `ADDR_WIDTH'(32'h0000_ffff);
  localparam bit [`ADDR_WIDTH-1:0] OOR_PAGE_BASE   = `ADDR_WIDTH'(32'h0001_0000);
  localparam bit [`ADDR_WIDTH-1:0] OOR_PAGE_LAST   = `ADDR_WIDTH'(32'h0001_03ff);

  rand int unsigned         sequence_length;
  rand packet_kind_e        pkt_kind[];
  rand frontend_exc_kind_e  fe_kind[];
  rand bit                  do_write[];
  rand axi_burst_type_e     burst[];
  rand axi_size_e           size[];
  rand int unsigned         len[];

  bit [`ADDR_WIDTH-1:0]     addr[];
  bit [63:0]                raw_data[][];

  bit [`DATA_WIDTH-1:0]     fd_beats[];
  bit [`DATA_WIDTH-1:0]     rd_data[];
  axi_resp_e                bresp;
  axi_resp_e                rresp[];

  constraint mixed_traffic_c {
    sequence_length inside {[180:240]};

    pkt_kind.size() == sequence_length;
    fe_kind.size()  == sequence_length;
    do_write.size() == sequence_length;
    burst.size()    == sequence_length;
    size.size()     == sequence_length;
    len.size()      == sequence_length;

    pkt_kind[0]  == PKT_FRONTEND;
    fe_kind[0]   == EXC_UNSUPPORTED_SIZE;
    do_write[0]  == 1'b1;
    pkt_kind[1]  == PKT_FRONTEND;
    fe_kind[1]   == EXC_UNSUPPORTED_BURST;
    do_write[1]  == 1'b0;
    pkt_kind[2]  == PKT_FRONTEND;
    fe_kind[2]   == EXC_UNALIGNED_INCR;
    do_write[2]  == 1'b1;
    pkt_kind[3]  == PKT_FRONTEND;
    fe_kind[3]   == EXC_UNALIGNED_FIXED;
    do_write[3]  == 1'b0;
    pkt_kind[4]  == PKT_FRONTEND;
    fe_kind[4]   == EXC_WRAP_ILLEGAL_LEN;
    do_write[4]  == 1'b1;
    pkt_kind[5]  == PKT_FRONTEND;
    fe_kind[5]   == EXC_WRAP_UNALIGNED;
    do_write[5]  == 1'b0;
    pkt_kind[6]  == PKT_FRONTEND;
    fe_kind[6]   == EXC_CROSS_1KB;
    do_write[6]  == 1'b1;
    pkt_kind[7]  == PKT_BACKEND;
    do_write[7]  == 1'b1;
    pkt_kind[8]  == PKT_BACKEND;
    do_write[8]  == 1'b0;
    pkt_kind[9]  == PKT_LEGAL;
    do_write[9]  == 1'b1;
    pkt_kind[10] == PKT_LEGAL;
    do_write[10] == 1'b0;

    foreach (pkt_kind[i]) {
      if (i > 10) pkt_kind[i] dist {PKT_LEGAL := 60, PKT_FRONTEND := 25, PKT_BACKEND := 15};
    }

    foreach (fe_kind[i]) {
      if (pkt_kind[i] == PKT_FRONTEND && i > 6) {
        fe_kind[i] inside {
          EXC_UNSUPPORTED_SIZE,
          EXC_UNSUPPORTED_BURST,
          EXC_UNALIGNED_INCR,
          EXC_UNALIGNED_FIXED,
          EXC_WRAP_ILLEGAL_LEN,
          EXC_WRAP_UNALIGNED,
          EXC_CROSS_1KB
        };
      }
      else if (pkt_kind[i] != PKT_FRONTEND) {
        fe_kind[i] == EXC_UNSUPPORTED_SIZE;
      }
    }

    foreach (do_write[i]) {
      if (i > 10) do_write[i] dist {1'b1 := 1, 1'b0 := 1};
    }

    foreach (burst[i]) {
      if (pkt_kind[i] == PKT_FRONTEND) {
        burst[i] == axi_pkg::INCR;
      }
      else {
        burst[i] inside {axi_pkg::FIXED, axi_pkg::INCR, axi_pkg::WRAP};
      }
    }

    foreach (size[i]) {
      if (pkt_kind[i] == PKT_FRONTEND && fe_kind[i] == EXC_UNSUPPORTED_SIZE) {
        size[i] inside {
          axi_pkg::SIZE_16B,
          axi_pkg::SIZE_32B,
          axi_pkg::SIZE_64B,
          axi_pkg::SIZE_128B
        };
      }
      else if (pkt_kind[i] == PKT_FRONTEND &&
              (fe_kind[i] == EXC_UNALIGNED_INCR ||
               fe_kind[i] == EXC_UNALIGNED_FIXED ||
               fe_kind[i] == EXC_WRAP_UNALIGNED)) {
        size[i] inside {axi_pkg::SIZE_2B, axi_pkg::SIZE_4B, axi_pkg::SIZE_8B};
      }
      else {
        size[i] inside {axi_pkg::SIZE_1B, axi_pkg::SIZE_2B, axi_pkg::SIZE_4B, axi_pkg::SIZE_8B};
      }
    }

    foreach (len[i]) {
      if (pkt_kind[i] == PKT_FRONTEND && fe_kind[i] == EXC_CROSS_1KB) {
        len[i] inside {[2:8]};
      }
      else if (pkt_kind[i] == PKT_FRONTEND && fe_kind[i] == EXC_WRAP_ILLEGAL_LEN) {
        len[i] inside {1, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15};
      }
      else if (pkt_kind[i] == PKT_FRONTEND && !do_write[i]) {
        len[i] == 1;
      }
      else if (pkt_kind[i] != PKT_FRONTEND && burst[i] == axi_pkg::WRAP) {
        len[i] inside {2, 4, 8, 16};
      }
      else {
        len[i] inside {[1:16]};
      }
    }
  }

  function new(string name = "mixed_random_traffic_virt_seq");
    super.new(name);
  endfunction

  function void post_randomize();
    addr     = new[sequence_length];
    raw_data = new[sequence_length];

    foreach (pkt_kind[i]) begin
      if (pkt_kind[i] == PKT_FRONTEND)
        burst[i] = select_frontend_burst(fe_kind[i]);

      addr[i]     = build_addr(i);
      raw_data[i] = new[len[i]];

      foreach (raw_data[i][beat]) begin
        raw_data[i][beat] = {$urandom(), $urandom()};
      end
    end
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    foreach (pkt_kind[i]) begin
      wait_for_dut_idle();

      case (pkt_kind[i])
        PKT_LEGAL: begin
          if (do_write[i]) run_legal_write(i);
          else             run_legal_read(i);
        end
        PKT_FRONTEND: begin
          if (do_write[i]) run_frontend_illegal_write(i);
          else             run_frontend_illegal_read(i);
        end
        PKT_BACKEND: begin
          if (do_write[i]) run_backend_illegal_write(i);
          else             run_backend_illegal_read(i);
        end
      endcase

      wait_for_dut_idle();
    end

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag(
      "mixed_random_traffic",
      "Interleave legal traffic with frontend and backend illegal packets to stress DUT robustness under mixed operating conditions"
    );
  endfunction

  virtual task run_legal_write(int unsigned idx);
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    build_frontdoor_beats(idx, fd_beats);
    bresp = axi_pkg::OKAY;

    send_write_monitored(idx, fd_beats, bresp,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);

    if (bresp != axi_pkg::OKAY) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal write returned unexpected response at iteration %0d: addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, addr[idx], len[idx], burst_name(burst[idx]), size[idx].name(), bresp.name()))
    end

    if (aw_push_seen == 0 || w_push_seen == 0 || core_launch_seen == 0 || core_grant_seen == 0 || b_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal write did not traverse normal path at iteration %0d: aw_push=%0d w_push=%0d launch=%0d grant=%0d b_fire=%0d",
                  idx, aw_push_seen, w_push_seen, core_launch_seen, core_grant_seen, b_fire_seen))
    end

    if (ar_push_seen != 0 || r_push_seen != 0 || r_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal write showed unexpected read-path activity at iteration %0d: ar_push=%0d r_push=%0d r_fire=%0d",
                  idx, ar_push_seen, r_push_seen, r_fire_seen))
    end
  endtask

  virtual task run_legal_read(int unsigned idx);
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    rd_data = new[0];
    rresp   = new[0];

    send_read_monitored(idx, rd_data, rresp,
                        aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                        core_launch_seen, core_grant_seen, illegal_seen,
                        b_fire_seen, r_fire_seen);

    if (rd_data.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal read data beat count mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rd_data.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal read response beat count mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Legal read returned unexpected response at iteration %0d beat %0d: addr=0x%0h burst=%s size=%s resp=%s",
                    idx, beat, addr[idx], burst_name(burst[idx]), size[idx].name(), rresp[beat].name()))
      end
    end

    if (ar_push_seen == 0 || r_push_seen == 0 || core_launch_seen == 0 || core_grant_seen == 0 || r_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal read did not traverse normal path at iteration %0d: ar_push=%0d r_push=%0d launch=%0d grant=%0d r_fire=%0d",
                  idx, ar_push_seen, r_push_seen, core_launch_seen, core_grant_seen, r_fire_seen))
    end

    if (aw_push_seen != 0 || w_push_seen != 0 || b_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Legal read showed unexpected write-path activity at iteration %0d: aw_push=%0d w_push=%0d b_fire=%0d",
                  idx, aw_push_seen, w_push_seen, b_fire_seen))
    end
  endtask

  virtual task run_frontend_illegal_write(int unsigned idx);
    int unsigned aw_before;
    int unsigned w_before;
    int unsigned ar_before;
    int unsigned r_before;
    int unsigned aw_after;
    int unsigned w_after;
    int unsigned ar_after;
    int unsigned r_after;
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    sample_path_counts(aw_before, w_before, ar_before, r_before);
    bresp = axi_pkg::OKAY;

    send_raw_write_monitored(addr[idx], len[idx], burst[idx], size[idx], raw_data[idx], bresp,
                             aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                             core_launch_seen, core_grant_seen, illegal_seen,
                             b_fire_seen, r_fire_seen);

    sample_path_counts(aw_after, w_after, ar_after, r_after);

    if (bresp != axi_pkg::SLVERR) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal write did not return SLVERR at iteration %0d: kind=%s addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, frontend_kind_name(fe_kind[idx]), addr[idx], len[idx], burst_name(burst[idx]), size[idx].name(), bresp.name()))
    end

    if (illegal_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal write was not flagged as illegal at iteration %0d: kind=%s addr=0x%0h",
                  idx, frontend_kind_name(fe_kind[idx]), addr[idx]))
    end

    if (b_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal write did not complete on B channel at iteration %0d: kind=%s addr=0x%0h",
                  idx, frontend_kind_name(fe_kind[idx]), addr[idx]))
    end

    check_blocked_downstream(idx, 1'b1,
                             aw_before, w_before, ar_before, r_before,
                             aw_after, w_after, ar_after, r_after,
                             aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                             core_launch_seen, core_grant_seen);
  endtask

  virtual task run_frontend_illegal_read(int unsigned idx);
    int unsigned aw_before;
    int unsigned w_before;
    int unsigned ar_before;
    int unsigned r_before;
    int unsigned aw_after;
    int unsigned w_after;
    int unsigned ar_after;
    int unsigned r_after;
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    rd_data = new[0];
    rresp   = new[0];

    sample_path_counts(aw_before, w_before, ar_before, r_before);

    send_raw_read_monitored(addr[idx], len[idx], burst[idx], size[idx], rd_data, rresp,
                            aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                            core_launch_seen, core_grant_seen, illegal_seen,
                            b_fire_seen, r_fire_seen);

    sample_path_counts(aw_after, w_after, ar_after, r_after);

    if (rd_data.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal read data beat count mismatch at iteration %0d: kind=%s expected=%0d actual=%0d",
                  idx, frontend_kind_name(fe_kind[idx]), len[idx], rd_data.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal read response beat count mismatch at iteration %0d: kind=%s expected=%0d actual=%0d",
                  idx, frontend_kind_name(fe_kind[idx]), len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::SLVERR) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Frontend illegal read did not return SLVERR at iteration %0d beat %0d: kind=%s addr=0x%0h burst=%s size=%s resp=%s",
                    idx, beat, frontend_kind_name(fe_kind[idx]), addr[idx], burst_name(burst[idx]), size[idx].name(), rresp[beat].name()))
      end
      if (rd_data[beat] != '0) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Frontend illegal read returned non-zero data at iteration %0d beat %0d: kind=%s data=0x%0h",
                    idx, beat, frontend_kind_name(fe_kind[idx]), rd_data[beat]))
      end
    end

    if (r_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal read did not complete on R channel at iteration %0d: kind=%s addr=0x%0h",
                  idx, frontend_kind_name(fe_kind[idx]), addr[idx]))
    end

    check_blocked_downstream(idx, 1'b0,
                             aw_before, w_before, ar_before, r_before,
                             aw_after, w_after, ar_after, r_after,
                             aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                             core_launch_seen, core_grant_seen);
  endtask

  virtual task run_backend_illegal_write(int unsigned idx);
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    build_frontdoor_beats(idx, fd_beats);
    bresp = axi_pkg::OKAY;

    send_write_monitored(idx, fd_beats, bresp,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);

    if (bresp != axi_pkg::SLVERR) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal write did not return SLVERR at iteration %0d: addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, addr[idx], len[idx], burst_name(burst[idx]), size[idx].name(), bresp.name()))
    end

    if (aw_push_seen == 0 || w_push_seen == 0 || core_launch_seen == 0 || core_grant_seen == 0 || b_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal write did not reach normal/backend path at iteration %0d: aw_push=%0d w_push=%0d launch=%0d grant=%0d b_fire=%0d",
                  idx, aw_push_seen, w_push_seen, core_launch_seen, core_grant_seen, b_fire_seen))
    end

    if (ar_push_seen != 0 || r_push_seen != 0 || r_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal write showed unexpected read-path activity at iteration %0d: ar_push=%0d r_push=%0d r_fire=%0d",
                  idx, ar_push_seen, r_push_seen, r_fire_seen))
    end
  endtask

  virtual task run_backend_illegal_read(int unsigned idx);
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    rd_data = new[0];
    rresp   = new[0];

    send_read_monitored(idx, rd_data, rresp,
                        aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                        core_launch_seen, core_grant_seen, illegal_seen,
                        b_fire_seen, r_fire_seen);

    if (rd_data.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal read data beat count mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rd_data.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal read response beat count mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::SLVERR) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Backend illegal read did not return SLVERR at iteration %0d beat %0d: addr=0x%0h burst=%s size=%s resp=%s",
                    idx, beat, addr[idx], burst_name(burst[idx]), size[idx].name(), rresp[beat].name()))
      end
      if (rd_data[beat] != '0) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Backend illegal read returned non-zero data at iteration %0d beat %0d: addr=0x%0h data=0x%0h",
                    idx, beat, addr[idx], rd_data[beat]))
      end
    end

    if (ar_push_seen == 0 || r_push_seen == 0 || core_launch_seen == 0 || core_grant_seen == 0 || r_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal read did not reach normal/backend path at iteration %0d: ar_push=%0d r_push=%0d launch=%0d grant=%0d r_fire=%0d",
                  idx, ar_push_seen, r_push_seen, core_launch_seen, core_grant_seen, r_fire_seen))
    end

    if (aw_push_seen != 0 || w_push_seen != 0 || b_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend illegal read showed unexpected write-path activity at iteration %0d: aw_push=%0d w_push=%0d b_fire=%0d",
                  idx, aw_push_seen, w_push_seen, b_fire_seen))
    end
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

  virtual task sample_path_counts(
    output int unsigned aw_count_val,
    output int unsigned w_count_val,
    output int unsigned ar_count_val,
    output int unsigned r_count_val
  );
    aw_count_val = dvif.aw_count;
    w_count_val  = dvif.w_count;
    ar_count_val = dvif.ar_count;
    r_count_val  = dvif.r_count;
  endtask

  virtual task check_blocked_downstream(
    input int unsigned idx,
    input bit          is_write,
    input int unsigned aw_before,
    input int unsigned w_before,
    input int unsigned ar_before,
    input int unsigned r_before,
    input int unsigned aw_after,
    input int unsigned w_after,
    input int unsigned ar_after,
    input int unsigned r_after,
    input int unsigned aw_push_seen,
    input int unsigned w_push_seen,
    input int unsigned ar_push_seen,
    input int unsigned r_push_seen,
    input int unsigned core_launch_seen,
    input int unsigned core_grant_seen
  );
    string path_name;

    path_name = is_write ? "write" : "read";

    if (aw_after != aw_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s changed AW FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, aw_before, aw_after))
    end
    if (w_after != w_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s changed W FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, w_before, w_after))
    end
    if (ar_after != ar_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s changed AR FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, ar_before, ar_after))
    end
    if (r_after != r_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s changed R FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, r_before, r_after))
    end
    if (aw_push_seen != 0 || w_push_seen != 0 || ar_push_seen != 0 || r_push_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s wrote downstream FIFOs at iteration %0d: aw_push=%0d w_push=%0d ar_push=%0d r_push=%0d",
                  path_name, idx, aw_push_seen, w_push_seen, ar_push_seen, r_push_seen))
    end
    if (core_launch_seen != 0 || core_grant_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal %s reached bridge backend at iteration %0d: launches=%0d grants=%0d",
                  path_name, idx, core_launch_seen, core_grant_seen))
    end
  endtask

  virtual task watch_dut_activity(
    ref bit done,
    output int unsigned aw_push_seen,
    output int unsigned w_push_seen,
    output int unsigned ar_push_seen,
    output int unsigned r_push_seen,
    output int unsigned core_launch_seen,
    output int unsigned core_grant_seen,
    output int unsigned illegal_seen,
    output int unsigned b_fire_seen,
    output int unsigned r_fire_seen
  );
    aw_push_seen     = 0;
    w_push_seen      = 0;
    ar_push_seen     = 0;
    r_push_seen      = 0;
    core_launch_seen = 0;
    core_grant_seen  = 0;
    illegal_seen     = 0;
    b_fire_seen      = 0;
    r_fire_seen      = 0;

    while (done == 0) begin
      @(posedge avif.clk);
      if (dvif.aw_wr_fire_dbg) aw_push_seen++;
      if (dvif.w_wr_fire_dbg) w_push_seen++;
      if (dvif.ar_wr_fire_dbg) ar_push_seen++;
      if (dvif.r_wr_fire_dbg) r_push_seen++;
      if (dvif.core_beat_launch_fire_dbg) core_launch_seen++;
      if (dvif.core_grant_accept_dbg) core_grant_seen++;
      if (dvif.frontend_wr_req_illegal_dbg) illegal_seen++;
      if (dvif.frontend_b_fire_dbg) b_fire_seen++;
      if (dvif.frontend_r_fire_dbg) r_fire_seen++;
    end
  endtask

  virtual task send_write_monitored(
    input int unsigned           idx,
    input bit [`DATA_WIDTH-1:0]  beats[],
    output axi_resp_e            resp,
    output int unsigned          aw_push_seen,
    output int unsigned          w_push_seen,
    output int unsigned          ar_push_seen,
    output int unsigned          r_push_seen,
    output int unsigned          core_launch_seen,
    output int unsigned          core_grant_seen,
    output int unsigned          illegal_seen,
    output int unsigned          b_fire_seen,
    output int unsigned          r_fire_seen
  );
    bit done;

    resp = axi_pkg::OKAY;
    done = 0;

    fork
      watch_dut_activity(done,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);
      begin
        fd_write_burst(addr[idx], len[idx], beats, burst[idx], size[idx], resp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join
  endtask

  virtual task send_read_monitored(
    input int unsigned           idx,
    output bit [`DATA_WIDTH-1:0] beats[],
    output axi_resp_e            resp[],
    output int unsigned          aw_push_seen,
    output int unsigned          w_push_seen,
    output int unsigned          ar_push_seen,
    output int unsigned          r_push_seen,
    output int unsigned          core_launch_seen,
    output int unsigned          core_grant_seen,
    output int unsigned          illegal_seen,
    output int unsigned          b_fire_seen,
    output int unsigned          r_fire_seen
  );
    bit done;

    beats = new[0];
    resp  = new[0];
    done  = 0;

    fork
      watch_dut_activity(done,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);
      begin
        fd_read_burst(addr[idx], len[idx], burst[idx], size[idx], beats, resp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join
  endtask

  virtual task send_raw_write_monitored(
    input bit [`ADDR_WIDTH-1:0]   req_addr,
    input int unsigned            req_len,
    input axi_burst_type_e        req_burst,
    input axi_size_e              req_size,
    input bit [`DATA_WIDTH-1:0]   req_data[],
    output axi_resp_e             resp,
    output int unsigned           aw_push_seen,
    output int unsigned           w_push_seen,
    output int unsigned           ar_push_seen,
    output int unsigned           r_push_seen,
    output int unsigned           core_launch_seen,
    output int unsigned           core_grant_seen,
    output int unsigned           illegal_seen,
    output int unsigned           b_fire_seen,
    output int unsigned           r_fire_seen
  );
    axi_transaction tr;
    axi_transaction rsp;
    bit done;

    resp = axi_pkg::OKAY;
    done = 0;

    `uvm_create_on(tr, p_sequencer.axi_seqr)

    tr.xact_type = axi_pkg::WRITE;
    tr.addr      = req_addr;
    tr.burst     = req_burst;
    tr.size      = req_size;
    tr.len       = req_len;
    tr.data      = new[req_len];
    tr.wstrb     = new[req_len];
    tr.rresp     = new[0];

    foreach (tr.data[i]) begin
      tr.data[i]  = req_data[i];
      tr.wstrb[i] = {`STRB_WIDTH{1'b1}};
    end

    fork
      watch_dut_activity(done,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);
      begin
        `uvm_send(tr)
        get_response(rsp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join

    if (rsp == null) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), "Mixed frontend illegal write response is null")
      resp = axi_pkg::SLVERR;
      return;
    end

    resp = rsp.bresp;
  endtask

  virtual task send_raw_read_monitored(
    input bit [`ADDR_WIDTH-1:0]   req_addr,
    input int unsigned            req_len,
    input axi_burst_type_e        req_burst,
    input axi_size_e              req_size,
    output bit [`DATA_WIDTH-1:0]  data[],
    output axi_resp_e             resp[],
    output int unsigned           aw_push_seen,
    output int unsigned           w_push_seen,
    output int unsigned           ar_push_seen,
    output int unsigned           r_push_seen,
    output int unsigned           core_launch_seen,
    output int unsigned           core_grant_seen,
    output int unsigned           illegal_seen,
    output int unsigned           b_fire_seen,
    output int unsigned           r_fire_seen
  );
    axi_transaction tr;
    axi_transaction rsp;
    bit done;

    data = new[0];
    resp = new[0];
    done = 0;

    `uvm_create_on(tr, p_sequencer.axi_seqr)

    tr.xact_type = axi_pkg::READ;
    tr.addr      = req_addr;
    tr.burst     = req_burst;
    tr.size      = req_size;
    tr.len       = req_len;
    tr.data      = new[req_len];
    tr.rresp     = new[req_len];
    tr.wstrb     = new[0];

    foreach (tr.data[i]) begin
      tr.data[i]  = '0;
      tr.rresp[i] = axi_pkg::OKAY;
    end

    fork
      watch_dut_activity(done,
                         aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen,
                         b_fire_seen, r_fire_seen);
      begin
        `uvm_send(tr)
        get_response(rsp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join

    if (rsp == null) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), "Mixed frontend illegal read response is null")
      return;
    end

    data = new[rsp.data.size()];
    resp = new[rsp.rresp.size()];

    foreach (rsp.data[i]) data[i] = rsp.data[i];
    foreach (rsp.rresp[i]) resp[i] = rsp.rresp[i];
  endtask

  virtual task build_frontdoor_beats(
    input int unsigned idx,
    output bit [`DATA_WIDTH-1:0] beats[]
  );
    bit [`ADDR_WIDTH-1:0] beat_addr;

    beats = new[len[idx]];
    for (int beat = 0; beat < len[idx]; beat++) begin
      beat_addr   = calc_beat_addr(addr[idx], beat, burst[idx], size[idx], len[idx]);
      beats[beat] = pack_frontdoor_payload(beat_addr, size[idx], raw_data[idx][beat]);
    end
  endtask

  virtual function bit [63:0] pack_frontdoor_payload(
    input bit [`ADDR_WIDTH-1:0] beat_addr,
    input axi_size_e            beat_size,
    input bit [63:0]            payload
  );
    bit [63:0] beat_word;
    int unsigned byte_off;

    beat_word = '0;
    byte_off  = beat_addr[$clog2(`STRB_WIDTH)-1:0];

    case (beat_size)
      axi_pkg::SIZE_1B: beat_word[byte_off*8 +: 8]  = payload[7:0];
      axi_pkg::SIZE_2B: beat_word[byte_off*8 +: 16] = payload[15:0];
      axi_pkg::SIZE_4B: beat_word[byte_off*8 +: 32] = payload[31:0];
      axi_pkg::SIZE_8B: beat_word                    = payload;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported size for payload packing: %s", beat_size.name()))
      end
    endcase

    return beat_word;
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] build_addr(int unsigned idx);
    case (pkt_kind[idx])
      PKT_FRONTEND: return build_frontend_addr(idx);
      PKT_BACKEND:  return build_backend_addr(idx);
      default:      return build_legal_addr(idx);
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] build_legal_addr(int unsigned idx);
    bit [`ADDR_WIDTH-1:0] page_base;
    bit [`ADDR_WIDTH-1:0] page_last;
    bit [`ADDR_WIDTH-1:0] wrap_base;
    int unsigned          beat_bytes;
    int unsigned          burst_bytes;
    int unsigned          wrap_offset;
    int unsigned          num_pages;

    beat_bytes  = get_supported_bytes(size[idx]);
    burst_bytes = len[idx] * beat_bytes;
    num_pages   = ((LEGAL_ADDR_LAST + 1) / 32'h400);
    page_base   = `ADDR_WIDTH'($urandom_range(num_pages - 1, 0) * 32'h400);
    page_last   = page_base + 32'h3ff;

    case (burst[idx])
      axi_pkg::WRAP: begin
        wrap_base = pick_aligned_addr(page_base, page_last, burst_bytes, burst_bytes);
        wrap_offset = $urandom_range(len[idx] - 1, 0);
        return wrap_base + wrap_offset * beat_bytes;
      end
      axi_pkg::INCR: begin
        return pick_aligned_addr(page_base, page_last, beat_bytes, burst_bytes);
      end
      default: begin
        return pick_aligned_addr(page_base, page_last, beat_bytes, beat_bytes);
      end
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] build_backend_addr(int unsigned idx);
    bit [`ADDR_WIDTH-1:0] wrap_base;
    int unsigned          beat_bytes;
    int unsigned          burst_bytes;
    int unsigned          wrap_offset;

    beat_bytes  = get_supported_bytes(size[idx]);
    burst_bytes = len[idx] * beat_bytes;

    case (burst[idx])
      axi_pkg::WRAP: begin
        wrap_base   = pick_aligned_addr(OOR_PAGE_BASE, OOR_PAGE_LAST, burst_bytes, burst_bytes);
        wrap_offset = $urandom_range(len[idx] - 1, 0);
        return wrap_base + wrap_offset * beat_bytes;
      end
      axi_pkg::INCR: begin
        return pick_aligned_addr(OOR_PAGE_BASE, OOR_PAGE_LAST, beat_bytes, burst_bytes);
      end
      default: begin
        return pick_aligned_addr(OOR_PAGE_BASE, OOR_PAGE_LAST, beat_bytes, beat_bytes);
      end
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] build_frontend_addr(int unsigned idx);
    bit [`ADDR_WIDTH-1:0] addr_base;
    int unsigned          bytes;

    bytes = get_declared_bytes(size[idx]);

    if (fe_kind[idx] == EXC_CROSS_1KB)
      return `ADDR_WIDTH'(32'h0000_0400 - bytes);

    if (bytes > 16'h0800)
      addr_base = '0;
    else
      addr_base = `ADDR_WIDTH'(($urandom_range(16'h07ff, 0) / bytes) * bytes);

    case (fe_kind[idx])
      EXC_UNALIGNED_INCR,
      EXC_UNALIGNED_FIXED,
      EXC_WRAP_UNALIGNED: return addr_base + 1;
      default:            return addr_base;
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] pick_aligned_addr(
    input bit [`ADDR_WIDTH-1:0] low_addr,
    input bit [`ADDR_WIDTH-1:0] high_addr,
    input int unsigned          align_bytes,
    input int unsigned          span_bytes
  );
    int unsigned min_slot;
    int unsigned max_slot;
    int unsigned pick_slot;

    min_slot = low_addr / align_bytes;
    max_slot = (high_addr + 1 - span_bytes) / align_bytes;

    if ((high_addr + 1) < span_bytes || min_slot > max_slot) begin
      `uvm_fatal(get_type_name(),
        $sformatf("No aligned address available: low=0x%0h high=0x%0h align=%0d span=%0d",
                  low_addr, high_addr, align_bytes, span_bytes))
      return low_addr;
    end

    pick_slot = $urandom_range(max_slot, min_slot);
    return `ADDR_WIDTH'(pick_slot * align_bytes);
  endfunction

  virtual function axi_burst_type_e select_frontend_burst(frontend_exc_kind_e exc_kind);
    case (exc_kind)
      EXC_UNSUPPORTED_BURST: return axi_burst_type_e'(2'b11);
      EXC_UNALIGNED_FIXED:   return axi_pkg::FIXED;
      EXC_WRAP_ILLEGAL_LEN:  return axi_pkg::WRAP;
      EXC_WRAP_UNALIGNED:    return axi_pkg::WRAP;
      default:               return axi_pkg::INCR;
    endcase
  endfunction

  virtual function int unsigned get_supported_bytes(axi_size_e beat_size);
    case (beat_size)
      axi_pkg::SIZE_1B: return 1;
      axi_pkg::SIZE_2B: return 2;
      axi_pkg::SIZE_4B: return 4;
      axi_pkg::SIZE_8B: return 8;
      default: begin
        `uvm_fatal(get_type_name(), $sformatf("Unsupported legal/backend AXI size: %s", beat_size.name()))
        return 1;
      end
    endcase
  endfunction

  virtual function int unsigned get_declared_bytes(axi_size_e beat_size);
    case (beat_size)
      axi_pkg::SIZE_1B:   return 1;
      axi_pkg::SIZE_2B:   return 2;
      axi_pkg::SIZE_4B:   return 4;
      axi_pkg::SIZE_8B:   return 8;
      axi_pkg::SIZE_16B:  return 16;
      axi_pkg::SIZE_32B:  return 32;
      axi_pkg::SIZE_64B:  return 64;
      axi_pkg::SIZE_128B: return 128;
      default:            return 1;
    endcase
  endfunction

  virtual function string frontend_kind_name(frontend_exc_kind_e exc_kind);
    case (exc_kind)
      EXC_UNSUPPORTED_SIZE: return "unsupported_size";
      EXC_UNSUPPORTED_BURST: return "unsupported_burst";
      EXC_UNALIGNED_INCR: return "unaligned_incr";
      EXC_UNALIGNED_FIXED: return "unaligned_fixed";
      EXC_WRAP_ILLEGAL_LEN: return "wrap_illegal_len";
      EXC_WRAP_UNALIGNED: return "wrap_unaligned";
      EXC_CROSS_1KB: return "cross_1kb";
      default: return "unknown";
    endcase
  endfunction

  virtual function string burst_name(axi_burst_type_e burst_kind);
    case (burst_kind)
      axi_pkg::FIXED: return "FIXED";
      axi_pkg::INCR:  return "INCR";
      axi_pkg::WRAP:  return "WRAP";
      default:        return $sformatf("0x%0h", burst_kind);
    endcase
  endfunction

endclass

`endif
