TB        = top_tb
TESTNAME ?= incr_random_len_wr_test
SEED      = 1
VERB     ?= UVM_MEDIUM
RUN_TIME ?= 1

OUT      ?= out
RUN_DIR   = $(OUT)/$(TESTNAME)_seed_$(SEED)
LOG_DIR   = $(RUN_DIR)/log
WAVE_DIR  = $(RUN_DIR)/wave
COV_DIR   = $(RUN_DIR)/cov
SIMV_DIR  = $(RUN_DIR)/simv

INC_DIR = +incdir+../config      \
					+incdir+../cov         \
					+incdir+../debug       \
					+incdir+../dut         \
					+incdir+../env         \
					+incdir+../seq_lib     \
					+incdir+../tb          \
					+incdir+../tests       \
					+incdir+../agent/axi_mst \
					+incdir+../agent/ahb_slv \
					+incdir+../agent/common  

DFILES   = -f ./filelist.f
VFILES   = ../config/axi2ahb_macros.svh \
           ../agent/common/common_pkg.sv  \
					 ../agent/axi_mst/axi_pkg.sv    \
					 ../agent/ahb_slv/ahb_pkg.sv    \
					 ../tb/axi_if.sv              \
					 ../tb/ahb_if.sv              \
           ../env/axi2ahb_pkg.sv        \
					 ../tb/top_tb.sv
PTHREAD_FIX = ../debug/pthread_yield_shim.c

VCS_OPT = -full64                      \
					-sverilog                    \
					-kdb                         \
					-debug_access+all            \
					-timescale=1ns/1ps           \
					-ntb_opts uvm-1.2            \
					-lca                         \
					-nc                          \
		      -cm line+cond+fsm+branch+tgl+assert \
		      -cm_dir $(RUN_DIR)/cov       \
					$(INC_DIR)

all: prepare elab run

prepare:
	mkdir -p $(LOG_DIR)
	mkdir -p $(WAVE_DIR)
	mkdir -p $(COV_DIR)
	mkdir -p $(SIMV_DIR)

elab: prepare
	vcs $(VCS_OPT)                \
		  $(PTHREAD_FIX)            \
		  $(DFILES) $(VFILES)       \
	    -top $(TB)                \
		  -l $(LOG_DIR)/compile.log \
		  -o $(SIMV_DIR)/$(TB).simv 

run:
	$(SIMV_DIR)/$(TB).simv                                \
		timeout $(RUN_TIME)                                 \
		+ntb_random_seed=$(SEED)                            \
		+UVM_TESTNAME=$(TESTNAME)                           \
		+UVM_VERBOSITY=$(VERB)                              \
		-cm line+cond+fsm+branch+tgl+assert                 \
		-cm_dir $(RUN_DIR)/cov                              \
		+vcs+watchdog+time=5ms                              \
		+FSDB                                               \
		+FSDB_FILE=$(WAVE_DIR)/$(TESTNAME)_seed$(SEED).fsdb \
		-l $(LOG_DIR)/run.log

verdi:
	verdi -sv       \
		-f filelist.f \
		-top $(TB)    \
		-ssf $(WAVE_DIR)/$(TESTNAME)_seed$(SEED).fsdb &

merge_cov:
	urg \
	  -dir $(OUT)/single_write_read_test_seed_1/cov.vdb \
	  -dir $(OUT)/fd_write_bd_read_test_seed_1/cov.vdb \
	  -dir $(OUT)/bd_write_fd_read_test_seed_1/cov.vdb \
	  -dir $(OUT)/incr_random_len_wr_test_seed_1/cov.vdb \
	  -dir $(OUT)/wrap_random_len_wr_test_seed_1/cov.vdb \
	  -dir $(OUT)/fixed_random_len_write_test_seed_1/cov.vdb \
	  -dir $(OUT)/fixed_random_len_read_test_seed_1/cov.vdb \
	  -dir $(OUT)/fixed_read_boundary_combo_test_seed_1/cov.vdb \
	  -dbname $(OUT)/merged_cov

clean:
	rm -rf $(OUT) 
	rm -rf 64 AN.DB DVEfiles csrc *.simv *.simv.daidir *.simv.vdb ucli.key vdCovLog vhdl_objs_dir
	rm -rf .shadow *.Log* *.conf *.vpd *.h urgReport work.lib++ verdiLog 64 *.tar.gz stack.info*
	rm -rf *.vdb eman* *_cosim *.slave_transaction_trace *.fsdb *.setup *.rc *.log


