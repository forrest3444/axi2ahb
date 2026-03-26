`ifndef SINGLE_WRITE_READ_VIRT_SEQ_SV
`define SINGLE_WRITE_READ_VIRT_SEQ_SV

class single_write_read_virt_seq extends base_virtual_sequence;

  typedef struct {
    string           name;
    bit              do_write;
    axi_burst_type_e burst;
    axi_size_e       size;
    int unsigned     len;
    bit [31:0]       addr;
  } boundary_case_t;

  `uvm_object_utils(single_write_read_virt_seq)

  boundary_case_t         cases[$];
  bit [`DATA_WIDTH-1:0]   exp_beats[];
  bit [`DATA_WIDTH-1:0]   act_beats[];
  bit [63:0]              payloads[];
  bit [63:0]              act_payload;
  axi_resp_e              bresp;
  axi_resp_e              rresp[];

  function new(string name = "single_write_read_virt_seq");
    super.new(name);
  endfunction

  virtual task body();
    super.body();
    `uvm_info(get_type_name(), "Entered...", UVM_LOW)

    add_tag();
    build_boundary_cases();

    foreach (cases[i]) begin
      run_case(i, cases[i]);
    end

    set_check_state_by_check_error_num();

    `uvm_info(get_type_name(), "Exiting...", UVM_LOW)
  endtask

  virtual function void add_tag();
    add_check_tag("single_write_read",
                  "Directed legal boundary read/write coverage for FIXED, INCR, and WRAP bursts");
  endfunction

  virtual function void build_boundary_cases();
    cases.delete();

    add_case_pair("fixed_len1_size1_low",      axi_pkg::FIXED, axi_pkg::SIZE_1B, 1,  32'h0000_0000);
    add_case_pair("fixed_len1_size1_top",      axi_pkg::FIXED, axi_pkg::SIZE_1B, 1,  32'h0000_ffff);
    add_case_pair("fixed_len1_size8_top",      axi_pkg::FIXED, axi_pkg::SIZE_8B, 1,  32'h0000_fff8);
    add_case_pair("fixed_len16_size1_top",     axi_pkg::FIXED, axi_pkg::SIZE_1B, 16, 32'h0000_fff0);
    add_case_pair("fixed_len16_size8_low",     axi_pkg::FIXED, axi_pkg::SIZE_8B, 16, 32'h0000_0000);
    add_case_pair("fixed_len16_size8_top",     axi_pkg::FIXED, axi_pkg::SIZE_8B, 16, 32'h0000_fff8);

    add_case_pair("incr_len1_size1_low",       axi_pkg::INCR,  axi_pkg::SIZE_1B, 1,  32'h0000_0000);
    add_case_pair("incr_len1_size1_top",       axi_pkg::INCR,  axi_pkg::SIZE_1B, 1,  32'h0000_ffff);
    add_case_pair("incr_len1_size8_top",       axi_pkg::INCR,  axi_pkg::SIZE_8B, 1,  32'h0000_fff8);
    add_case_pair("incr_len16_size1_top",      axi_pkg::INCR,  axi_pkg::SIZE_1B, 16, 32'h0000_fff0);
    add_case_pair("incr_len16_size8_low",      axi_pkg::INCR,  axi_pkg::SIZE_8B, 16, 32'h0000_0000);
    add_case_pair("incr_len16_size8_top",      axi_pkg::INCR,  axi_pkg::SIZE_8B, 16, 32'h0000_ff80);

    add_case_pair("wrap_len2_size1_boundary_low",  axi_pkg::WRAP, axi_pkg::SIZE_1B, 2,  32'h0000_0000);
    add_case_pair("wrap_len2_size1_middle_low",    axi_pkg::WRAP, axi_pkg::SIZE_1B, 2,  32'h0000_0001);
    add_case_pair("wrap_len2_size1_boundary_top",  axi_pkg::WRAP, axi_pkg::SIZE_1B, 2,  32'h0000_fffe);
    add_case_pair("wrap_len2_size1_middle_top",    axi_pkg::WRAP, axi_pkg::SIZE_1B, 2,  32'h0000_ffff);
    add_case_pair("wrap_len2_size8_boundary_top",  axi_pkg::WRAP, axi_pkg::SIZE_8B, 2,  32'h0000_fff0);
    add_case_pair("wrap_len2_size8_middle_top",    axi_pkg::WRAP, axi_pkg::SIZE_8B, 2,  32'h0000_fff8);
    add_case_pair("wrap_len16_size1_boundary_top", axi_pkg::WRAP, axi_pkg::SIZE_1B, 16, 32'h0000_fff0);
    add_case_pair("wrap_len16_size1_middle_top",   axi_pkg::WRAP, axi_pkg::SIZE_1B, 16, 32'h0000_fff8);
    add_case_pair("wrap_len16_size8_boundary_low", axi_pkg::WRAP, axi_pkg::SIZE_8B, 16, 32'h0000_0000);
    add_case_pair("wrap_len16_size8_middle_low",   axi_pkg::WRAP, axi_pkg::SIZE_8B, 16, 32'h0000_0040);
    add_case_pair("wrap_len16_size8_boundary_top", axi_pkg::WRAP, axi_pkg::SIZE_8B, 16, 32'h0000_ff80);
    add_case_pair("wrap_len16_size8_middle_top",   axi_pkg::WRAP, axi_pkg::SIZE_8B, 16, 32'h0000_ffc0);
  endfunction

  virtual function void add_case_pair(
    input string           base_name,
    input axi_burst_type_e burst,
    input axi_size_e       size,
    input int unsigned     len,
    input bit [31:0]       addr
  );
    boundary_case_t tc;

    tc.name     = {base_name, "_write"};
    tc.do_write = 1'b1;
    tc.burst    = burst;
    tc.size     = size;
    tc.len      = len;
    tc.addr     = addr;
    cases.push_back(tc);

    tc.name     = {base_name, "_read"};
    tc.do_write = 1'b0;
    cases.push_back(tc);
  endfunction

  virtual task run_case(
    input int unsigned idx,
    input boundary_case_t tc
  );
    if (!case_is_legal(tc)) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Boundary case %0d (%s) is not legal: burst=%s size=%s len=%0d addr=0x%0h",
                  idx, tc.name, tc.burst.name(), tc.size.name(), tc.len, tc.addr))
      return;
    end

    build_payloads(idx, tc, payloads);

    if (tc.do_write)
      run_fd_write_bd_check(idx, tc, payloads);
    else
      run_bd_write_fd_check(idx, tc, payloads);
  endtask

  virtual task run_fd_write_bd_check(
    input int unsigned     idx,
    input boundary_case_t  tc,
    input bit [63:0]       exp_payloads[]
  );
    build_frontdoor_beats(tc, exp_payloads, exp_beats);
    bresp = axi_pkg::OKAY;
    fd_write_burst(tc.addr, tc.len, exp_beats, tc.burst, tc.size, bresp);

    if (bresp != axi_pkg::OKAY) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Boundary write failed at case %0d (%s): burst=%s size=%s len=%0d addr=0x%0h bresp=%s",
                  idx, tc.name, tc.burst.name(), tc.size.name(), tc.len, tc.addr, bresp.name()))
      return;
    end

    for (int beat = 0; beat < tc.len; beat++) begin
      bd_read_payload(calc_beat_addr(tc.addr, beat, tc.burst, tc.size, tc.len), tc.size, act_payload);
      compare_payload(mask_payload(exp_payloads[beat], tc.size),
                      act_payload,
                      tc.size,
                      $sformatf("%s_exp_write_payload[%0d]", tc.name, beat),
                      $sformatf("%s_act_write_payload[%0d]", tc.name, beat));
    end
  endtask

  virtual task run_bd_write_fd_check(
    input int unsigned     idx,
    input boundary_case_t  tc,
    input bit [63:0]       exp_payloads[]
  );
    for (int beat = 0; beat < tc.len; beat++) begin
      bd_write_payload(calc_beat_addr(tc.addr, beat, tc.burst, tc.size, tc.len),
                       tc.size,
                       mask_payload(exp_payloads[beat], tc.size));
    end

    fd_read_burst(tc.addr, tc.len, tc.burst, tc.size, act_beats, rresp);

    if (act_beats.size() != tc.len) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Boundary read data size mismatch at case %0d (%s): expected=%0d actual=%0d",
                  idx, tc.name, tc.len, act_beats.size()))
      return;
    end

    if (rresp.size() != tc.len) begin
      cfg.seq_check_error++;
      `uvm_error(get_type_name(),
        $sformatf("Boundary read resp size mismatch at case %0d (%s): expected=%0d actual=%0d",
                  idx, tc.name, tc.len, rresp.size()))
      return;
    end

    for (int beat = 0; beat < tc.len; beat++) begin
      act_payload = unpack_frontdoor_payload(
        calc_beat_addr(tc.addr, beat, tc.burst, tc.size, tc.len),
        tc.size,
        act_beats[beat]
      );

      compare_payload(mask_payload(exp_payloads[beat], tc.size),
                      act_payload,
                      tc.size,
                      $sformatf("%s_exp_read_payload[%0d]", tc.name, beat),
                      $sformatf("%s_act_read_payload[%0d]", tc.name, beat));

      if (rresp[beat] != axi_pkg::OKAY) begin
        cfg.seq_check_error++;
        `uvm_error(get_type_name(),
          $sformatf("Boundary read response error at case %0d (%s) beat %0d: resp=%s",
                    idx, tc.name, beat, rresp[beat].name()))
      end
    end
  endtask

  virtual function bit case_is_legal(input boundary_case_t tc);
    bit [31:0] page_base;
    bit [31:0] beat_addr;
    bit [31:0] last_addr;
    int unsigned beat_bytes;

    beat_bytes = get_bytes_per_beat(tc.size);

    if (!(tc.burst inside {axi_pkg::FIXED, axi_pkg::INCR, axi_pkg::WRAP}))
      return 1'b0;

    if (tc.len == 0)
      return 1'b0;

    if ((tc.burst == axi_pkg::WRAP) && !(tc.len inside {2, 4, 8, 16}))
      return 1'b0;

    if ((tc.addr % beat_bytes) != 0)
      return 1'b0;

    page_base = {tc.addr[31:10], 10'b0};

    for (int beat = 0; beat < tc.len; beat++) begin
      beat_addr = calc_beat_addr(tc.addr, beat, tc.burst, tc.size, tc.len);
      last_addr = beat_addr + beat_bytes - 1;

      if (last_addr > 32'h0000_ffff)
        return 1'b0;

      if ((beat_addr[31:10] != page_base[31:10]) || (last_addr[31:10] != page_base[31:10]))
        return 1'b0;
    end

    return 1'b1;
  endfunction

  virtual function void build_payloads(
    input  int unsigned    idx,
    input  boundary_case_t tc,
    output bit [63:0]      beats[]
  );
    bit [63:0] base_payload;

    beats = new[tc.len];
    base_payload = 64'hA5C3_0000_0000_0000
                 ^ (64'(idx) << 16)
                 ^ (64'(get_bytes_per_beat(tc.size)) << 8)
                 ^ 64'(tc.len);

    for (int beat = 0; beat < tc.len; beat++) begin
      if (tc.burst == axi_pkg::FIXED)
        beats[beat] = mask_payload(base_payload, tc.size);
      else
        beats[beat] = mask_payload(base_payload ^ (64'(beat) * 64'h0001_0101_0101_0101), tc.size);
    end
  endfunction

  virtual task build_frontdoor_beats(
    input  boundary_case_t      tc,
    input  bit [63:0]           payload_words[],
    output bit [`DATA_WIDTH-1:0] beats[]
  );
    bit [`ADDR_WIDTH-1:0] beat_addr;

    beats = new[tc.len];
    for (int beat = 0; beat < tc.len; beat++) begin
      beat_addr  = calc_beat_addr(tc.addr, beat, tc.burst, tc.size, tc.len);
      beats[beat] = pack_frontdoor_payload(beat_addr, tc.size, payload_words[beat]);
    end
  endtask

  virtual task bd_write_payload(
    input bit [`ADDR_WIDTH-1:0] beat_addr,
    input axi_size_e            size,
    input bit [63:0]            payload
  );
    int unsigned beat_bytes;

    beat_bytes = get_bytes_per_beat(size);
    for (int byte_idx = 0; byte_idx < beat_bytes; byte_idx++) begin
      bd_write_byte(beat_addr + byte_idx, payload[byte_idx*8 +: 8]);
    end
  endtask

  virtual task bd_read_payload(
    input  bit [`ADDR_WIDTH-1:0] beat_addr,
    input  axi_size_e            size,
    output bit [63:0]            payload
  );
    int unsigned beat_bytes;
    bit [7:0]    rd_byte;

    payload    = '0;
    beat_bytes = get_bytes_per_beat(size);

    for (int byte_idx = 0; byte_idx < beat_bytes; byte_idx++) begin
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
        return payload;
      end
    endcase
  endfunction

  virtual function void compare_payload(
    input bit [63:0] exp_payload,
    input bit [63:0] act_payload,
    input axi_size_e size,
    input string     exp_id,
    input string     act_id
  );
    compare_data(mask_payload(exp_payload, size),
                 mask_payload(act_payload, size),
                 exp_id,
                 act_id);
  endfunction

endclass

`endif
