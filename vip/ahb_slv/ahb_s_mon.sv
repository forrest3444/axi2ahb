`ifndef AHB_S_MON__SV
`define AHB_S_MON__SV

class ahb_s_monitor extends uvm_monitor;

	`uvm_component_utils(ahb_s_monitor)

	virtual ahb_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)).smon	hvif;
	ahb_tr #(DATA_WIDTH, ADDR_WIDTH)	htr;

	uvm_analysis_port #(ahb_tr #(DATA_WIDTH, ADDR_WIDTH))  ap;

	function new(string name = "ahb_s_monitor", uvm_component parent);
		super.new(name, parent);
	  ap = new("ap", this);
	endfunction

		task run_phase(uvm_phase phase);
		forever begin
			fork
				begin: mon
					monitor();
					disable wait_for_reset;
				end
				begin: wait_for_reset
					wait(!hvif.hresetn);
					htr = ahb_transaction::type_id::create("htr");
					htr.reset = 0;
					$cast(htr.trans_type, hvif.htrans);
					disable mon;
					monitor_ap.write(htr);
					@(hvif.smon_cb);
				end
				join
		end
	endtask

	extern task monitor();

endclass

task ahb_s_monitor::monitor();

	forever begin: MON_LOOP
		@(hvif.smon_cb);
		wait (hvif.hresetn && (hvif.smon_cb.htrans inside {NONSEQ, SEQ}) && hvif.smon_cb.hready);

		htr = ahb_transaction::type_id::create("htr");
		
		htr.trans_type = hvif.smon_cb.htrans;
		htr.burst_mode = hvif.smon_cb.hburst;
		htr.trans_size = hvif.smon_cb.hsize;
		htr.read_write = hvif.smon_cb.hwrite;
		htr.address.push_back(hvif.smon_cb.haddr);

    // 打印事务开始信息
    `uvm_info(get_type_name(),
              $sformatf("New Transaction Started: addr=%h, write=%0d", htr.address[0], htr.read_write),
              UVM_MEDIUM)

    // 收集 burst 数据
    do begin : BURST_COLLECT
      @(posedge vif.mmon_cb.HCLK);

      // 如果响应错误
      if (vif.mmon_cb.HRESP == 1) begin
        `uvm_error(get_type_name(), $sformatf("ERROR response on address %h", htr.address.back()))
        break;
      end

      // 只有当 HREADY 为高时，说明上一个传输完成
      if (vif.mmon_cb.HREADY) begin
        if (htr.read_write == READ)
          htr.read_data.push_back(vif.mmon_cb.HRDATA);
        else
          htr.write_data.push_back(vif.mmon_cb.HWDATA);

        // 收集后续 SEQ 传输的地址
        if (vif.mmon_cb.HTRANS == SEQ)
          htr.address.push_back(vif.mmon_cb.HADDR);
      end

    end while (vif.mmon_cb.HTRANS == SEQ && vif.mmon_cb.HREADY);

    // 打印事务收集结果
    `uvm_info(get_type_name(), "Transaction completed by AHB Slave Monitor", UVM_MEDIUM)
    htr.print();

    // 发送到 analysis port
    monitor_ap.write(htr);

  end : MON_LOOP
endtask

