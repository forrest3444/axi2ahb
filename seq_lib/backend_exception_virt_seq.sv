`ifndef AXI2AHB_BACKEND_EXCEPTION_VIRT_SEQ_SV
`define AXI2AHB_BACKEND_EXCEPTION_VIRT_SEQ_SV

class backend_exception_virt_seq extends base_virtual_sequence;

  `uvm_object_utils(backend_exception_virt_seq)

  localparam bit [`ADDR_WIDTH-1:0] OOR_PAGE_BASE = `ADDR_WIDTH'(32'h0001_0000);
  localparam bit [`ADDR_WIDTH-1:0] OOR_PAGE_LAST = `ADDR_WIDTH'(32'h0001_03ff);

  rand int unsigned    sequence_length;
  rand axi_burst_type_e burst[];
  rand axi_size_e      size[];
  rand int unsigned    len[];
  rand int unsigned    beat_bytes[];
  rand int unsigned    burst_bytes[];
  rand bit [`ADDR_WIDTH-1:0] addr[];
  rand bit [`ADDR_WIDTH-1:0] wrap_base_addr[];
  rand int unsigned    wrap_offset[];
  rand bit             do_write[];
  rand bit [63:0]      data[][];

  bit [`DATA_WIDTH-1:0] fd_beats[];
  bit [`DATA_WIDTH-1:0] fd_read_beats[];
  axi_resp_e            bresp;
  axi_resp_e            rresp[];

  constraint backend_exception_c {
    sequence_length inside {[16:32]};

    solve burst before len;
    solve size before beat_bytes;
    solve len before burst_bytes;
    solve beat_bytes before burst_bytes;
    solve burst_bytes before wrap_base_addr;
    solve wrap_base_addr before addr;
    solve beat_bytes before addr;

    burst.size()          == sequence_length;
    size.size()           == sequence_length;
    len.size()            == sequence_length;
    beat_bytes.size()     == sequence_length;
    burst_bytes.size()    == sequence_length;
    addr.size()           == sequence_length;
    wrap_base_addr.size() == sequence_length;
    wrap_offset.size()    == sequence_length;
    do_write.size()       == sequence_length;
    data.size()           == sequence_length;

    foreach (burst[i]) burst[i] inside {
      axi_pkg::FIXED,
      axi_pkg::INCR,
      axi_pkg::WRAP
    };

    foreach (size[i]) size[i] inside {
      axi_pkg::SIZE_1B,
      axi_pkg::SIZE_2B,
      axi_pkg::SIZE_4B,
      axi_pkg::SIZE_8B
    };

    foreach (beat_bytes[i]) {
      if (size[i] == axi_pkg::SIZE_1B) beat_bytes[i] == 1;
      else if (size[i] == axi_pkg::SIZE_2B) beat_bytes[i] == 2;
      else if (size[i] == axi_pkg::SIZE_4B) beat_bytes[i] == 4;
      else if (size[i] == axi_pkg::SIZE_8B) beat_bytes[i] == 8;
    }

    foreach (len[i]) {
      if (burst[i] == axi_pkg::WRAP) len[i] inside {2, 4, 8, 16};
      else                           len[i] inside {[1:16]};
    }

    foreach (burst_bytes[i]) burst_bytes[i] == len[i] * beat_bytes[i];
    foreach (data[i]) data[i].size() == len[i];

    foreach (do_write[i]) {
      if (i == 0) do_write[i] == 1'b1;
      else        do_write[i] != do_write[i-1];
    }

    foreach (wrap_base_addr[i]) {
      if (burst[i] == axi_pkg::WRAP) {
        wrap_base_addr[i] >= OOR_PAGE_BASE;
        wrap_base_addr[i] <= OOR_PAGE_LAST;
        (wrap_base_addr[i] % burst_bytes[i]) == 0;
        wrap_base_addr[i] + burst_bytes[i] - 1 <= OOR_PAGE_LAST;
      }
      else {
        wrap_base_addr[i] == '0;
      }
    }

    foreach (wrap_offset[i]) {
      if (burst[i] == axi_pkg::WRAP) wrap_offset[i] inside {[0:len[i]-1]};
      else                           wrap_offset[i] == 0;
    }

    foreach (addr[i]) {
      if (burst[i] == axi_pkg::WRAP) {
        addr[i] == wrap_base_addr[i] + (wrap_offset[i] * beat_bytes[i]);
      }
      else if (burst[i] == axi_pkg::INCR) {
        addr[i] >= OOR_PAGE_BASE;
        addr[i] <= OOR_PAGE_LAST;
        (addr[i] % beat_bytes[i]) == 0;
        addr[i] + burst_bytes[i] - 1 <= OOR_PAGE_LAST;
      }
      else {
        addr[i] >= OOR_PAGE_BASE;
        addr[i] <= OOR_PAGE_LAST;
        (addr[i] % beat_bytes[i]) == 0;
        addr[i] + beat_bytes[i] - 1 <= OOR_PAGE_LAST;
      }
    }
  }

  function new(string name = "backend_exception_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    foreach (addr[i]) begin
      if (do_write[i])
        run_write(i);
      else
        run_read(i);
    end

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag(
      "backend_exception",
      "Out-of-range backend accesses must pass the AXI frontend, reach the backend, and return SLVERR"
    );
  endfunction

  virtual task run_write(int unsigned idx);
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

    send_write_monitored(
      idx,
      fd_beats,
      bresp,
      aw_push_seen,
      w_push_seen,
      ar_push_seen,
      r_push_seen,
      core_launch_seen,
      core_grant_seen,
      illegal_seen,
      b_fire_seen,
      r_fire_seen
    );

    if (bresp != axi_pkg::SLVERR) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write did not return SLVERR at iteration %0d: addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, addr[idx], len[idx], burst[idx].name(), size[idx].name(), bresp.name()))
    end

    if (aw_push_seen == 0 || w_push_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write did not enter normal frontend FIFOs at iteration %0d: aw_push=%0d w_push=%0d",
                  idx, aw_push_seen, w_push_seen))
    end

    if (core_launch_seen == 0 || core_grant_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write did not reach backend execution at iteration %0d: launches=%0d grants=%0d",
                  idx, core_launch_seen, core_grant_seen))
    end

    if (illegal_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write was unexpectedly intercepted by frontend at iteration %0d: illegal_seen=%0d",
                  idx, illegal_seen))
    end

    if (b_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write never completed on B channel at iteration %0d", idx))
    end

    if (ar_push_seen != 0 || r_push_seen != 0 || r_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception write showed unexpected read-path activity at iteration %0d: ar_push=%0d r_push=%0d r_fire=%0d",
                  idx, ar_push_seen, r_push_seen, r_fire_seen))
    end
  endtask

  virtual task run_read(int unsigned idx);
    int unsigned aw_push_seen;
    int unsigned w_push_seen;
    int unsigned ar_push_seen;
    int unsigned r_push_seen;
    int unsigned core_launch_seen;
    int unsigned core_grant_seen;
    int unsigned illegal_seen;
    int unsigned b_fire_seen;
    int unsigned r_fire_seen;

    fd_read_beats = new[0];
    rresp         = new[0];

    send_read_monitored(
      idx,
      fd_read_beats,
      rresp,
      aw_push_seen,
      w_push_seen,
      ar_push_seen,
      r_push_seen,
      core_launch_seen,
      core_grant_seen,
      illegal_seen,
      b_fire_seen,
      r_fire_seen
    );

    if (fd_read_beats.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read data size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], fd_read_beats.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read resp size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::SLVERR) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Backend exception read did not return SLVERR at iteration %0d beat %0d: burst=%s size=%s resp=%s",
                    idx, beat, burst[idx].name(), size[idx].name(), rresp[beat].name()))
      end

      if (fd_read_beats[beat] != '0) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Backend exception read returned non-zero data at iteration %0d beat %0d: data=0x%0h",
                    idx, beat, fd_read_beats[beat]))
      end
    end

    if (ar_push_seen == 0 || r_push_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read did not use normal request/response FIFOs at iteration %0d: ar_push=%0d r_push=%0d",
                  idx, ar_push_seen, r_push_seen))
    end

    if (core_launch_seen == 0 || core_grant_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read did not reach backend execution at iteration %0d: launches=%0d grants=%0d",
                  idx, core_launch_seen, core_grant_seen))
    end

    if (r_fire_seen == 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read never completed on R channel at iteration %0d", idx))
    end

    if (illegal_seen != 0 || aw_push_seen != 0 || w_push_seen != 0 || b_fire_seen != 0) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Backend exception read showed unexpected write/frontend-illegal activity at iteration %0d: illegal=%0d aw_push=%0d w_push=%0d b_fire=%0d",
                  idx, illegal_seen, aw_push_seen, w_push_seen, b_fire_seen))
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

  virtual task build_frontdoor_beats(
    input int unsigned idx,
    output bit [`DATA_WIDTH-1:0] beats[]
  );
    bit [`ADDR_WIDTH-1:0] beat_addr;

    beats = new[len[idx]];
    for (int beat = 0; beat < len[idx]; beat++) begin
      beat_addr   = calc_beat_addr(addr[idx], beat, burst[idx], size[idx], len[idx]);
      beats[beat] = pack_frontdoor_payload(beat_addr, size[idx], data[idx][beat]);
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

endclass

`endif
