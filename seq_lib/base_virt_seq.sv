`ifndef AXI2AHB_BASE_VIRTUAL_SEQUENCE_SV
`define AXI2AHB_BASE_VIRTUAL_SEQUENCE_SV

typedef enum bit [1:0] {
 UNKNOWN = 0,
 PASS    = 1,
 FALL    = 2
} check_state_enum;

typedef struct {
	string tag;
  string description;
	check_state_enum state;
} check_tag_struct;

class base_virtual_sequence extends uvm_sequence #(axi_transaction, axi_transaction);

	axi2ahb_config     cfg;
	virtual axi_intf   avif;
	virtual ahb_intf   hvif;
	virtual dut_dbg_if dvif;

	ahb_slave_agent    ahb_slv;
	memory             mem;

	string            cur_check_tag;
	check_tag_struct  check_tags[string];

	`uvm_object_utils(base_virtual_sequence)
	`uvm_declare_p_sequencer(axi2ahb_virtual_sequencer)

	function new(string name = "base_virtual_sequence");
		super.new(name);
	endfunction

	virtual task body();
		`uvm_info("body", "ENTERED...", UVM_LOW)
		get_config();
		wait_ready_for_stim();
		`uvm_info("body", "EXITING...", UVM_LOW)
	endtask

	virtual task post_body();
		review_check_tags();
	endtask

	virtual function void get_config();
		cfg  = p_sequencer.cfg;
		if(cfg == null)
			`uvm_fatal("BODY", "Get a null cfg")
		avif = cfg.avif;
		hvif = cfg.hvif;
		dvif = cfg.dvif;
		mem  = cfg.slv_cfg.mem;
		if(avif == null || hvif == null || dvif == null)
			`uvm_fatal("BODY", "Get a null vif")
		if(mem == null)
			`uvm_fatal("BODY", "Get a null mem")
	endfunction

	task wait_reset_signal_asserted();
		if(avif.rstn === 1'b1)
			@(negedge avif.rstn);
		else 
			return;
	endtask

	task wait_reset_signal_released();
		if(avif.rstn === 1'b0)
			@(posedge avif.rstn);
		else
			return;
	endtask

	task wait_cycles(int n = 1);
		repeat(n) @(posedge avif.clk);
	endtask

	virtual task wait_ready_for_stim();
		if(avif.rstn !== 1'b1)
			wait_reset_signal_released();
		wait_cycles(10);
	endtask

	virtual function void add_check_tag(string tag, string description = "");
		check_tag_struct chktag;
		if(check_tags.exists(tag))
			`uvm_error("CHKSTAT", $sformatf("Tag:%s already added to check tags array", tag))
		else begin
			chktag.tag = tag;
			chktag.description = description;
			check_tags[tag] = chktag;
			cur_check_tag = tag;
		end
	endfunction

	virtual function void set_check_state(check_state_enum state, string tag = "");
		bit state_recorded;

		state_recorded = 0;

		if(check_tags.size() == 0) begin
			`uvm_error("CHKSTAT", "check tags size is 0, please add valid check tag first.")
			return;
		end

		if(tag == "") begin
			if(cur_check_tag == "") begin
				`uvm_error("CHKSTAT", "Current check tag is empty, please add a valid check tag first.")
				return;
			end
			check_tags[cur_check_tag].state = state;
			state_recorded = 1;
		end
		else if(!check_tags.exists(tag)) begin
			`uvm_error("CHKSTAT", $sformatf("Tag:%s is not in check tags array", tag))
			return;
		end
		else begin
			check_tags[tag].state = state;
			state_recorded = 1;
		end

		if(!state_recorded)
			return;

		if(state == FALL)
			cfg.add_seq_check_error();
		else if(state == PASS)
			cfg.add_seq_check_count();
	endfunction

	virtual function void set_check_state_by_check_error_num(string tag = "");
		if(cfg.seq_check_error == 0)
			set_check_state(PASS, tag);
		else
			set_check_state(FALL, tag);
	endfunction

	virtual function void review_check_tags();
		check_state_enum state = PASS;
		check_tag_struct chktag;
		string rpt = "\n";
		rpt = {rpt, "-----------------------------------------------\n"};
		rpt = {rpt, ">>>>>>  Sequence Dedicated Checks Report:      \n"};
		rpt = {rpt, "-----------------------------------------------\n"};
		foreach(check_tags[tag]) begin
			chktag = check_tags[tag];
			rpt = {rpt, $sformatf("Check          : %s\n", chktag.tag)};
			rpt = {rpt, $sformatf("Description    : %s\n", chktag.description)};
			rpt = {rpt, $sformatf("Check          : %s\n", chktag.state)};
			if(chktag.state == FALL)
				state = FALL;
		end
		if(check_tags.size() > 0) begin
			if(state == PASS)
				`uvm_info("CHECK_REPORT", rpt, UVM_LOW)
			else
				`uvm_error("CHECK_REPORT", rpt)
		end
	endfunction

	virtual function void compare_data(
		logic [`DATA_WIDTH-1:0] val1,
	 	logic [`DATA_WIDTH-1:0] val2,
	 	string id1 = "val1",
	 	string id2 = "val2"
	);
		cfg.seq_check_count++;
		if(val1 == val2) begin
			`uvm_info("CMPSUC", $sformatf("%s 'h%0x == %s 'h%0x", id1, val1, id2, val2), UVM_LOW)
		end
		else begin
			cfg.seq_check_error++;
			`uvm_error("CMPERR", $sformatf("%s 'h%0x != %s 'h%0x", id1, val1, id2, val2))
		end
	endfunction

	virtual task sink_response();
		fork
			forever begin
				get_response(rsp);
			end
		join_none
	endtask

  // --------------------------------------------------------------------------
  // Utility helpers
  // --------------------------------------------------------------------------	
  virtual function int unsigned get_bytes_per_beat(axi_size_e size);
    case (size)
      axi_pkg::SIZE_1B: return 1;
      axi_pkg::SIZE_2B: return 2;
      axi_pkg::SIZE_4B: return 4;
      axi_pkg::SIZE_8B: return 8;
      default: begin
        `uvm_fatal(get_type_name(),
          $sformatf("Unsupported AXI size: %s", size.name()))
        return 1;
      end
    endcase
  endfunction	


  virtual function void check_burst_len_legal(
    int              beat_num,
    axi_burst_type_e burst,
    output bit       legal
  );
    legal = 1'b1;

    if (beat_num <= 0) begin
      `uvm_error(get_type_name(),
        $sformatf("Illegal burst beat count: %0d", beat_num))
      legal = 1'b0;
      return;
    end

    case (burst)
      axi_pkg::WRAP: begin
        if (!(beat_num inside {2,4,8,16})) begin
          `uvm_error(get_type_name(),
            $sformatf("Illegal WRAP beat count: %0d, only 2/4/8/16 are allowed", beat_num))
          legal = 1'b0;
        end
      end

      axi_pkg::INCR,
      axi_pkg::FIXED: begin
        if (beat_num > 256) begin
          `uvm_error(get_type_name(),
            $sformatf("Illegal burst beat count: %0d, current supported max is 256", beat_num))
          legal = 1'b0;
        end
      end

      default: begin
        `uvm_error(get_type_name(),
          $sformatf("Unsupported burst type: %s", burst.name()))
        legal = 1'b0;
      end
    endcase
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] get_wrap_base_addr(
    bit [`ADDR_WIDTH-1:0] start_addr,
    int unsigned          beat_num,
    int unsigned          beat_bytes
  );
    int unsigned wrap_bytes;

    wrap_bytes = beat_num * beat_bytes;

    if (wrap_bytes == 0)
      return start_addr;

    return (start_addr / wrap_bytes) * wrap_bytes;
  endfunction

  virtual function bit [`ADDR_WIDTH-1:0] calc_beat_addr(
    bit [`ADDR_WIDTH-1:0] start_addr,
    int unsigned          beat_idx,
    axi_burst_type_e      burst,
    axi_size_e            size,
    int unsigned          beat_num
  );
    int unsigned          beat_bytes;
    int unsigned          wrap_bytes;
    bit [`ADDR_WIDTH-1:0] wrap_base;
    bit [`ADDR_WIDTH-1:0] addr_tmp;

    beat_bytes = get_bytes_per_beat(size);

    case (burst)
      axi_pkg::FIXED: begin
        return start_addr;
      end

      axi_pkg::INCR: begin
        return start_addr + beat_idx * beat_bytes;
      end

      axi_pkg::WRAP: begin
        wrap_bytes = beat_num * beat_bytes;
        wrap_base  = get_wrap_base_addr(start_addr, beat_num, beat_bytes);
        addr_tmp   = start_addr + beat_idx * beat_bytes;

        if (addr_tmp >= wrap_base + wrap_bytes)
          addr_tmp = wrap_base + (addr_tmp - (wrap_base + wrap_bytes));

        return addr_tmp;
      end

      default: begin
        `uvm_error(get_type_name(),
          $sformatf("Unsupported burst type for address calculation: %s", burst.name()))
        return start_addr;
      end
    endcase
  endfunction

  virtual function bit [`STRB_WIDTH-1:0] calc_wstrb(
    bit [`ADDR_WIDTH-1:0] addr,
    axi_size_e            size
  );
    int unsigned          byte_off;
    int unsigned          nbytes;
    bit [`STRB_WIDTH-1:0] mask;

    nbytes   = get_bytes_per_beat(size);
    byte_off = addr[$clog2(`STRB_WIDTH)-1:0];
    mask     = '0;

    if (nbytes > `STRB_WIDTH) begin
      `uvm_error(get_type_name(),
        $sformatf("WSTRB generation failed: nbytes=%0d > STRB_WIDTH=%0d",
                  nbytes, `STRB_WIDTH))
      return '0;
    end

    if ((byte_off + nbytes) > `STRB_WIDTH) begin
      `uvm_error(get_type_name(),
        $sformatf("WSTRB generation crosses beat boundary: addr=0x%0h size=%s byte_off=%0d nbytes=%0d STRB_WIDTH=%0d",
                  addr, size.name(), byte_off, nbytes, `STRB_WIDTH))
      return '0;
    end

    for (int i = 0; i < nbytes; i++) begin
      mask[byte_off + i] = 1'b1;
    end

    return mask;
  endfunction

  // --------------------------------------------------------------------------
  // Backdoor beat-level access
  // --------------------------------------------------------------------------
  virtual task bd_write(
	bit [`ADDR_WIDTH-1:0] addr,
 	bit [`DATA_WIDTH-1:0] data,
 	bit [`STRB_WIDTH-1:0] byteen = {`STRB_WIDTH{1'b1}}
);
		mem.write(addr, data, byteen);
	endtask

	virtual task bd_write_num_beats(
		bit [`ADDR_WIDTH-1:0] addr,
	 	int no_of_beats,
	 	bit [`DATA_WIDTH-1:0] data[]
	);
		bit [`ADDR_WIDTH-1:0] wrad;
	  bit [`DATA_WIDTH-1:0] wrdt;
		bit [`STRB_WIDTH-1:0] byteen;

    if (no_of_beats <= 0) begin
      `uvm_error(get_type_name(),
        $sformatf("BD WRITE: no_of_beats must be > 0, got %0d", no_of_beats))
      return;
    end

    if (data.size() != no_of_beats) begin
      `uvm_error(get_type_name(),
        $sformatf("BD WRITE: data size mismatch, expect %0d, got %0d",
                  no_of_beats, data.size()))
      return;
    end
		
		for(int i = 0; i < no_of_beats; i++) begin
			wrad   = addr + (i << $clog2(`STRB_WIDTH));
			wrdt   = data[i];
			byteen = {`STRB_WIDTH{1'b1}};
			bd_write(wrad, wrdt, byteen);
		end
	endtask

	virtual task bd_read(
		input  bit [`ADDR_WIDTH-1:0] addr,
	 	output bit [`DATA_WIDTH-1:0] data
	);
		data = mem.read(addr);
	endtask

	virtual task bd_read_num_beats(
		input  bit [`ADDR_WIDTH-1:0] addr,
	 	input  int no_of_words,
	 	output bit [`DATA_WIDTH-1:0] data[]
	);
		bit [`DATA_WIDTH-1:0] rddt;
		bit [`ADDR_WIDTH-1:0] rdad;

		data = new[no_of_words];

		for(int i = 0; i < no_of_words; i++) begin
			rdad = addr + (i << $clog2(`STRB_WIDTH));
			bd_read(rdad, rddt);
			data[i] = rddt;
		end
	endtask

  // --------------------------------------------------------------------------
  // Backdoor byte-level access
  // --------------------------------------------------------------------------
	virtual task bd_write_byte(bit [`ADDR_WIDTH-1:0] addr, bit [7:0] data);
		mem.write_byte(addr, data);
	endtask

	virtual task bd_write_num_byte(bit [`ADDR_WIDTH-1:0] addr, int no_of_bytes, bit [7:0] data[]);
		mem.write_num_bytes(addr, no_of_bytes, data);
	endtask

	virtual task bd_read_byte(input bit [`ADDR_WIDTH-1:0] addr, output bit [7:0] data);
		mem.read_byte(addr, data);
	endtask

	virtual task bd_read_num_byte(input bit [`ADDR_WIDTH-1:0] addr, input int no_of_bytes, output bit [7:0] data[]);
		mem.read_num_bytes(addr, no_of_bytes, data);
	endtask

  // --------------------------------------------------------------------------
  // Backdoor 32-bit word-level compatibility APIs
  // --------------------------------------------------------------------------
	virtual task bd_write_word(bit [`ADDR_WIDTH-1:0] addr, bit [31:0] data);
		bit [`ADDR_WIDTH-1:0] aligned_addr;
		bit [`DATA_WIDTH-1:0] beat_data;
		bit [`STRB_WIDTH-1:0] byteen;
		int unsigned          byte_off;

		if((addr % 4) != 0)
			`uvm_warning(get_type_name(), $sformatf("BD WORD WRITE: addr=0x%0h is not 4-byte aligned", addr))

		byte_off    = addr[$clog2(`STRB_WIDTH)-1:0];
		aligned_addr = addr & ~(`STRB_WIDTH - 1);

		if((byte_off + 4) > `STRB_WIDTH) begin
			`uvm_error(get_type_name(),
				$sformatf("BD WORD WRITE crosses beat boundary: addr=0x%0h byte_off=%0d STRB_WIDTH=%0d",
						  addr, byte_off, `STRB_WIDTH))
			return;
		end

		beat_data = '0;
		beat_data[byte_off*8 +: 32] = data;
		byteen = '0;
		for(int i = 0; i < 4; i++)
			byteen[byte_off + i] = 1'b1;

		bd_write(aligned_addr, beat_data, byteen);
	endtask

	virtual task bd_write_num_word(bit [`ADDR_WIDTH-1:0] addr, int no_of_words, bit [31:0] data[]);
		bit [`ADDR_WIDTH-1:0] wrad;

		if(no_of_words <= 0) begin
			`uvm_error(get_type_name(),
				$sformatf("BD WORD WRITE: no_of_words must be > 0, got %0d", no_of_words))
			return;
		end

		if(data.size() != no_of_words) begin
			`uvm_error(get_type_name(),
				$sformatf("BD WORD WRITE: data size mismatch, expect %0d, got %0d",
						  no_of_words, data.size()))
			return;
		end

		for(int i = 0; i < no_of_words; i++) begin
			wrad = addr + (i * 4);
			bd_write_word(wrad, data[i]);
		end
	endtask

	virtual task bd_read_word(input bit [`ADDR_WIDTH-1:0] addr, output bit [31:0] data);
		bit [`ADDR_WIDTH-1:0] aligned_addr;
		bit [`DATA_WIDTH-1:0] beat_data;
		int unsigned          byte_off;

		if((addr % 4) != 0)
			`uvm_warning(get_type_name(), $sformatf("BD WORD READ: addr=0x%0h is not 4-byte aligned", addr))

		byte_off    = addr[$clog2(`STRB_WIDTH)-1:0];
		aligned_addr = addr & ~(`STRB_WIDTH - 1);

		if((byte_off + 4) > `STRB_WIDTH) begin
			`uvm_error(get_type_name(),
				$sformatf("BD WORD READ crosses beat boundary: addr=0x%0h byte_off=%0d STRB_WIDTH=%0d",
						  addr, byte_off, `STRB_WIDTH))
			data = '0;
			return;
		end

		bd_read(aligned_addr, beat_data);
		data = beat_data[byte_off*8 +: 32];
	endtask

	virtual task bd_read_num_word(input bit [`ADDR_WIDTH-1:0] addr, input int no_of_words, output bit [31:0] data[]);
		bit [`ADDR_WIDTH-1:0] rdad;

		if(no_of_words < 0) begin
			`uvm_error(get_type_name(),
				$sformatf("BD WORD READ: no_of_words must be >= 0, got %0d", no_of_words))
			data = new[0];
			return;
		end

		data = new[no_of_words];

		for(int i = 0; i < no_of_words; i++) begin
			rdad = addr + (i * 4);
			bd_read_word(rdad, data[i]);
		end
	endtask

  // --------------------------------------------------------------------------
  // Frontdoor generic burst access
  // --------------------------------------------------------------------------
  virtual task fd_read_burst(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    axi_burst_type_e      burst,
    axi_size_e            size,
    output bit [`DATA_WIDTH-1:0] data[],
    output axi_resp_e     resp[]
  );
    axi_transaction       tr, rsp;
    int unsigned          beat_bytes;
    bit                   legal;

    data = new[0];
    resp = new[0];

    check_burst_len_legal(no_of_beats, burst, legal);
    if (!legal)
      return;

    beat_bytes = get_bytes_per_beat(size);

    if ((addr % beat_bytes) != 0) begin
      `uvm_warning(get_type_name(),
        $sformatf("READ: addr=0x%0h is not aligned to size=%s", addr, size.name()))
    end

    `uvm_create_on(tr, p_sequencer.axi_seqr)

    tr.xact_type = axi_pkg::READ;
    tr.addr      = addr;
    tr.burst     = burst;
    tr.size      = size;
    tr.len       = no_of_beats;

    tr.data  = new[tr.len];
    tr.rresp = new[tr.len];

    `uvm_send(tr)

    get_response(rsp);

    if (rsp == null) begin
      `uvm_error(get_type_name(), "READ: response is null")
      return;
    end

    if (rsp.data.size() != no_of_beats) begin
      `uvm_error(get_type_name(),
        $sformatf("READ: rsp.data size mismatch, expect %0d, got %0d",
                  no_of_beats, rsp.data.size()))
      return;
    end

    if (rsp.rresp.size() != no_of_beats) begin
      `uvm_error(get_type_name(),
        $sformatf("READ: rsp.rresp size mismatch, expect %0d, got %0d",
                  no_of_beats, rsp.rresp.size()))
      return;
    end

    data = new[no_of_beats];
    resp = new[no_of_beats];

    foreach (rsp.data[i]) begin
      data[i] = rsp.data[i];
    end

    foreach (rsp.rresp[i]) begin
      resp[i] = rsp.rresp[i];
    end

    `uvm_info(get_type_name(),
      $sformatf("READ: burst=%s addr=0x%0h len=%0d size=%s",
                burst.name(), addr, no_of_beats, size.name()),
      UVM_MEDIUM)
  endtask

	virtual task fd_write_burst(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_beats,
		bit [`DATA_WIDTH-1:0] data[],
		axi_burst_type_e      burst,
		axi_size_e            size,
		output axi_resp_e     resp
	);
		axi_transaction tr, rsp;
		int unsigned    beat_bytes;
		bit             legal;
		bit [`ADDR_WIDTH-1:0] beat_addr;

		resp = axi_pkg::OKAY;

		if (data.size() != no_of_beats) begin
			`uvm_error(get_type_name(),
				$sformatf("WRITE: data size mismatch, expect %0d, got %0d",
									no_of_beats, data.size()))
			resp = axi_pkg::SLVERR;
			return;
		end

		check_burst_len_legal(no_of_beats, burst, legal);
		if(!legal) begin
			resp = axi_pkg::SLVERR;
			return;
		end

		beat_bytes = get_bytes_per_beat(size);
    if ((addr % beat_bytes) != 0) begin
      `uvm_warning(get_type_name(),
        $sformatf("WRITE: addr=0x%0h is not aligned to size=%s", addr, size.name()))
    end

		`uvm_create_on(tr, p_sequencer.axi_seqr)

		tr.xact_type = axi_pkg::WRITE;
		tr.addr      = addr;
		tr.burst     = burst;
		tr.size      = size;
		tr.len       = no_of_beats;
		tr.data      = new[tr.len];
		tr.wstrb     = new[tr.len];

		foreach (tr.data[i]) begin
			tr.data[i]  = data[i];
			beat_addr   = calc_beat_addr(addr, i, burst, size, no_of_beats);
			tr.wstrb[i] = calc_wstrb(beat_addr, size);
		end

		`uvm_send(tr)

		get_response(rsp);

		if (rsp == null) begin
			`uvm_error(get_type_name(), "WRITE: response is null")
			resp = axi_pkg::SLVERR;
			return;
		end

		resp = rsp.bresp;

		`uvm_info(get_type_name(),
			$sformatf("WRITE: burst=%s addr=0x%0h len=%0d size=%s resp=%s",
								burst.name(), addr, no_of_beats, size.name(), resp.name()),
			UVM_MEDIUM)
	endtask

  // --------------------------------------------------------------------------
  // Frontdoor convenience APIs
  // --------------------------------------------------------------------------
  virtual task fd_write_num_beats(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    bit [`DATA_WIDTH-1:0] data[],
    output axi_resp_e     resp
  );
    fd_write_burst(addr, no_of_beats, data, axi_pkg::INCR, axi_pkg::SIZE_8B, resp);
  endtask

  virtual task fd_read_num_beats(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    output bit [`DATA_WIDTH-1:0] data[],
    output axi_resp_e     resp[]
  );
    fd_read_burst(addr, no_of_beats, axi_pkg::INCR, axi_pkg::SIZE_8B, data, resp);
  endtask

  virtual task fd_write_wrap(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    bit [`DATA_WIDTH-1:0] data[],
    axi_size_e            size,
    output axi_resp_e     resp
  );
    fd_write_burst(addr, no_of_beats, data, axi_pkg::WRAP, size, resp);
  endtask

  virtual task fd_write_fixed(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    bit [`DATA_WIDTH-1:0] data[],
    axi_size_e            size,
    output axi_resp_e     resp
  );
    fd_write_burst(addr, no_of_beats, data, axi_pkg::FIXED, size, resp);
  endtask

  virtual task fd_read_wrap(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    axi_size_e            size,
    output bit [`DATA_WIDTH-1:0] data[],
    output axi_resp_e     resp[]
  );
    fd_read_burst(addr, no_of_beats, axi_pkg::WRAP, size, data, resp);
  endtask

  virtual task fd_read_fixed(
    bit [`ADDR_WIDTH-1:0] addr,
    int                   no_of_beats,
    axi_size_e            size,
    output bit [`DATA_WIDTH-1:0] data[],
    output axi_resp_e     resp[]
  );
    fd_read_burst(addr, no_of_beats, axi_pkg::FIXED, size, data, resp);
  endtask	

	virtual task fd_write_num_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		bit [31:0]            data[],
		output axi_resp_e     resp
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		if(data.size() != no_of_words) begin
			`uvm_error(get_type_name(),
				$sformatf("WRITE WORD: data size mismatch, expect %0d, got %0d",
						  no_of_words, data.size()))
			resp = axi_pkg::SLVERR;
			return;
		end

		beat_data = new[no_of_words];
		foreach(beat_data[i]) begin
			beat_data[i] = '0;
			word_addr = calc_beat_addr(addr, i, axi_pkg::INCR, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			beat_data[i][byte_off*8 +: 32] = data[i];
		end

		fd_write_burst(addr, no_of_words, beat_data, axi_pkg::INCR, axi_pkg::SIZE_4B, resp);
	endtask

	virtual task fd_read_num_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		output bit [31:0]     data[],
		output axi_resp_e     resp[]
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		fd_read_burst(addr, no_of_words, axi_pkg::INCR, axi_pkg::SIZE_4B, beat_data, resp);

		data = new[beat_data.size()];
		foreach(beat_data[i]) begin
			word_addr = calc_beat_addr(addr, i, axi_pkg::INCR, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			data[i] = beat_data[i][byte_off*8 +: 32];
		end
	endtask

	virtual task fd_write_wrap_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		bit [31:0]            data[],
		output axi_resp_e     resp
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		if(data.size() != no_of_words) begin
			`uvm_error(get_type_name(),
				$sformatf("WRITE WRAP WORD: data size mismatch, expect %0d, got %0d",
						  no_of_words, data.size()))
			resp = axi_pkg::SLVERR;
			return;
		end

		beat_data = new[no_of_words];
		foreach(beat_data[i]) begin
			beat_data[i] = '0;
			word_addr = calc_beat_addr(addr, i, axi_pkg::WRAP, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			beat_data[i][byte_off*8 +: 32] = data[i];
		end

		fd_write_burst(addr, no_of_words, beat_data, axi_pkg::WRAP, axi_pkg::SIZE_4B, resp);
	endtask

	virtual task fd_write_fixed_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		bit [31:0]            data[],
		output axi_resp_e     resp
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		if(data.size() != no_of_words) begin
			`uvm_error(get_type_name(),
				$sformatf("WRITE FIXED WORD: data size mismatch, expect %0d, got %0d",
						  no_of_words, data.size()))
			resp = axi_pkg::SLVERR;
			return;
		end

		beat_data = new[no_of_words];
		foreach(beat_data[i]) begin
			beat_data[i] = '0;
			word_addr = calc_beat_addr(addr, i, axi_pkg::FIXED, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			beat_data[i][byte_off*8 +: 32] = data[i];
		end

		fd_write_burst(addr, no_of_words, beat_data, axi_pkg::FIXED, axi_pkg::SIZE_4B, resp);
	endtask

	virtual task fd_read_wrap_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		output bit [31:0]     data[],
		output axi_resp_e     resp[]
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		fd_read_burst(addr, no_of_words, axi_pkg::WRAP, axi_pkg::SIZE_4B, beat_data, resp);

		data = new[beat_data.size()];
		foreach(beat_data[i]) begin
			word_addr = calc_beat_addr(addr, i, axi_pkg::WRAP, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			data[i] = beat_data[i][byte_off*8 +: 32];
		end
	endtask

	virtual task fd_read_fixed_word(
		bit [`ADDR_WIDTH-1:0] addr,
		int                   no_of_words,
		output bit [31:0]     data[],
		output axi_resp_e     resp[]
	);
		bit [`DATA_WIDTH-1:0] beat_data[];
		bit [`ADDR_WIDTH-1:0] word_addr;
		int unsigned          byte_off;

		fd_read_burst(addr, no_of_words, axi_pkg::FIXED, axi_pkg::SIZE_4B, beat_data, resp);

		data = new[beat_data.size()];
		foreach(beat_data[i]) begin
			word_addr = calc_beat_addr(addr, i, axi_pkg::FIXED, axi_pkg::SIZE_4B, no_of_words);
			byte_off  = word_addr[$clog2(`STRB_WIDTH)-1:0];
			data[i] = beat_data[i][byte_off*8 +: 32];
		end
	endtask

  // --------------------------------------------------------------------------
  // Data conversion helpers
  // --------------------------------------------------------------------------
  function void beats_convert_to_bytes(
    input  bit [`DATA_WIDTH-1:0] darr[],
    output bit [7:0]             barr[]
  );
    barr = new[`STRB_WIDTH * darr.size()];

    foreach (darr[i]) begin
      for (int b = 0; b < `STRB_WIDTH; b++) begin
        barr[i * `STRB_WIDTH + b] = darr[i][8*b +: 8];
      end
    end
  endfunction

  function void bytes_convert_to_beats(
    input  bit [7:0]             barr[],
    output bit [`DATA_WIDTH-1:0] darr[]
  );
    int beat_num;

    if ((barr.size() % `STRB_WIDTH) != 0) begin
      `uvm_error(get_type_name(),
        $sformatf("bytes_convert_to_beats: byte count %0d is not divisible by STRB_WIDTH=%0d",
                  barr.size(), `STRB_WIDTH))
      darr = new[0];
      return;
    end

    beat_num = barr.size() / `STRB_WIDTH;
    darr = new[beat_num];

    foreach (darr[i]) begin
      darr[i] = '0;
      for (int b = 0; b < `STRB_WIDTH; b++) begin
        darr[i][8*b +: 8] = barr[i * `STRB_WIDTH + b];
      end
    end
  endfunction
endclass

`endif

