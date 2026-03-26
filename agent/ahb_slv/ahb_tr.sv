`ifndef AHB_TRANSACTION_SV
`define AHB_TRANSACTION_SV

class ahb_transaction extends uvm_sequence_item;

  `uvm_object_utils(ahb_transaction)

	//---control / address phase---
  ahb_addr_t                addr[];
  ahb_trans_e               trans[];
	ahb_burst_e               burst;
	ahb_size_e                size;
	ahb_length_t              len;
	xact_type_e               write;
	ahb_burst_type_e          burst_type;

	//---data / response phase---
	rand ahb_data_t           data[];
	rand ahb_resp_e           resp[];
	rand bit                  ready[];
	rand int unsigned         wait_delay;

	constraint reasonable_delay {

		wait_delay inside {[0:`MAX_DELAY]};

	  wait_delay dist {
			0                :/60,
			[1:3]            :/30,
			[4:6]            :/5,
			[7:`MAX_DELAY]   :/5
  	};
  }
	//---transacton meta-info---
	ahb_addr_t                start_addr;
	real                      start_time;
	real                      end_time;

	function new(string name = "ahb_transaction");
		super.new(name);
	endfunction

endclass

`endif

