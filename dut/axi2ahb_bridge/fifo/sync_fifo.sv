module sync_fifo #(
	parameter int unsigned DEPTH = 32,
	parameter int unsigned WIDTH = 64,
	parameter int unsigned AFULL_TH = (DEPTH > 1) ? (DEPTH - 1) : 1,
	parameter int unsigned AEMPTY_TH = 1
)(
	input  logic clk,
	input  logic rstn,

	input  logic write_en,
	input  logic [WIDTH-1:0]data_in,

	input  logic read_en,
	output logic [WIDTH-1:0] data_out,

	output logic full,
	output logic empty,
	output logic almost_full,
	output logic almost_empty,
	output logic [$clog2(DEPTH+1)-1:0] count,
  // -------------------------
  // debug / observability
  // -------------------------
  output logic                     wr_fire,          //write success indeed
  output logic                     rd_fire,          //read success indeed
  output logic                     overflow_pulse,   //still write while fifo full
  output logic                     underflow_pulse,  //still read while fifo empty

  output logic [$clog2(DEPTH)-1:0] wr_ptr_dbg,
  output logic [$clog2(DEPTH)-1:0] rd_ptr_dbg,
  output logic [WIDTH-1:0]         head_dbg,
  output logic [WIDTH-1:0]         tail_dbg
);
  // ------------------------------------------------------------
  // compile-time checks
  // ------------------------------------------------------------
  initial begin
    if (DEPTH < 2) begin
      $error("sync_fifo: DEPTH must be >= 2, got %0d", DEPTH);
    end
    if (AFULL_TH > DEPTH) begin
      $error("sync_fifo: AFULL_TH (%0d) cannot be greater than DEPTH (%0d)",
             AFULL_TH, DEPTH);
    end
    if (AEMPTY_TH > DEPTH) begin
      $error("sync_fifo: AEMPTY_TH (%0d) cannot be greater than DEPTH (%0d)",
             AEMPTY_TH, DEPTH);
    end
  end

  localparam int unsigned PTR_W   = $clog2(DEPTH);
  localparam int unsigned COUNT_W = $clog2(DEPTH+1);	

  // ------------------------------------------------------------
  // storage
  // ------------------------------------------------------------
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  logic [PTR_W-1:0] wr_ptr;
  logic [PTR_W-1:0] rd_ptr;

  logic [COUNT_W-1:0] count_n;

  logic [PTR_W-1:0] wr_ptr_n;
  logic [PTR_W-1:0] rd_ptr_n;

  logic do_write, do_read;

  // ------------------------------------------------------------
  // helpers
  // ------------------------------------------------------------
  function automatic logic [PTR_W-1:0] ptr_inc(input logic [PTR_W-1:0] ptr);
    if (ptr == PTR_W'(DEPTH-1))
      ptr_inc = '0;
    else
      ptr_inc = ptr + 1'b1;
  endfunction

  assign do_write = write_en && !full;
  assign do_read  = read_en  && !empty;

  assign wr_fire = do_write;
  assign rd_fire = do_read;

  // debug signal
  assign overflow_pulse  = write_en && full && !do_read;
  assign underflow_pulse = read_en  && empty;

  // ------------------------------------------------------------
  // next-state calculation
  // ------------------------------------------------------------
  always_comb begin
    // default hold
    wr_ptr_n = wr_ptr;
    rd_ptr_n = rd_ptr;
    count_n  = count;

    unique case ({do_write, do_read})
      2'b10: begin
        wr_ptr_n = ptr_inc(wr_ptr);
        count_n  = count + 1'b1;
      end

      2'b01: begin
        rd_ptr_n = ptr_inc(rd_ptr);
        count_n  = count - 1'b1;
      end

      2'b11: begin
        wr_ptr_n = ptr_inc(wr_ptr);
        rd_ptr_n = ptr_inc(rd_ptr);
        count_n  = count; // simultaneous read & write => occupancy unchanged
      end

      default: begin
        // hold
      end
    endcase
  end

  // ------------------------------------------------------------
  // state flags from current state
  // ------------------------------------------------------------
  always_comb begin
    full  = (count == COUNT_W'(DEPTH));
    empty = (count == '0);

    almost_full  = (count >= COUNT_W'(AFULL_TH)) && !full;
    almost_empty = (count <= COUNT_W'(AEMPTY_TH)) && !empty;
  end

  // ------------------------------------------------------------
  // FWFT data_out
  //
  // -When not empty, data_out presents the current head of the queue, mem[rd_ptr] 
	// -When empty, if this cycle is write-only (no read), it can bypass to present data_in (FWFT-friendly)
  // -This is more natural for waveform observation and downstream combinational logic decision-making
  // ------------------------------------------------------------
  always_comb begin
    data_out = '0;

    if (!empty) begin
      // show-ahead
      data_out = mem[rd_ptr];
    end
    else if (write_en && !full) begin
      // When an empty FIFO is written to, FWFT bypass takes effect:
			// the new queue head is visible in the same cycle.
      data_out = data_in;
    end
  end

  // ------------------------------------------------------------
  // sequential update
  // ------------------------------------------------------------
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
    end
    else begin
			//write ram first
      if (do_write) begin
        mem[wr_ptr] <= data_in;
      end

      // update pointer/count then
      wr_ptr <= wr_ptr_n;
      rd_ptr <= rd_ptr_n;
      count  <= count_n;
    end
  end

  // ------------------------------------------------------------
  // debug ports
  // ------------------------------------------------------------
  assign wr_ptr_dbg = wr_ptr;
  assign rd_ptr_dbg = rd_ptr;

  assign head_dbg = (!empty) ? mem[rd_ptr] : data_out;

  // tail_dbg shows the "most recent write position", which is more valuable for debugging
  // When wr_ptr==0, the most recent write position is regarded as DEPTH-1
  always_comb begin
    if (count == 0) begin
      tail_dbg = '0;
    end
    else if (wr_ptr == '0) begin
      tail_dbg = mem[DEPTH-1];
    end
    else begin
      tail_dbg = mem[wr_ptr - 1'b1];
    end
  end

endmodule

