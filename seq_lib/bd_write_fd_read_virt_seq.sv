`ifndef AXI2AHB_BD_WRITE_FD_READ_VIRT_SEQ_SV
`define AXI2AHB_BD_WRITE_FD_READ_VIRT_SEQ_SV

class bd_write_fd_read_virt_seq extends base_virtual_sequence;

	`uvm_object_utils(bd_write_fd_read_virt_seq)

	rand int unsigned sequence_length = 10;
	rand bit [`DATA_WIDTH-1:0] data[][];
	rand bit [`ADDR_WIDTH-1:0] addr[];
	bit      [`DATA_WIDTH-1:0] read_words[];
	axi_resp_e      rresp[] = new[8];

	constraint reasonable_sequence_length {
		sequence_length inside {[10:20]};
	  data.size() == sequence_length;
		addr.size() == sequence_length;
		foreach(data[i]) data[i].size() == 8;
		foreach(addr[i]) {addr[i][2:0] == 0; addr[i][31:16] == 0;}
	}

	function new(string name = "bd_write_fd_read_virt_seq");
		super.new(name);
	endfunction

	virtual task body();
		super.body();
		`uvm_info("body", "Entered...", UVM_LOW)
		add_tag();

		foreach(data[i]) begin
			
			bd_write_num_beats(addr[i], $size(data[i]), data[i]);

			fd_read_num_beats(addr[i], $size(data[i]), read_words, rresp);

			foreach(data[i][j]) begin
				compare_data(
					data[i][j],
				 	read_words[j],
				 	$sformatf("bd_write_word[%0d][%0d]", i, j),
					$sformatf("fd_read_word[%0d][%0d]", i, j)
				);
			end
		end

		set_check_state_by_check_error_num();
			
		`uvm_info("body", "Exiting...", UVM_LOW)
	endtask

	virtual function void add_tag();
		add_check_tag("bd_write_fd_read", "Directed write & read");
	endfunction
endclass

`endif

