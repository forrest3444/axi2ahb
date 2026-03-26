`ifndef AHB_TYPES__SV
`define AHB_TYPES__SV

typedef bit [`ADDR_WIDTH-1:0] ahb_addr_t;
typedef bit [`DATA_WIDTH-1:0] ahb_data_t;
typedef bit [`LEN_WIDTH:0]  ahb_length_t;

typedef enum bit [1:0] {
	IDLE,
 	BUSY,
 	NONSEQ,
 	SEQ
} ahb_trans_e;

typedef enum bit {
	READ,
 	WRITE
} xact_type_e;

typedef enum bit [2:0] {
	SINGLE,
 	INCR,
 	WRAP4,
 	INCR4,
 	WRAP8,
 	INCR8,
 	WRAP16,
 	INCR16
} ahb_burst_e;

typedef enum bit [2:0] {
	BYTE1,
 	BYTE2,
 	BYTE4,
 	BYTE8,
 	BYTE16,
 	BYTE32,
 	BYTE64,
 	BYTE128
} ahb_size_e;

typedef enum bit [1:0] {
	OKAY,
 	ERROR,
	RETRY,
  SPLIT
} ahb_resp_e;

typedef enum bit [1:0] {
	AHB_FIXED,
 	AHB_INCR,
 	AHB_WRAP
} ahb_burst_type_e;

`endif 
