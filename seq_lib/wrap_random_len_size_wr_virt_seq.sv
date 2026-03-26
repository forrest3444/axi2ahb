`ifndef AXI2AHB_WRAP_RANDOM_LEN_SIZE_WR_VIRT_SEQ_SV
`define AXI2AHB_WRAP_RANDOM_LEN_SIZE_WR_VIRT_SEQ_SV

class wrap_random_len_size_wr_virt_seq extends base_virtual_sequence;

  `uvm_object_utils(wrap_random_len_size_wr_virt_seq)

  rand int unsigned sequence_length;
  rand axi_size_e   size[];
  rand int unsigned len[];
  rand int unsigned beat_bytes[];
  rand int unsigned wrap_bytes[];
  rand bit [31:0]   wrap_base_addr[];
  rand int unsigned wrap_offset[];
  rand bit [31:0]   addr[];
  rand bit          do_write[];
  rand bit          first_is_write;
  rand bit [63:0]   data[][];

  bit [`DATA_WIDTH-1:0] fd_beats[];
  bit [`DATA_WIDTH-1:0] fd_read_beats[];
  axi_resp_e            bresp;
  axi_resp_e            rresp[];

  constraint reasonable_sequence_length {
    sequence_length inside {[50:100]};

    solve size before beat_bytes;
    solve len before wrap_bytes;
    solve beat_bytes before wrap_bytes;
    solve wrap_bytes before wrap_base_addr;
    solve len before wrap_offset;
    solve wrap_base_addr before addr;
    solve wrap_offset before addr;

    size.size()       == sequence_length;
    len.size()        == sequence_length;
    beat_bytes.size() == sequence_length;
    wrap_bytes.size()     == sequence_length;
    wrap_base_addr.size() == sequence_length;
    wrap_offset.size()    == sequence_length;
    addr.size()           == sequence_length;
    do_write.size()   == sequence_length;
    data.size()       == sequence_length;

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

    foreach (len[i]) len[i] inside {2, 4, 8, 16};
    foreach (wrap_bytes[i]) wrap_bytes[i] == len[i] * beat_bytes[i];
    foreach (wrap_offset[i]) wrap_offset[i] inside {[1:len[i]-1]};
    foreach (data[i]) data[i].size() == len[i];

    foreach (wrap_base_addr[i]) {
      wrap_base_addr[i][31:16] == 16'h0000;
      (wrap_base_addr[i] % wrap_bytes[i]) == 0;
      wrap_base_addr[i] + wrap_bytes[i] - 1 <= 32'h0000_ffff;
    }

    foreach (addr[i]) {
      addr[i] == wrap_base_addr[i] + (wrap_offset[i] * beat_bytes[i]);
    }

    foreach (do_write[i]) {
      if (i == 0) do_write[i] == first_is_write;
      else do_write[i] == ~do_write[i-1];
    }
  }

  function new(string name = "wrap_random_len_size_wr_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();

    foreach (addr[i]) begin
      if (do_write[i])
        run_fd_write_bd_read(i);
      else
        run_bd_write_fd_read(i);
    end

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag("wrap_random_len_size_wr",
                  "Random WRAP len/size traffic with force-aligned addresses and alternating direction");
  endfunction

  virtual task run_fd_write_bd_read(int unsigned idx);
    bit [63:0] exp_payload;
    bit [63:0] act_payload;

    build_frontdoor_beats(idx, fd_beats);
    bresp = axi_pkg::OKAY;
    fd_write_burst(addr[idx], len[idx], fd_beats, axi_pkg::WRAP, size[idx], bresp);

    if (bresp != axi_pkg::OKAY) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("FD WRAP write failed at iteration %0d: addr=0x%0h len=%0d size=%s bresp=%s",
                  idx, addr[idx], len[idx], size[idx].name(), bresp.name()))
      return;
    end

    for (int beat = 0; beat < len[idx]; beat++) begin
      exp_payload = mask_payload(data[idx][beat], size[idx]);
      bd_read_payload(calc_beat_addr(addr[idx], beat, axi_pkg::WRAP, size[idx], len[idx]),
                      size[idx], act_payload);
      compare_payload(exp_payload, act_payload, size[idx],
                      $sformatf("fd_wrap_write_payload[%0d][%0d]", idx, beat),
                      $sformatf("bd_wrap_read_payload[%0d][%0d]", idx, beat));
    end
  endtask

  virtual task run_bd_write_fd_read(int unsigned idx);
    bit [63:0] exp_payload;
    bit [63:0] act_payload;

    for (int beat = 0; beat < len[idx]; beat++) begin
      exp_payload = mask_payload(data[idx][beat], size[idx]);
      bd_write_payload(calc_beat_addr(addr[idx], beat, axi_pkg::WRAP, size[idx], len[idx]),
                       size[idx], exp_payload);
    end

    fd_read_burst(addr[idx], len[idx], axi_pkg::WRAP, size[idx], fd_read_beats, rresp);

    if (fd_read_beats.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("FD WRAP read data size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], fd_read_beats.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("FD WRAP read resp size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rresp.size()))
      return;
    end

    for (int beat = 0; beat < len[idx]; beat++) begin
      exp_payload = mask_payload(data[idx][beat], size[idx]);
      act_payload = unpack_frontdoor_payload(
        calc_beat_addr(addr[idx], beat, axi_pkg::WRAP, size[idx], len[idx]),
        size[idx],
        fd_read_beats[beat]
      );

      compare_payload(exp_payload, act_payload, size[idx],
                      $sformatf("bd_wrap_write_payload[%0d][%0d]", idx, beat),
                      $sformatf("fd_wrap_read_payload[%0d][%0d]", idx, beat));

      if (rresp[beat] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("FD WRAP read response error at iteration %0d beat %0d: size=%s resp=%s",
                    idx, beat, size[idx].name(), rresp[beat].name()))
      end
    end
  endtask

  virtual task build_frontdoor_beats(
    input int unsigned idx,
    output bit [`DATA_WIDTH-1:0] beats[]
  );
    bit [`ADDR_WIDTH-1:0] beat_addr;

    beats = new[len[idx]];
    for (int beat = 0; beat < len[idx]; beat++) begin
      beat_addr   = calc_beat_addr(addr[idx], beat, axi_pkg::WRAP, size[idx], len[idx]);
      beats[beat] = pack_frontdoor_payload(beat_addr, size[idx], data[idx][beat]);
    end
  endtask

  virtual task bd_write_payload(
    input bit [`ADDR_WIDTH-1:0] beat_addr,
    input axi_size_e            size,
    input bit [63:0]            payload
  );
    int unsigned beat_bytes_local;

    beat_bytes_local = get_bytes_per_beat(size);
    for (int byte_idx = 0; byte_idx < beat_bytes_local; byte_idx++) begin
      bd_write_byte(beat_addr + byte_idx, payload[byte_idx*8 +: 8]);
    end
  endtask

  virtual task bd_read_payload(
    input  bit [`ADDR_WIDTH-1:0] beat_addr,
    input  axi_size_e            size,
    output bit [63:0]            payload
  );
    int unsigned beat_bytes_local;
    bit [7:0]    rd_byte;

    payload          = '0;
    beat_bytes_local = get_bytes_per_beat(size);

    for (int byte_idx = 0; byte_idx < beat_bytes_local; byte_idx++) begin
      bd_read_byte(beat_addr + byte_idx, rd_byte);
      payload[byte_idx*8 +: 8] = rd_byte;
    end
  endtask

  virtual function bit [63:0] pack_frontdoor_payload(
    input bit [`ADDR_WIDTH-1:0] beat_addr,
    input axi_size_e            size,
    input bit [63:0]            payload
  );
    bit [63:0] beat_word;
    int unsigned byte_off;

    beat_word = '0;
    byte_off  = beat_addr[$clog2(`STRB_WIDTH)-1:0];

    case (size)
      axi_pkg::SIZE_1B: beat_word[byte_off*8 +: 8]  = payload[7:0];
      axi_pkg::SIZE_2B: beat_word[byte_off*8 +: 16] = payload[15:0];
      axi_pkg::SIZE_4B: beat_word[byte_off*8 +: 32] = payload[31:0];
      axi_pkg::SIZE_8B: beat_word                    = payload;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported size for payload packing: %s", size.name()))
      end
    endcase

    return beat_word;
  endfunction

  virtual function bit [63:0] unpack_frontdoor_payload(
    input bit [`ADDR_WIDTH-1:0] beat_addr,
    input axi_size_e            size,
    input bit [`DATA_WIDTH-1:0] beat_word
  );
    bit [63:0] payload;
    int unsigned byte_off;

    payload  = '0;
    byte_off = beat_addr[$clog2(`STRB_WIDTH)-1:0];

    case (size)
      axi_pkg::SIZE_1B: payload[7:0]   = beat_word[byte_off*8 +: 8];
      axi_pkg::SIZE_2B: payload[15:0]  = beat_word[byte_off*8 +: 16];
      axi_pkg::SIZE_4B: payload[31:0]  = beat_word[byte_off*8 +: 32];
      axi_pkg::SIZE_8B: payload        = beat_word;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported size for payload unpacking: %s", size.name()))
      end
    endcase

    return payload;
  endfunction

  virtual function bit [63:0] mask_payload(
    input bit [63:0] payload,
    input axi_size_e size
  );
    case (size)
      axi_pkg::SIZE_1B: return {56'h0, payload[7:0]};
      axi_pkg::SIZE_2B: return {48'h0, payload[15:0]};
      axi_pkg::SIZE_4B: return {32'h0, payload[31:0]};
      axi_pkg::SIZE_8B: return payload;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported size for payload masking: %s", size.name()))
        return '0;
      end
    endcase
  endfunction

  virtual function void compare_payload(
    input bit [63:0] expected,
    input bit [63:0] actual,
    input axi_size_e size,
    input string     exp_id,
    input string     act_id
  );
    case (size)
      axi_pkg::SIZE_1B: compare_data({56'h0, expected[7:0]}, {56'h0, actual[7:0]}, exp_id, act_id);
      axi_pkg::SIZE_2B: compare_data({48'h0, expected[15:0]}, {48'h0, actual[15:0]}, exp_id, act_id);
      axi_pkg::SIZE_4B: compare_data({32'h0, expected[31:0]}, {32'h0, actual[31:0]}, exp_id, act_id);
      axi_pkg::SIZE_8B: compare_data(expected, actual, exp_id, act_id);
      default: begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Unsupported size for payload comparison: %s", size.name()))
      end
    endcase
  endfunction

endclass

`endif
