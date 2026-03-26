`ifndef AXI2AHB_FRONTEND_EXCEPTION_VIRT_SEQ_SV
`define AXI2AHB_FRONTEND_EXCEPTION_VIRT_SEQ_SV

class frontend_exception_virt_seq extends base_virtual_sequence;

  typedef enum int unsigned {
    EXC_UNSUPPORTED_SIZE = 0,
    EXC_UNSUPPORTED_BURST,
    EXC_UNALIGNED_INCR,
    EXC_UNALIGNED_FIXED,
    EXC_WRAP_ILLEGAL_LEN,
    EXC_WRAP_UNALIGNED,
    EXC_CROSS_1KB
  } frontend_exc_kind_e;

  `uvm_object_utils(frontend_exception_virt_seq)

  rand int unsigned        sequence_length;
  rand frontend_exc_kind_e kind[];
  rand bit                 do_write[];
  rand axi_size_e          size[];
  rand int unsigned        len[];

  axi_burst_type_e         burst[];
  bit [`ADDR_WIDTH-1:0]    addr[];
  bit [`DATA_WIDTH-1:0]    wr_data[][];

  bit [`DATA_WIDTH-1:0]    rd_data[];
  axi_resp_e               bresp;
  axi_resp_e               rresp[];

  constraint exception_traffic_c {
    sequence_length inside {[32:64]};

    kind.size()     == sequence_length;
    do_write.size() == sequence_length;
    size.size()     == sequence_length;
    len.size()      == sequence_length;

    foreach (kind[i]) kind[i] inside {
      EXC_UNSUPPORTED_SIZE,
      EXC_UNSUPPORTED_BURST,
      EXC_UNALIGNED_INCR,
      EXC_UNALIGNED_FIXED,
      EXC_WRAP_ILLEGAL_LEN,
      EXC_WRAP_UNALIGNED,
      EXC_CROSS_1KB
    };

    foreach (do_write[i]) {
      if (i > 0) do_write[i] != do_write[i-1];
    }

    foreach (size[i]) {
      if (kind[i] == EXC_UNSUPPORTED_SIZE) {
        size[i] inside {
          axi_pkg::SIZE_16B,
          axi_pkg::SIZE_32B,
          axi_pkg::SIZE_64B,
          axi_pkg::SIZE_128B
        };
      }
      else if ((kind[i] == EXC_UNALIGNED_INCR)
            || (kind[i] == EXC_UNALIGNED_FIXED)
            || (kind[i] == EXC_WRAP_UNALIGNED)) {
        size[i] inside {
          axi_pkg::SIZE_2B,
          axi_pkg::SIZE_4B,
          axi_pkg::SIZE_8B
        };
      }
      else {
        size[i] inside {
          axi_pkg::SIZE_1B,
          axi_pkg::SIZE_2B,
          axi_pkg::SIZE_4B,
          axi_pkg::SIZE_8B
        };
      }
    }

    foreach (len[i]) {
      if (kind[i] == EXC_CROSS_1KB) {
        len[i] inside {[2:8]};
      }
      else if (do_write[i] == 0) {
        len[i] == 1;
      }
      else if (kind[i] == EXC_WRAP_ILLEGAL_LEN) {
        len[i] inside {1, 3, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15};
      }
      else {
        len[i] inside {[1:8]};
      }
    }
  }

  function new(string name = "frontend_exception_virt_seq");
    super.new(name);
  endfunction

  function void post_randomize();
    burst   = new[sequence_length];
    addr    = new[sequence_length];
    wr_data = new[sequence_length];

    foreach (kind[i]) begin
      burst[i]   = select_burst(kind[i]);
      addr[i]    = build_addr(i);
      wr_data[i] = new[len[i]];

      foreach (wr_data[i][beat]) begin
        wr_data[i][beat] = {$urandom(), $urandom()};
      end
    end
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    foreach (kind[i]) begin
      if (do_write[i])
        run_illegal_write(i);
      else
        run_illegal_read(i);
    end

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag(
      "frontend_exception",
      "Frontend-rejected illegal AXI traffic must return SLVERR without entering FIFO, bridge core, or AHB execution paths"
    );
  endfunction

  virtual task run_illegal_write(int unsigned idx);
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

    send_raw_write_monitored(
      addr[idx], len[idx], burst[idx], size[idx], wr_data[idx], bresp,
      aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
      core_launch_seen, core_grant_seen, illegal_seen, b_fire_seen, r_fire_seen
    );

    sample_path_counts(aw_after, w_after, ar_after, r_after);

    if (bresp != axi_pkg::SLVERR) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal write did not return SLVERR at iteration %0d: kind=%s addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, kind_name(kind[idx]), addr[idx], len[idx], burst_name(burst[idx]), size[idx].name(), bresp.name()))
    end

    if (illegal_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal-write flag never asserted at iteration %0d: kind=%s addr=0x%0h",
                  idx, kind_name(kind[idx]), addr[idx]))
    end

    if (b_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal write did not complete on B channel at iteration %0d: kind=%s addr=0x%0h",
                  idx, kind_name(kind[idx]), addr[idx]))
    end

    check_blocked_downstream(
      idx, 1, aw_before, w_before, ar_before, r_before,
      aw_after, w_after, ar_after, r_after,
      aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
      core_launch_seen, core_grant_seen
    );
  endtask

  virtual task run_illegal_read(int unsigned idx);
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

    send_raw_read_monitored(
      addr[idx], len[idx], burst[idx], size[idx], rd_data, rresp,
      aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
      core_launch_seen, core_grant_seen, illegal_seen, b_fire_seen, r_fire_seen
    );

    sample_path_counts(aw_after, w_after, ar_after, r_after);

    if (rd_data.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal read data beat count mismatch at iteration %0d: kind=%s expected=%0d actual=%0d",
                  idx, kind_name(kind[idx]), len[idx], rd_data.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal read resp beat count mismatch at iteration %0d: kind=%s expected=%0d actual=%0d",
                  idx, kind_name(kind[idx]), len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::SLVERR) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Illegal read did not return SLVERR at iteration %0d beat %0d: kind=%s addr=0x%0h burst=%s size=%s resp=%s",
                    idx, beat, kind_name(kind[idx]), addr[idx], burst_name(burst[idx]), size[idx].name(), rresp[beat].name()))
      end

      if (rd_data[beat] != 0) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Illegal read returned non-zero data at iteration %0d beat %0d: kind=%s data=0x%0h",
                    idx, beat, kind_name(kind[idx]), rd_data[beat]))
      end
    end

    if (r_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend illegal read did not complete on R channel at iteration %0d: kind=%s addr=0x%0h",
                  idx, kind_name(kind[idx]), addr[idx]))
    end

    check_blocked_downstream(
      idx, 0, aw_before, w_before, ar_before, r_before,
      aw_after, w_after, ar_after, r_after,
      aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
      core_launch_seen, core_grant_seen
    );
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
        $sformatf("Illegal %s request changed AW FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, aw_before, aw_after))
    end

    if (w_after != w_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request changed W FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, w_before, w_after))
    end

    if (ar_after != ar_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request changed AR FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, ar_before, ar_after))
    end

    if (r_after != r_before) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request changed R FIFO occupancy at iteration %0d: before=%0d after=%0d",
                  path_name, idx, r_before, r_after))
    end

    if (aw_push_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request wrote AW FIFO at iteration %0d: pushes=%0d",
                  path_name, idx, aw_push_seen))
    end

    if (w_push_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request wrote W FIFO at iteration %0d: pushes=%0d",
                  path_name, idx, w_push_seen))
    end

    if (ar_push_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request wrote AR FIFO at iteration %0d: pushes=%0d",
                  path_name, idx, ar_push_seen))
    end

    if (r_push_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request wrote R FIFO at iteration %0d: pushes=%0d",
                  path_name, idx, r_push_seen))
    end

    if (core_launch_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request launched downstream AHB beats at iteration %0d: launches=%0d",
                  path_name, idx, core_launch_seen))
    end

    if (core_grant_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Illegal %s request reached bridge-core grant acceptance at iteration %0d: accepts=%0d",
                  path_name, idx, core_grant_seen))
    end
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

      if (dvif.aw_wr_fire_dbg)
        aw_push_seen++;
      if (dvif.w_wr_fire_dbg)
        w_push_seen++;
      if (dvif.ar_wr_fire_dbg)
        ar_push_seen++;
      if (dvif.r_wr_fire_dbg)
        r_push_seen++;
      if (dvif.core_beat_launch_fire_dbg)
        core_launch_seen++;
      if (dvif.core_grant_accept_dbg)
        core_grant_seen++;
      if (dvif.frontend_wr_req_illegal_dbg)
        illegal_seen++;
      if (dvif.frontend_b_fire_dbg)
        b_fire_seen++;
      if (dvif.frontend_r_fire_dbg)
        r_fire_seen++;
    end
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
      tr.wstrb[i] = {`STRB_WIDTH{1}};
    end

    fork
      watch_dut_activity(done, aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen, b_fire_seen, r_fire_seen);
      begin
        `uvm_send(tr)
        get_response(rsp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join

    if (rsp == null) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), "Illegal write response is null")
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
      tr.data[i]  = 0;
      tr.rresp[i] = axi_pkg::OKAY;
    end

    fork
      watch_dut_activity(done, aw_push_seen, w_push_seen, ar_push_seen, r_push_seen,
                         core_launch_seen, core_grant_seen, illegal_seen, b_fire_seen, r_fire_seen);
      begin
        `uvm_send(tr)
        get_response(rsp);
        repeat (2) @(posedge avif.clk);
        done = 1;
      end
    join

    if (rsp == null) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(), "Illegal read response is null")
      return;
    end

    data = new[rsp.data.size()];
    resp = new[rsp.rresp.size()];

    foreach (rsp.data[i]) begin
      data[i] = rsp.data[i];
    end

    foreach (rsp.rresp[i]) begin
      resp[i] = rsp.rresp[i];
    end
  endtask

  virtual function axi_burst_type_e select_burst(frontend_exc_kind_e exc_kind);
    case (exc_kind)
      EXC_UNSUPPORTED_BURST: return axi_burst_type_e'(2'b11);
      EXC_UNALIGNED_FIXED:   return axi_pkg::FIXED;
      EXC_WRAP_ILLEGAL_LEN:  return axi_pkg::WRAP;
      EXC_WRAP_UNALIGNED:    return axi_pkg::WRAP;
      default:               return axi_pkg::INCR;
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] build_addr(int unsigned idx);
    bit [`ADDR_WIDTH-1:0] addr_base;
    int unsigned          bytes;

    bytes = get_declared_bytes(size[idx]);

    if (kind[idx] == EXC_CROSS_1KB)
      return (`ADDR_WIDTH'(32'h0000_0400 - bytes));

    if (bytes > 16'h0800)
      addr_base = 0;
    else
      addr_base = `ADDR_WIDTH'(($urandom_range(16'h07ff, 0) / bytes) * bytes);

    case (kind[idx])
      EXC_UNALIGNED_INCR,
      EXC_UNALIGNED_FIXED,
      EXC_WRAP_UNALIGNED: begin
        return addr_base + 1;
      end
      default: begin
        return addr_base;
      end
    endcase
  endfunction

  virtual function int unsigned get_declared_bytes(axi_size_e burst_size);
    case (burst_size)
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

  virtual function string kind_name(frontend_exc_kind_e exc_kind);
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
