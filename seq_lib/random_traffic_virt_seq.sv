`ifndef AXI2AHB_RANDOM_TRAFFIC_VIRT_SEQ_SV
`define AXI2AHB_RANDOM_TRAFFIC_VIRT_SEQ_SV

class random_traffic_virt_seq extends base_virtual_sequence;

  `uvm_object_utils(random_traffic_virt_seq)

  rand int unsigned    sequence_length;
  rand axi_burst_type_e burst[];
  rand axi_size_e      size[];
  rand int unsigned    len[];
  rand int unsigned    beat_bytes[];
  rand int unsigned    burst_bytes[];
  rand bit [31:0]      addr[];
  rand bit [31:0]      wrap_base_addr[];
  rand int unsigned    wrap_offset[];
  rand bit             do_write[];
  rand bit [63:0]      data[][];

  bit [`DATA_WIDTH-1:0] fd_beats[];
  bit [`DATA_WIDTH-1:0] fd_read_beats[];
  axi_resp_e            bresp;
  axi_resp_e            rresp[];

  constraint legal_random_traffic {
    sequence_length inside {[100:200]};

    solve burst before len;
    solve size before beat_bytes;
    solve len before burst_bytes;
    solve beat_bytes before burst_bytes;
    solve beat_bytes before addr;
    solve burst_bytes before wrap_base_addr;
    solve burst_bytes before wrap_offset;

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

    foreach (wrap_base_addr[i]) {
      if (burst[i] == axi_pkg::WRAP) {
        wrap_base_addr[i][31:16] == 16'h0000;
        (wrap_base_addr[i] % burst_bytes[i]) == 0;
        wrap_base_addr[i] + burst_bytes[i] - 1 <= 32'h0000_ffff;
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
        addr[i][31:16] == 16'h0000;
        (addr[i] % beat_bytes[i]) == 0;
        addr[i] + burst_bytes[i] - 1 <= 32'h0000_ffff;
      }
      else {
        addr[i][31:16] == 16'h0000;
        (addr[i] % beat_bytes[i]) == 0;
        addr[i] + beat_bytes[i] - 1 <= 32'h0000_ffff;
      }
    }
  }

  function new(string name = "random_traffic_virt_seq");
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
    add_check_tag("random_traffic",
                  "Legal mixed random traffic with randomized direction, burst, size, and length");
  endfunction

  virtual task run_write(int unsigned idx);
    build_frontdoor_beats(idx, fd_beats);
    bresp = axi_pkg::OKAY;

    fd_write_burst(addr[idx], len[idx], fd_beats, burst[idx], size[idx], bresp);

    if (bresp != axi_pkg::OKAY) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Random traffic write failed at iteration %0d: addr=0x%0h len=%0d burst=%s size=%s bresp=%s",
                  idx, addr[idx], len[idx], burst[idx].name(), size[idx].name(), bresp.name()))
    end
  endtask

  virtual task run_read(int unsigned idx);
    fd_read_burst(addr[idx], len[idx], burst[idx], size[idx], fd_read_beats, rresp);

    if (fd_read_beats.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Random traffic read data size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], fd_read_beats.size()))
      return;
    end

    if (rresp.size() != len[idx]) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Random traffic read resp size mismatch at iteration %0d: expected=%0d actual=%0d",
                  idx, len[idx], rresp.size()))
      return;
    end

    foreach (rresp[beat]) begin
      if (rresp[beat] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Random traffic read response error at iteration %0d beat %0d: burst=%s size=%s resp=%s",
                    idx, beat, burst[idx].name(), size[idx].name(), rresp[beat].name()))
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
      beat_addr   = calc_beat_addr(addr[idx], beat, burst[idx], size[idx], len[idx]);
      beats[beat] = pack_frontdoor_payload(beat_addr, size[idx], data[idx][beat]);
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

endclass

`endif
