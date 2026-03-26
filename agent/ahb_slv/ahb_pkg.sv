`ifndef AHB_PKG_SV
`define AHB_PKG_SV

package ahb_pkg;
	import uvm_pkg::*;
	`include "uvm_macros.svh"
	import common_pkg::*;

	`include "axi2ahb_macros.svh"
	`include "ahb_type.svh"
	`include "ahb_tr.sv"
	`include "ahb_s_cfg.sv"
	`include "ahb_s_drv.sv"
	`include "ahb_s_mon.sv"
	`include "ahb_s_agt.sv"
endpackage

`endif
