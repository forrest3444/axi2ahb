package axi_frontend_pkg;

	parameter int ADDR_WIDTH = 32;
	parameter int DATA_WIDTH = 64;
	parameter int STRB_WIDTH = DATA_WIDTH/8;

  typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
    logic [3:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
		logic                  illegal;
  } aw_item_t;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [STRB_WIDTH-1:0] strb;
    logic                  last;
		logic                  illegal;
  } w_item_t;

  typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
    logic [3:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
		logic                  illegal;
  } ar_item_t;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic [1:0]            resp;
    logic                  last;
		logic                  illegal;
  } r_item_t;

endpackage
