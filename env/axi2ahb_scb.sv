`ifndef AXI2AHB_SCB__SV
`define AXI2AHB_SCB__SV

`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_ahb)

class axi2ahb_scoreboard extends uvm_scoreboard;

	`uvm_component_utils(axi2ahb_scoreboard)

	uvm_analysis_imp_axi #(axi_tr #(DATA_WIDTH, ADDR_WIDTH), axi2ahb_scoreboard)  axi_ap_imp;
	uvm_analysis_imp_ahb #(ahb_tr #(DATA_WIDTH, ADDR_WIDTH), axi2ahb_scoreboard)  ahb_ap_imp;

	axi_tr #(DATA_WIDTH, ADDR_WIDTH)  m_wtrs, m_rtrs;
	ahb_tr #(DATA_WIDTH, ADDR_WIDTH)  s_wtrs, s_wtrs;
	bit [1:0] w_rcvd, r_rcvd;
	int passcnt, failcnt;

	function new(string name = "axi2ahb_scoreboard", uvm_component parent);
		super.new(name, parent);
		axi_ap_imp = new("axi_ap_imp", this);
		ahb_ap_imp = new("ahb_ap_imp", this);
	endfunction

	extern bit compare_axi2ahb(axi_tr atr, ahb_tr htr);

endclass
