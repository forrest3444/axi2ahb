`ifndef AXI_PKG_SV
`define AXI_PKG_SV

package axi_pkg;
	import uvm_pkg::*;
	`include "uvm_macros.svh"

	`include "axi2ahb_macros.svh"
	`include "axi_type.svh"
	`include "axi_tr.sv"
	`include "axi_m_cfg.sv"
	`include "axi_m_seqr.sv"
	`include "axi_m_mon.sv"
	`include "axi_m_drv.sv"
	`include "axi_m_agt.sv"
endpackage

`endif
