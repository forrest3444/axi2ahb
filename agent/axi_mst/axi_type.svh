`ifndef AXI_TYPE_SV
`define AXI_TYPE_SV

typedef bit [`ADDR_WIDTH-1:0] axi_addr_t;
typedef bit [`DATA_WIDTH-1:0] axi_data_t;
typedef bit [`STRB_WIDTH-1:0] axi_wstrb_t;
typedef bit [`LEN_WIDTH:0]    axi_length_t;//1-256

typedef enum bit [1:0] {
	FIXED = 2'b00,
  INCR  = 2'b01,
	WRAP  = 2'b10
} axi_burst_type_e;

typedef enum bit [2:0] {
	SIZE_1B   = 3'b000,
 	SIZE_2B   = 3'b001,
 	SIZE_4B   = 3'b010,
 	SIZE_8B   = 3'b011,
 	SIZE_16B  = 3'b100,
 	SIZE_32B  = 3'b101,
 	SIZE_64B  = 3'b110,
 	SIZE_128B = 3'b111
} axi_size_e;

typedef enum bit {
	READ  = 0, 
	WRITE = 1
} xact_type_e;

typedef enum bit [1:0] {
	OKAY     = 2'b00,
	SLVERR   = 2'b10
} axi_resp_e;

`endif
