`ifndef AXI_IF__SV
`define AXI_IF__SV

import uvm_pkg::*;

typedef enum bit[1:0] { FIXED, INCR, WRAP } B_TYPE;

class axi_tr #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32) extends uvm_sequence_item;

	typedef axi_tr #(DATA_WIDTH, ADDR_WIDTH) this_type_t;

	`uvm_object_param_utils(axi_tr #(DATA_WIDTH, ADDR_WIDTH));

	rand bit [ADDR_WIDTH-1:0] addr;
	rand bit [7:0]            data [][];
	rand bit [2:0]            b_size;
	rand bit [3:0]            b_len;
	rand B_TYPE               b_type;
	bit                       b_last;
	bit [1:0]                 b_resp;
	bit [1:0]                 r_resp[];

	//Constraints
	constraint b_size_val { 8*(2**b_size) <= DATA_WIDTH; }

	constraint data_size {
		solve b_len before data;
		solve b_size before data;

		data.size() == b_len+1;
		foreach (data[i])
			data[i].size() == 2**b_size;
	}

	constraint b_len_val {
			/*  solve order constraints  */
			solve b_type before b_len;

			/*  rand variable constraints  */
			if(b_type == FIXED)
					b_len inside { 0, 1 };
			else if(b_type == WRAP)
					b_len inside { 1, 3, 7, 15 };
	}

	constraint addr_val {
			/*  solve order constraints  */
			solve b_type before addr;
			solve b_size before addr;

			/*  rand variable constraints  */
			if(b_type == WRAP)
					addr == int'(addr/2**b_size) * 2**b_size;
	}

	constraint addr_val_align {
			/*  solve order constraints  */
			solve b_size before addr;

			/*  rand variable constraints  */
			addr == int'(addr/2**b_size) * 2**b_size;
	}

	constraint addr_val_unalign {
			/*  solve order constraints  */
			solve b_size before addr;

			/*  rand variable constraints  */
			addr != int'(addr/2**b_size) * 2**b_size;
	}

		//  Constructor: new
	function new(string name = "axi_tr");
			super.new(name);
	endfunction: new

	//  Function: do_copy
	extern function void do_copy(uvm_object rhs);
	//  Function: do_compare
	extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
	//  Function: convert2string
	extern function string convert2string();
	//  Function: do_print
	extern function void do_print(uvm_printer printer);

endclass: axi_tr

function void axi_tr::do_print(uvm_printer printer);
    /*  chain the print with parent classes  */
    super.do_print(printer);

    /*  list of local properties to be printed:  */
    //printer.print_field("ID", id, $bits(id), UVM_UNSIGNED);
    printer.print_field("Addr", addr, $bits(addr), UVM_HEX);
    printer.print_generic("Data", "dynamic array", 8*2**b_size*(b_len+1), $sformatf("%u", data));
    printer.print_field("Burst Size", b_size, $bits(b_size), UVM_UNSIGNED);
    printer.print_field("Burst Length", b_len+1, $bits(b_len), UVM_UNSIGNED);
    printer.print_generic("Burst Type", "B_TYPE", $bits(b_len), b_type.name());
endfunction: do_print

function string axi_tr::convert2string();
    string s;

    /*  chain the convert2string with parent classes  */
    s = super.convert2string();

    /*  list of local properties to be printed:  */
    //  guide             0---4---8--12--16--20--24--28--32--36--40--44--48--
    //s = {s, $sformatf("ID             :   %0d\n", id)};
    s = {s, $sformatf("Addr           : 0x%0h\n", addr)};
    s = {s, $sformatf("Data           : 0x%0u\n", data)};
    s = {s, $sformatf("Burst Type     :   %s\n", b_type.name())};
    s = {s, $sformatf("Burst Size     :   %0d\n", b_size)};
    s = {s, $sformatf("Burst Length   :   %0d\n", b_len+1)};
    s = {s, $sformatf("Burst resp     : 0x%0h\n", b_resp)};
    s = {s, $sformatf("Read resp      :   %0u\n", r_resp)};
    return s;
endfunction: convert2string

function void axi_tr::do_copy(uvm_object rhs);
    this_type_t rhs_;

    if (!$cast(rhs_, rhs)) begin
        `uvm_error({this.get_name(), ".do_copy()"}, "Cast failed!");
        return;
    end
    // `uvm_info({this.get_name(), ".do_copy()"}, "Cast succeded.", UVM_HIGH);

    /*  chain the copy with parent classes  */
    super.do_copy(rhs);

    /*  list of local properties to be copied  */
    //this.id     = rhs_.id;
    this.addr   = rhs_.addr;
    this.data   = rhs_.data;
    this.b_type = rhs_.b_type;
    this.b_size = rhs_.b_size;
    this.b_len  = rhs_.b_len;
    this.b_resp = rhs_.b_resp;
    this.r_resp = rhs_.r_resp;
endfunction: do_copy

function bit axi_tr::do_compare(uvm_object rhs, uvm_comparer comparer);
    this_type_t rhs_;

    if (!$cast(rhs_, rhs)) begin
        `uvm_error({this.get_name(), ".do_compare()"}, "Cast failed!");
        return 0;
    end
    // `uvm_info({this.get_name(), ".do_compare()"}, "Cast succeded.", UVM_HIGH);

    /*  chain the compare with parent classes  */
    do_compare = super.do_compare(rhs, comparer);

    /*  list of local properties to be compared:  */
    do_compare &= (
        //this.id == rhs_.id &&
        this.addr == rhs_.addr &&
        this.b_type == rhs_.b_type &&
        this.b_size == rhs_.b_size &&
        this.b_len == rhs_.b_len &&
        this.b_resp == rhs_.b_resp 
    );

    foreach(data[i,j]) begin
        do_compare &= this.data[i][j] == rhs_.data[i][j];
    end

    foreach ( r_resp[i] ) begin
        do_compare &= this.r_resp[i] == rhs_.r_resp[i];
    end
endfunction: do_compare

