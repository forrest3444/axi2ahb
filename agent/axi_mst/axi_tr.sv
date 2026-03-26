`ifndef AXI_TRANSACTION_SV
`define AXI_TRANSACTION_SV

class axi_transaction extends uvm_sequence_item;

	bit addr_align_enable = 1;

  rand xact_type_e             xact_type;
	rand axi_addr_t              addr;
	rand axi_size_e              size;
	rand axi_length_t            len;
	rand axi_burst_type_e        burst;
	axi_resp_e                   bresp;

	rand axi_data_t              data[];
	axi_wstrb_t                  wstrb[];
	axi_resp_e                   rresp[];

	//Constraints
	constraint size_c { 8*(2**size) <= `DATA_WIDTH; }

	constraint data_size_c {
		solve len before data;

		data.size() == len + 1;
	}

	constraint len_c {
			/*  solve order constraints  */
			solve burst before len;

			/*  rand variable constraints  */
			if(burst == WRAP)
				len inside { 1, 3, 7, 15 };
	}

	constraint addr_align_c {
			/*  solve order constraints  */
			solve burst before addr;
			solve size before addr;

			/*  rand variable constraints  */
			if(burst == WRAP)
				addr == int'(addr/2**size) * 2**size;
			else if(addr_align_enable)
				addr == int'(addr/2**size) * 2**size;
			else
				addr != int'(addr/2**size) * 2**size;
	}

	`uvm_object_utils(axi_transaction);

	function new(string name = "axi_transaction");
			super.new(name);
	endfunction: new

	extern function void do_copy(uvm_object rhs);
	extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
	extern function string convert2string();
	extern function void do_print(uvm_printer printer);
	extern function axi_resp_e get_txn_resp();
	extern function bit has_error();

endclass

function void axi_transaction::do_print(uvm_printer printer);
    super.do_print(printer);

		printer.print_string("Xact type", xact_type.name());
    printer.print_field("Addr", addr, $bits(addr), UVM_HEX);
    printer.print_string("Burst type", burst.name());
    printer.print_field("Burst Size", size, $bits(size), UVM_UNSIGNED);
    printer.print_field("Burst Length", len+1, $bits(len), UVM_UNSIGNED);
    printer.print_generic(
			"Data", "dynamic array",
		 	8*2**size*(len+1),
		 	$sformatf("%p", data)
		);
endfunction

function string axi_transaction::convert2string();
    string s;

    s = super.convert2string();

    s = {s, $sformatf("Xact_type      :    %s\n", xact_type.name())};
    s = {s, $sformatf("Addr           : 0x%0h\n", addr)};
    s = {s, $sformatf("Burst Type     :    %s\n", burst.name())};
    s = {s, $sformatf("Burst Size     :   %0d\n", size)};
    s = {s, $sformatf("Burst Length   :   %0d\n", len+1)};
    s = {s, $sformatf("Write resp     : 0x%0h\n", bresp)};
    s = {s, $sformatf("Read resp      :   %0p\n", rresp)};
    s = {s, $sformatf("Data           :   %0p\n", data)};

    return s;
endfunction

function void axi_transaction::do_copy(uvm_object rhs);
    axi_transaction rhs_;

    if (!$cast(rhs_, rhs)) begin
        `uvm_error({this.get_name(), ".do_copy()"}, "Cast failed!");
        return;
    end

    super.do_copy(rhs);

		this.xact_type = rhs_.xact_type;
    this.addr      = rhs_.addr;
    this.burst     = rhs_.burst;
    this.size      = rhs_.size;
    this.len       = rhs_.len;

    this.data      = rhs_.data;
		this.wstrb     = rhs_.wstrb;
    this.bresp     = rhs_.bresp;
    this.rresp     = rhs_.rresp;
endfunction

function bit axi_transaction::do_compare(uvm_object rhs, uvm_comparer comparer);
    axi_transaction rhs_;

    if (!$cast(rhs_, rhs)) begin
        `uvm_error({this.get_name(), ".do_compare()"}, "Cast failed!");
        return 0;
    end

		if(!super.do_compare(rhs, comparer))
			return 0;

		if(xact_type != rhs_.xact_type) return 0;
		if(addr      != rhs_.addr)      return 0;
		if(burst     != rhs_.burst)     return 0;
		if(size      != rhs_.size)      return 0;
		if(len       != rhs_.len)       return 0;
		if(bresp     != rhs_.bresp)     return 0;

		if(data.size() != rhs_.data.size()) return 0;
		foreach(data[i])
			if(data[i] != rhs_.data[i]) return 0;
			
		if(rresp.size() != rhs_.rresp.size()) return 0;
		foreach(rresp[i])
			if(rresp[i] != rhs_.rresp[i]) return 0;

		if(wstrb.size() != rhs_.wstrb.size()) return 0;
		foreach(wstrb[i])
			if(wstrb[i] != rhs_.wstrb[i]) return 0;

		return 1;
endfunction

function axi_resp_e axi_transaction::get_txn_resp();
	if(xact_type == WRITE) begin
		return bresp;
	end
	else begin
		foreach(rresp[i]) begin
			if(rresp[i] != OKAY)
				return SLVERR;
		end
		return OKAY;
	end
endfunction

function bit axi_transaction::has_error();
	if(xact_type == WRITE)
		return (bresp != OKAY);
	else begin
		foreach(rresp[i]) begin
			if(rresp[i] != OKAY)
				return 1;
		end
		return 0;
	end
endfunction

`endif
