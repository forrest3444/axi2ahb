`ifndef MEMORY_SV
`define MEMORY_SV

class memory;

	typedef enum {
  MEMINIT_ZERO,
  MEMINIT_X,
  MEMINIT_VALUE
	} meminit_enum;

  // -----------------------------
  // Public attributes (runtime)
  // -----------------------------
  bit [`ADDR_WIDTH-1:0] min_addr;
  bit [`ADDR_WIDTH-1:0] max_addr;

  meminit_enum          meminit;
  bit [`DATA_WIDTH-1:0] meminit_value;

  // -----------------------------
  // Internal storage
  // -----------------------------
  byte mem [bit [`ADDR_WIDTH-1:0]]; // sparse byte-addressable memory

  // -----------------------------
  // Constructor
  // -----------------------------
  function new(
    bit [`ADDR_WIDTH-1:0] min_addr = 32'h0000_0000,
    bit [`ADDR_WIDTH-1:0] max_addr = 32'h0000_FFFF,
    meminit_enum          meminit  = MEMINIT_ZERO,
    bit [`DATA_WIDTH-1:0] meminit_value = '0
  );
    this.min_addr       = min_addr;
    this.max_addr       = max_addr;
    this.meminit        = meminit;
    this.meminit_value  = meminit_value;
  endfunction

	function void clean();
		mem.delete();
		`uvm_info("MEMORY", "Sparse memory has been cleared completely!", UVM_MEDIUM)
	endfunction

  function bit is_in_bounds(bit [`ADDR_WIDTH-1:0] addr);
    return (addr >= min_addr) && (addr <= max_addr);
  endfunction

  function bit is_aligned(bit [`ADDR_WIDTH-1:0] addr);
    return (addr % `STRB_WIDTH) == 0;
  endfunction

	//write
  function void write(
    bit [`ADDR_WIDTH-1:0] addr,
    bit [`DATA_WIDTH-1:0] data,
    bit [`STRB_WIDTH-1:0] byteen = ~0
  );
    if (!is_in_bounds(addr)) begin
      $error("[mem] Write out of bounds: addr=0x%0h", addr);
      return;
    end

    if (!is_aligned(addr)) begin
      $warning("[mem] Unaligned write: addr=0x%0h", addr);
    end

    for (int i = 0; i < `STRB_WIDTH; i++) begin
      if (byteen[i]) begin
        mem[addr + i] = data[i*8 +: 8];
      end
    end
  endfunction

	//read
  function bit [`DATA_WIDTH-1:0] read(
    bit [`ADDR_WIDTH-1:0] addr
  );
    bit [`DATA_WIDTH-1:0] rdata;

    if (!is_in_bounds(addr)) begin
      $error("[lite_mem] Read out of bounds: addr=0x%0h", addr);
      return '0;
    end

    if (!is_aligned(addr)) begin
      $warning("[lite_mem] Unaligned read: addr=0x%0h", addr);
    end

    for (int i = 0; i < `STRB_WIDTH; i++) begin
      if (mem.exists(addr + i)) begin
        rdata[i*8 +: 8] = mem[addr + i];
      end
      else begin
        case (meminit)
          MEMINIT_ZERO  : rdata[i*8 +: 8] = 8'h00;
          MEMINIT_X     : rdata[i*8 +: 8] = 8'hXX;
          MEMINIT_VALUE : rdata[i*8 +: 8] = meminit_value[i*8 +: 8];
        endcase
      end
    end
    return rdata;

  endfunction

	//single byte write.
  task write_byte(
    bit [`ADDR_WIDTH-1:0] addr,
    bit [7:0] data
  );
    if (!is_in_bounds(addr)) begin
      $error("[mem] write_byte out of bounds: addr=0x%0h", addr);
      return;
    end

    mem[addr] = data;
	endtask

  //multi byte write.
  task write_num_bytes(
    bit [`ADDR_WIDTH-1:0] addr,
    int no_of_bytes,
    bit [7:0] data[]
  );
    if (data.size() != no_of_bytes) begin
      $error("[mem] write_num_bytes: data array don't match the number of bytes");
      return;
    end

    for (int i = 0; i < no_of_bytes; i++) begin
      write_byte(addr + i, data[i]);
    end
  endtask

	//single byte read.
  task read_byte(
    bit [`ADDR_WIDTH-1:0] addr,
    output bit [7:0] data
  );
    if (!is_in_bounds(addr)) begin
      $error("[mem] read_byte out of bounds: addr=0x%0h", addr);
      data = 8'hXX;
      return;
    end

    if (mem.exists(addr)) begin
      data = mem[addr];
    end
    else begin
      case (meminit)
        MEMINIT_ZERO  : data = 8'h00;
        MEMINIT_X     : data = 8'hXX;
        MEMINIT_VALUE : data = meminit_value[7:0];
      endcase
    end
  endtask

	//multi byte read.
  task read_num_bytes(
    bit [`ADDR_WIDTH-1:0] addr,
    int no_of_bytes,
    output bit [7:0] data[]
  );
    data = new[no_of_bytes];

    for (int i = 0; i < no_of_bytes; i++) begin
      read_byte(addr + i, data[i]);
    end
  endtask

endclass

`endif
