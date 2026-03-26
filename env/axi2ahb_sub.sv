`ifndef AXI2AHB_SUB
`define AXI2AHB_SUB

`uvm_analysis_imp_decl(_mst)
`uvm_analysis_imp_decl(_slv)

class axi2ahb_subscriber extends uvm_component;

	`uvm_component_utils(axi2ahb_subscriber)

	uvm_analysis_imp_mst #(axi_transaction, axi2ahb_subscriber) mst_imp;
	uvm_analysis_imp_slv #(ahb_transaction, axi2ahb_subscriber) slv_imp;
	
	function new(string name = "axi2ahb_subscriber", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mst_imp = new("mst_imp", this);
		slv_imp = new("slv_imp", this);
	endfunction 

	virtual function void write_mst(axi_transaction tr);
	  //TODO: override in derived class if needed.
	endfunction

  virtual function void write_slv(ahb_transaction tr);
	  //TODO: override in derived class if needed.
	endfunction

endclass

`endif
