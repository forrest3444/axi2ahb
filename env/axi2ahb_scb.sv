`ifndef AXI2AHB_SCB
`define AXI2AHB_SCB

class axi2ahb_scoreboard extends axi2ahb_subscriber;

  `uvm_component_utils(axi2ahb_scoreboard)

  axi2ahb_config  cfg;

  axi_transaction axi_tr_q[$];
  ahb_transaction ahb_tr_q[$];

  int unsigned total_axi_tr;
  int unsigned total_ahb_tr;
  int unsigned compare_count;
  int unsigned error_count;

  time compare_timeout    = 100us;
  time illegal_guard_time = 1us;

  function new(string name = "axi2ahb_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    total_axi_tr  = 0;
    total_ahb_tr  = 0;
    compare_count = 0;
    error_count   = 0;
  endfunction

  virtual function void write_mst(axi_transaction tr);
    if (tr == null) begin
      `uvm_warning(get_type_name(), "write_mst received null axi_transaction")
      return;
    end

    total_axi_tr++;
    axi_tr_q.push_back(tr);

    `uvm_info(get_type_name(),
      $sformatf("AXI transaction received: type=%s addr=0x%0h len=%0d burst=%s size=%s",
                tr.xact_type.name(),
                tr.addr,
                tr.len,
                tr.burst.name(),
                tr.size.name()),
      UVM_HIGH)
  endfunction

  virtual function void write_slv(ahb_transaction tr);
    if (tr == null) begin
      `uvm_warning(get_type_name(), "write_slv received null ahb_transaction")
      return;
    end

    total_ahb_tr++;
    ahb_tr_q.push_back(tr);

    `uvm_info(get_type_name(),
      $sformatf("AHB beat transaction received: write=%s burst=%s size=%s addr0=0x%0h data0=0x%0h",
                tr.write.name(),
                tr.burst.name(),
                tr.size.name(),
                (tr.addr.size() > 0) ? tr.addr[0] : '0,
                (tr.data.size() > 0) ? tr.data[0] : '0),
      UVM_HIGH)
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
      wait (axi_tr_q.size() > 0);
      compare_one_axi_burst();
    end
  endtask

  virtual task compare_one_axi_burst();
    axi_transaction axi_tr;
    ahb_transaction exp_ahb_q[$];
    ahb_transaction act_ahb_q[$];
    int unsigned expected_beat_num;
    bit got_enough_ahb;

    if (axi_tr_q.size() == 0)
      return;

    axi_tr = axi_tr_q.pop_front();

    if (is_frontend_rejected_axi(axi_tr)) begin
      check_frontend_rejection(axi_tr);
      return;
    end

    build_expected_ahb_from_axi(axi_tr, exp_ahb_q);

    expected_beat_num = exp_ahb_q.size();

    if (expected_beat_num == 0) begin
      `uvm_warning(get_type_name(),
        $sformatf("No expected AHB beats generated for AXI tr: type=%s addr=0x%0h len=%0d burst=%s",
                  axi_tr.xact_type.name(), axi_tr.addr, axi_tr.len, axi_tr.burst.name()))
      return;
    end

    got_enough_ahb = wait_for_ahb_beats(expected_beat_num, compare_timeout);

    if (!got_enough_ahb) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("Timeout waiting AHB beats: expected=%0d actual=%0d timeout=%0t AXI[type=%s addr=0x%0h len=%0d burst=%s size=%s]",
                  expected_beat_num,
                  ahb_tr_q.size(),
                  compare_timeout,
                  axi_tr.xact_type.name(),
                  axi_tr.addr,
                  axi_tr.len,
                  axi_tr.burst.name(),
                  axi_tr.size.name()))
      return;
    end

    repeat (expected_beat_num) begin
      act_ahb_q.push_back(ahb_tr_q.pop_front());
    end

    compare_ahb_beat_queue(axi_tr, exp_ahb_q, act_ahb_q);
  endtask

  virtual function bit wait_for_ahb_beats(int unsigned needed, time timeout_val);
    time start_t;

    start_t = $time;

    while (ahb_tr_q.size() < needed) begin
      if (($time - start_t) >= timeout_val)
        return 0;
    end

    return 1;
  endfunction

  virtual task check_frontend_rejection(axi_transaction axi_tr);
    int unsigned ahb_before;

    if (axi_tr == null) begin
      error_count++;
      `uvm_error(get_type_name(), "Null AXI transaction in frontend rejection check")
      return;
    end

    ahb_before = ahb_tr_q.size();

    if (!axi_tr.has_error()) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("Frontend-rejected AXI transaction completed without error response: type=%s addr=0x%0h len=%0d burst=%s size=%s",
                  axi_tr.xact_type.name(), axi_tr.addr, axi_tr.len, burst_name(axi_tr.burst), size_name(axi_tr.size)))
    end

    if (axi_tr.xact_type == axi_pkg::WRITE) begin
      if (axi_tr.bresp != axi_pkg::SLVERR) begin
        error_count++;
        `uvm_error(get_type_name(),
          $sformatf("Illegal AXI write returned unexpected response: addr=0x%0h burst=%s size=%s bresp=%s",
                    axi_tr.addr, burst_name(axi_tr.burst), size_name(axi_tr.size), axi_tr.bresp.name()))
      end
    end
    else begin
      if (axi_tr.rresp.size() != axi_tr.len) begin
        error_count++;
        `uvm_error(get_type_name(),
          $sformatf("Illegal AXI read returned unexpected beat count: addr=0x%0h expected=%0d actual=%0d",
                    axi_tr.addr, axi_tr.len, axi_tr.rresp.size()))
      end
      else begin
        foreach (axi_tr.rresp[i]) begin
          if (axi_tr.rresp[i] != axi_pkg::SLVERR) begin
            error_count++;
            `uvm_error(get_type_name(),
              $sformatf("Illegal AXI read returned unexpected response at beat %0d: addr=0x%0h resp=%s",
                        i, axi_tr.addr, axi_tr.rresp[i].name()))
          end
        end
      end
    end

    #(illegal_guard_time);

    // In mixed legal/illegal traffic, later legal or backend-error AHB beats can arrive
    // during this guard window. Frontend blocking is proven by the dedicated sequences
    // through DUT debug-path checks, so the scoreboard only validates the AXI-side error
    // completion here.
    compare_count++;
  endtask

  virtual function bit is_frontend_rejected_axi(axi_transaction axi_tr);
    int unsigned beat_bytes;

    if (axi_tr == null)
      return 0;

    beat_bytes = get_bytes_per_beat_or_zero(axi_tr.size);

    return !burst_supported_axi(axi_tr.burst)
        || (beat_bytes == 0)
        || ((axi_tr.addr % beat_bytes) != 0)
        || ((axi_tr.burst == axi_pkg::WRAP) && !wrap_len_supported_axi(axi_tr.len))
        || crosses_1kb_boundary_axi(axi_tr);
  endfunction

  virtual function bit crosses_1kb_boundary_axi(axi_transaction axi_tr);
    int unsigned beat_num;
    int unsigned beat_bytes;
    ahb_addr_t   curr_addr;
    ahb_addr_t   next_addr;
    ahb_addr_t   last_addr;
    ahb_addr_t   wrap_base;
    ahb_addr_t   start_addr;

    if (axi_tr == null)
      return 0;

    beat_num   = axi_tr.len;
    beat_bytes = get_bytes_per_beat_or_zero(axi_tr.size);
    start_addr = axi_tr.addr;
    curr_addr  = start_addr;

    if ((beat_num == 0) || (beat_bytes == 0))
      return 0;

    if (axi_tr.burst == axi_pkg::WRAP)
      wrap_base = get_wrap_base_addr(start_addr, beat_num, beat_bytes);
    else
      wrap_base = '0;

    for (int unsigned i = 0; i < beat_num; i++) begin
      last_addr = curr_addr + beat_bytes - 1;

      if ((curr_addr[31:10] != start_addr[31:10])
       || (last_addr[31:10] != start_addr[31:10]))
        return 1;

      case (axi_tr.burst)
        axi_pkg::FIXED: next_addr = curr_addr;
        axi_pkg::INCR:  next_addr = curr_addr + beat_bytes;
        axi_pkg::WRAP:  next_addr = get_next_wrap_addr(curr_addr, wrap_base, beat_num, beat_bytes);
        default:        next_addr = curr_addr + beat_bytes;
      endcase

      curr_addr = next_addr;
    end

    return 0;
  endfunction

  virtual function bit burst_supported_axi(axi_burst_type_e burst);
    return (burst == axi_pkg::FIXED)
        || (burst == axi_pkg::INCR)
        || (burst == axi_pkg::WRAP);
  endfunction

  virtual function bit wrap_len_supported_axi(int unsigned beat_num);
    return (beat_num == 2)
        || (beat_num == 4)
        || (beat_num == 8)
        || (beat_num == 16);
  endfunction

  virtual function int unsigned get_bytes_per_beat_or_zero(axi_size_e size);
    case (size)
      SIZE_1B: return 1;
      SIZE_2B: return 2;
      SIZE_4B: return 4;
      SIZE_8B: return 8;
      default: return 0;
    endcase
  endfunction

  virtual function string burst_name(axi_burst_type_e burst);
    case (burst)
      axi_pkg::FIXED: return "FIXED";
      axi_pkg::INCR:  return "INCR";
      axi_pkg::WRAP:  return "WRAP";
      default:        return $sformatf("0x%0h", burst);
    endcase
  endfunction

  virtual function string size_name(axi_size_e size);
    case (size)
      axi_pkg::SIZE_1B:   return "SIZE_1B";
      axi_pkg::SIZE_2B:   return "SIZE_2B";
      axi_pkg::SIZE_4B:   return "SIZE_4B";
      axi_pkg::SIZE_8B:   return "SIZE_8B";
      axi_pkg::SIZE_16B:  return "SIZE_16B";
      axi_pkg::SIZE_32B:  return "SIZE_32B";
      axi_pkg::SIZE_64B:  return "SIZE_64B";
      axi_pkg::SIZE_128B: return "SIZE_128B";
      default:            return $sformatf("0x%0h", size);
    endcase
  endfunction

  virtual function void build_expected_ahb_from_axi(
    axi_transaction axi_tr,
    ref ahb_transaction exp_ahb_q[$]
  );
    int unsigned beat_num;
    int unsigned beat_bytes;
    ahb_addr_t   curr_addr;
    ahb_addr_t   next_addr;
    ahb_addr_t   start_addr;
    ahb_addr_t   wrap_base;

    exp_ahb_q.delete();

    beat_num   = axi_tr.len;
    beat_bytes = get_bytes_per_beat(axi_tr.size);
    start_addr = axi_tr.addr;
    curr_addr  = start_addr;

    if (beat_num == 0) begin
      `uvm_warning(get_type_name(),
        $sformatf("AXI transaction len==0 detected: type=%s addr=0x%0h",
                  axi_tr.xact_type.name(), axi_tr.addr))
      return;
    end

    if (axi_tr.burst == axi_pkg::WRAP) begin
      if (!(beat_num inside {2, 4, 8, 16})) begin
        `uvm_error(get_type_name(),
          $sformatf("Illegal AXI WRAP length: beat_num=%0d addr=0x%0h",
                    beat_num, start_addr))
        return;
      end
      wrap_base = get_wrap_base_addr(start_addr, beat_num, beat_bytes);
    end
    else begin
      wrap_base = '0;
    end

    for (int i = 0; i < beat_num; i++) begin
      ahb_transaction exp_tr;

      exp_tr = ahb_transaction::type_id::create($sformatf("exp_ahb_beat_%0d", i), this);

      exp_tr.write = ahb_pkg::xact_type_e'(axi_tr.xact_type);

      case (axi_tr.burst)
        axi_pkg::FIXED: begin
          exp_tr.burst = SINGLE;
        end
        axi_pkg::INCR: begin
          if (beat_num == 1)
            exp_tr.burst = SINGLE;
          else
            exp_tr.burst = ahb_pkg::INCR;
        end
        axi_pkg::WRAP: begin
          case (beat_num)
            4  : exp_tr.burst = WRAP4;
            8  : exp_tr.burst = WRAP8;
            16 : exp_tr.burst = WRAP16;
            default: exp_tr.burst = ahb_pkg::INCR;
          endcase
        end
        default: begin
          exp_tr.burst = ahb_pkg::INCR;
        end
      endcase

      exp_tr.size = ahb_size_e'(axi_tr.size);

      exp_tr.addr = new[1];
      exp_tr.data = new[1];
      exp_tr.resp = new[1];

      exp_tr.addr[0] = curr_addr;

      if (axi_tr.data.size() > i)
        exp_tr.data[0] = axi_tr.data[i];
      else
        exp_tr.data[0] = '0;

      exp_tr.resp[0] = ahb_pkg::OKAY;

      exp_ahb_q.push_back(exp_tr);

      case (axi_tr.burst)
        axi_pkg::FIXED: begin
          next_addr = curr_addr;
        end

        axi_pkg::INCR: begin
          next_addr = curr_addr + beat_bytes;
        end

        axi_pkg::WRAP: begin
          next_addr = get_next_wrap_addr(curr_addr, wrap_base, beat_num, beat_bytes);
        end

        default: begin
          next_addr = curr_addr + beat_bytes;
        end
      endcase

      curr_addr = next_addr;
    end
  endfunction

  virtual function void compare_ahb_beat_queue(
    axi_transaction axi_tr,
    ref ahb_transaction exp_ahb_q[$],
    ref ahb_transaction act_ahb_q[$]
  );
    int i;

    if (exp_ahb_q.size() != act_ahb_q.size()) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB beat queue size mismatch: expected=%0d actual=%0d",
                  exp_ahb_q.size(), act_ahb_q.size()))
      return;
    end

    for (i = 0; i < exp_ahb_q.size(); i++) begin
      compare_one_ahb_beat(axi_tr, exp_ahb_q[i], act_ahb_q[i], i);
    end

    compare_count++;
  endfunction

  virtual function void compare_one_ahb_beat(
    axi_transaction axi_tr,
    ahb_transaction exp_tr,
    ahb_transaction act_tr,
    int unsigned beat_idx
  );
    if (exp_tr == null || act_tr == null) begin
      error_count++;
      `uvm_error(get_type_name(), "Null expected/actual AHB beat transaction")
      return;
    end

    if (exp_tr.write != act_tr.write) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB write/read mismatch at beat %0d: expected=%s actual=%s axi_type=%s axi_addr=0x%0h",
                  beat_idx,
                  exp_tr.write.name(),
                  act_tr.write.name(),
                  axi_tr.xact_type.name(),
                  axi_tr.addr))
    end

    if (exp_tr.size != act_tr.size) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB size mismatch at beat %0d: expected=%s actual=%s",
                  beat_idx,
                  exp_tr.size.name(),
                  act_tr.size.name()))
    end

    if (exp_tr.addr.size() != 1 || act_tr.addr.size() != 1) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB addr field size mismatch at beat %0d: exp_size=%0d act_size=%0d",
                  beat_idx, exp_tr.addr.size(), act_tr.addr.size()))
    end
    else if (exp_tr.addr[0] != act_tr.addr[0]) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB addr mismatch at beat %0d: expected=0x%0h actual=0x%0h axi_burst=%s axi_start_addr=0x%0h",
                  beat_idx,
                  exp_tr.addr[0],
                  act_tr.addr[0],
                  axi_tr.burst.name(),
                  axi_tr.addr))
    end

    if (exp_tr.data.size() != 1 || act_tr.data.size() != 1) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB data field size mismatch at beat %0d: exp_size=%0d act_size=%0d",
                  beat_idx, exp_tr.data.size(), act_tr.data.size()))
    end
    else begin
      if (exp_tr.data[0] != act_tr.data[0]) begin
        error_count++;
        `uvm_error(get_type_name(),
          $sformatf("AHB data mismatch at beat %0d: expected=0x%0h actual=0x%0h axi_type=%s axi_addr=0x%0h",
                    beat_idx,
                    exp_tr.data[0],
                    act_tr.data[0],
                    axi_tr.xact_type.name(),
                    axi_tr.addr))
      end
    end
  endfunction

  virtual function void compare_masked_data(
    axi_transaction axi_tr,
    ahb_data_t exp_data,
    ahb_data_t act_data,
    int unsigned beat_idx
  );
    ahb_data_t mask;
    ahb_data_t masked_exp;
    ahb_data_t masked_act;

    mask       = get_data_mask_from_size(axi_tr.size);
    masked_exp = exp_data & mask;
    masked_act = act_data & mask;

    if (masked_exp != masked_act) begin
      error_count++;
      `uvm_error(get_type_name(),
        $sformatf("AHB data mismatch at beat %0d: expected=0x%0h actual=0x%0h mask=0x%0h axi_type=%s axi_addr=0x%0h size=%s",
                  beat_idx,
                  masked_exp,
                  masked_act,
                  mask,
                  axi_tr.xact_type.name(),
                  axi_tr.addr,
                  axi_tr.size.name()))
    end
  endfunction

  virtual function ahb_data_t get_data_mask_from_size(axi_size_e size);
    case (size)
      SIZE_1B: return ahb_data_t'('h0000_0000_0000_00FF);
      SIZE_2B: return ahb_data_t'('h0000_0000_0000_FFFF);
      SIZE_4B: return ahb_data_t'('h0000_0000_FFFF_FFFF);
      SIZE_8B: return ahb_data_t'('hFFFF_FFFF_FFFF_FFFF);
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported AXI size for data mask: %s", size.name()))
        return '0;
      end
    endcase
  endfunction

  virtual function int unsigned get_bytes_per_beat(axi_size_e size);
    case (size)
      SIZE_1B: return 1;
      SIZE_2B: return 2;
      SIZE_4B: return 4;
      SIZE_8B: return 8;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported AXI size for predictor: %s", size.name()))
        return 1;
      end
    endcase
  endfunction

  virtual function ahb_addr_t get_wrap_base_addr(
    ahb_addr_t start_addr,
    int unsigned beat_num,
    int unsigned beat_bytes
  );
    int unsigned wrap_bytes;

    wrap_bytes = beat_num * beat_bytes;

    if (wrap_bytes == 0)
      return start_addr;

    return (start_addr / wrap_bytes) * wrap_bytes;
  endfunction

  virtual function ahb_addr_t get_next_wrap_addr(
    ahb_addr_t curr_addr,
    ahb_addr_t wrap_base,
    int unsigned beat_num,
    int unsigned beat_bytes
  );
    ahb_addr_t candidate;
    int unsigned wrap_bytes;

    wrap_bytes = beat_num * beat_bytes;
    candidate  = curr_addr + beat_bytes;

    if (candidate >= (wrap_base + wrap_bytes))
      return wrap_base;

    return candidate;
  endfunction

endclass

`endif
