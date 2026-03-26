`ifndef AXI2AHB_PKG_SV
`define AXI2AHB_PKG_SV

`include "axi_if.sv"
`include "ahb_if.sv"
`include "dut_dbg_if.sv"

package axi2ahb_pkg;
	import uvm_pkg::*;
	`include "uvm_macros.svh"

	import common_pkg::*;
	import axi_pkg::*;
	import ahb_pkg::*;

	`include "axi2ahb_macros.svh"
	`include "axi2ahb_config.sv"
	`include "axi2ahb_virt_seqr.sv"
	`include "virt_seqs.svh"
	`include "axi2ahb_sub.sv"
	`include "axi2ahb_cov.sv"
	`include "axi2ahb_scb.sv"
	`include "axi2ahb_env.sv"
	`include "tests.svh"


endpackage

`endif

