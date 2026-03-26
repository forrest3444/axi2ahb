`ifndef AXI2AHB_COV
`define AXI2AHB_COV

class axi2ahb_coverage extends axi2ahb_subscriber;

  `uvm_component_utils(axi2ahb_coverage)

  axi2ahb_config cfg;

  // --------------------------------------------------------------------------
  // AXI sample variables
  // --------------------------------------------------------------------------
  axi_pkg::xact_type_e axi_rw;
  axi_burst_type_e     axi_burst;
  axi_length_t         axi_len;
  axi_size_e           axi_size;
  axi_resp_e           axi_resp;
  bit                  axi_addr_valid;
  bit                  axi_has_error;
  bit                  axi_wrap_mid;

  // --------------------------------------------------------------------------
  // AHB sample variables
  // --------------------------------------------------------------------------
  ahb_pkg::xact_type_e ahb_rw;
  ahb_trans_e          ahb_trans;
  ahb_burst_e          ahb_burst;
  ahb_size_e           ahb_size;
  ahb_resp_e           ahb_resp;
  int unsigned         ahb_wait_delay;
  bit                  ahb_wait;
  bit                  ahb_error;
  bit                  ahb_addr_aligned;

  // --------------------------------------------------------------------------
  // AXI transaction coverage
  // --------------------------------------------------------------------------
  covergroup axi_cg with function sample();
    option.per_instance = 1;

    cp_axi_rw : coverpoint axi_rw {
      bins read  = {axi_pkg::READ};
      bins write = {axi_pkg::WRITE};
    }

    cp_axi_burst : coverpoint axi_burst {
      bins fixed = {axi_pkg::FIXED};
      bins incr  = {axi_pkg::INCR};
      bins wrap  = {axi_pkg::WRAP};
    }

    cp_axi_len : coverpoint axi_len {
      bins len1      = {1};
      bins len2_4    = {[2:4]};
      bins len5_8    = {[5:8]};
      bins len9_16   = {[9:16]};
    }

    cp_axi_size : coverpoint axi_size {
      bins size_1b = {SIZE_1B};
      bins size_2b = {SIZE_2B};
      bins size_4b = {SIZE_4B};
      bins size_8b = {SIZE_8B};
      //illegal_bins unsupported = {SIZE_16B, SIZE_32B, SIZE_64B, SIZE_128B};
    }

    cp_axi_resp : coverpoint axi_resp {
      bins okay   = {axi_pkg::OKAY};
      bins slverr = {axi_pkg::SLVERR};
    }

    cp_axi_addr_valid : coverpoint axi_addr_valid {
      bins legal   = {1'b1};
      bins illegal = {1'b0};
    }

    cp_axi_has_error : coverpoint axi_has_error {
      bins no_error = {1'b0};
      bins error    = {1'b1};
    }

    cp_axi_wrap_mid : coverpoint axi_wrap_mid iff (axi_burst == axi_pkg::WRAP) {
      bins boundary   = {1'b0};
      bins mid_window = {1'b1};
    }

    cr_axi_rw_burst   : cross cp_axi_rw, cp_axi_burst;
    cr_axi_burst_len  : cross cp_axi_burst, cp_axi_len;
    cr_axi_burst_size : cross cp_axi_burst, cp_axi_size;
    cr_axi_rw_size    : cross cp_axi_rw, cp_axi_size;
    cr_axi_rw_resp    : cross cp_axi_rw, cp_axi_resp;
    cr_axi_wrap_shape : cross cp_axi_len, cp_axi_wrap_mid iff (axi_burst == axi_pkg::WRAP);
  endgroup

  // --------------------------------------------------------------------------
  // AHB beat coverage
  // --------------------------------------------------------------------------
  covergroup ahb_cg with function sample();
    option.per_instance = 1;

    cp_ahb_rw : coverpoint ahb_rw {
      bins read  = {ahb_pkg::READ};
      bins write = {ahb_pkg::WRITE};
    }

    cp_ahb_trans : coverpoint ahb_trans {
      bins nonseq = {ahb_pkg::NONSEQ};
      bins seq    = {ahb_pkg::SEQ};
      bins idle   = {ahb_pkg::IDLE};
      illegal_bins idle_busy = {ahb_pkg::BUSY};
    }

    cp_ahb_burst : coverpoint ahb_burst {
      bins single = {ahb_pkg::SINGLE};
      bins incr   = {ahb_pkg::INCR};
      bins wrap4  = {ahb_pkg::WRAP4};
      bins incr4  = {ahb_pkg::INCR4};
      bins wrap8  = {ahb_pkg::WRAP8};
      bins incr8  = {ahb_pkg::INCR8};
      bins wrap16 = {ahb_pkg::WRAP16};
      bins incr16 = {ahb_pkg::INCR16};
    }

    cp_ahb_size : coverpoint ahb_size {
      bins size_1b = {ahb_pkg::BYTE1};
      bins size_2b = {ahb_pkg::BYTE2};
      bins size_4b = {ahb_pkg::BYTE4};
      bins size_8b = {ahb_pkg::BYTE8};
      illegal_bins unsupported = {ahb_pkg::BYTE16, ahb_pkg::BYTE32, ahb_pkg::BYTE64, ahb_pkg::BYTE128};
    }

    cp_ahb_resp : coverpoint ahb_resp {
      bins okay  = {ahb_pkg::OKAY};
      bins error = {ahb_pkg::ERROR};
			illegal_bins split_retry = {ahb_pkg::SPLIT, ahb_pkg::RETRY};
    }

    cp_ahb_wait : coverpoint ahb_wait {
      bins no_wait = {1'b0};
      bins waited  = {1'b1};
    }

    cp_ahb_wait_delay : coverpoint ahb_wait_delay {
      bins zero   = {0};
      bins wait_1_2 = {[1:2]};
      bins wait_3_5 = {[3:5]};
      bins wait_6_max = {[6:`MAX_DELAY]};
    }

    cp_ahb_error : coverpoint ahb_error {
      bins no_error = {1'b0};
      bins error    = {1'b1};
    }

    cp_ahb_addr_aligned : coverpoint ahb_addr_aligned {
      bins aligned   = {1'b1};
      illegal_bins misaligned = {1'b0};
    }

    cr_ahb_rw_burst : cross cp_ahb_rw, cp_ahb_burst;
    cr_ahb_rw_size  : cross cp_ahb_rw, cp_ahb_size;
    cr_ahb_resp_rw  : cross cp_ahb_rw, cp_ahb_resp;
    cr_ahb_wait_rw  : cross cp_ahb_rw, cp_ahb_wait;
    cr_ahb_trans_rw : cross cp_ahb_trans, cp_ahb_rw;
  endgroup

  function new(string name = "axi2ahb_coverage", uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
    ahb_cg = new();
  endfunction

  virtual function void write_mst(axi_transaction tr);
    if (tr == null) begin
      `uvm_warning(get_type_name(), "write_mst received null axi_transaction")
      return;
    end

    axi_rw         = tr.xact_type;
    axi_burst      = tr.burst;
    axi_len        = tr.len;
    axi_size       = tr.size;
    axi_resp       = get_axi_txn_resp(tr);
    axi_has_error  = (axi_resp != axi_pkg::OKAY);
    axi_addr_valid = get_axi_addr_valid(tr);
    axi_wrap_mid   = is_wrap_mid_window(tr);

    axi_cg.sample();

    `uvm_info(get_type_name(),
      $sformatf("AXI coverage sampled: type=%s addr=0x%0h len=%0d burst=%s size=%s resp=%s",
                axi_rw.name(),
                tr.addr,
                axi_len,
                axi_burst.name(),
                axi_size.name(),
                axi_resp.name()),
      UVM_MEDIUM)
  endfunction

  virtual function void write_slv(ahb_transaction tr);
    if (tr == null) begin
      `uvm_warning(get_type_name(), "write_slv received null ahb_transaction")
      return;
    end

    if (tr.addr.size() == 0 || tr.resp.size() == 0) begin
      `uvm_warning(get_type_name(), "write_slv received malformed ahb_transaction")
      return;
    end

    ahb_rw           = tr.write;
    ahb_trans        = (tr.trans.size() > 0) ? tr.trans[0] : ahb_pkg::IDLE;
    ahb_burst        = tr.burst;
    ahb_size         = tr.size;
    ahb_resp         = tr.resp[0];
    ahb_wait_delay   = tr.wait_delay;
    ahb_wait         = (tr.wait_delay != 0);
    ahb_error        = (tr.resp[0] != ahb_pkg::OKAY);
    ahb_addr_aligned = get_ahb_addr_aligned(tr.addr[0], tr.size);

    ahb_cg.sample();

    `uvm_info(get_type_name(),
      $sformatf("AHB coverage sampled: trans=%s type=%s addr=0x%0h burst=%s size=%s resp=%s wait=%0d",
                ahb_trans.name(),
                ahb_rw.name(),
                tr.addr[0],
                ahb_burst.name(),
                ahb_size.name(),
                ahb_resp.name(),
                ahb_wait_delay),
      UVM_MEDIUM)
  endfunction

  virtual function axi_resp_e get_axi_txn_resp(axi_transaction tr);
    axi_resp_e txn_resp;

    if (tr.xact_type == axi_pkg::WRITE) begin
      txn_resp = tr.bresp;
    end
    else begin
      txn_resp = axi_pkg::OKAY;
      if (tr.rresp.size() != tr.len) begin
        `uvm_warning(get_type_name(),
          $sformatf("Read response array size mismatch: len=%0d rresp.size=%0d",
                    tr.len, tr.rresp.size()))
      end

      foreach (tr.rresp[i]) begin
        if (tr.rresp[i] != axi_pkg::OKAY) begin
          txn_resp = axi_pkg::SLVERR;
          break;
        end
      end
    end

    return txn_resp;
  endfunction

  virtual function bit get_axi_addr_valid(axi_transaction tr);
    int unsigned beat_bytes;

    beat_bytes = get_axi_bytes_per_beat(tr.size);

    if (beat_bytes == 0)
      return 0;

    if ((tr.addr % beat_bytes) != 0)
      return 0;

    if (tr.burst == axi_pkg::WRAP) begin
      if (!(tr.len inside {2, 4, 8, 16}))
        return 0;
    end

    return 1;
  endfunction

  virtual function bit is_wrap_mid_window(axi_transaction tr);
    int unsigned beat_bytes;
    int unsigned total_bytes;

    if (tr.burst != axi_pkg::WRAP)
      return 0;

    beat_bytes = get_axi_bytes_per_beat(tr.size);
    total_bytes = tr.len * beat_bytes;

    if (beat_bytes == 0 || total_bytes == 0)
      return 0;

    return ((tr.addr % total_bytes) != 0);
  endfunction

  virtual function int unsigned get_axi_bytes_per_beat(axi_size_e size);
    case (size)
      SIZE_1B: return 1;
      SIZE_2B: return 2;
      SIZE_4B: return 4;
      SIZE_8B: return 8;
      default: return 0;
    endcase
  endfunction

  virtual function int unsigned get_ahb_bytes_per_beat(ahb_size_e size);
    case (size)
      BYTE1: return 1;
      BYTE2: return 2;
      BYTE4: return 4;
      BYTE8: return 8;
      default: return 0;
    endcase
  endfunction

  virtual function bit get_ahb_addr_aligned(
    input ahb_addr_t addr,
    input ahb_size_e size
  );
    int unsigned beat_bytes;

    beat_bytes = get_ahb_bytes_per_beat(size);
    if (beat_bytes == 0)
      return 0;

    return ((addr % beat_bytes) == 0);
  endfunction

endclass

`endif
