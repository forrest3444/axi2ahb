module bridge_arbiter #(
  parameter bit DEBUG_EN = 1'b0
)(
  input  logic clk,
  input  logic rstn,

  // --------------------------------------------------------------------------
  // global admission gate
  // 1: scheduler/controller can accept a new transaction
  // 0: scheduler closed (controller busy or intentionally blocked)
  // --------------------------------------------------------------------------
  input  logic accept_enable,

  // --------------------------------------------------------------------------
  // executable candidate pool from fifo_ctrl
  // candidates presented here should already be "safe to launch"
  // --------------------------------------------------------------------------
  input  logic wr_candidate,
  input  logic rd_candidate,

  // --------------------------------------------------------------------------
  // handshake from controller:
  // current combinational grant is really consumed this cycle
  // --------------------------------------------------------------------------
  input  logic grant_accept,

  // --------------------------------------------------------------------------
  // arbitration result
  // one-hot when grant_valid=1
  // --------------------------------------------------------------------------
  output logic grant_valid,
  output logic grant_wr,
  output logic grant_rd,

  // --------------------------------------------------------------------------
  // debug outputs
  // --------------------------------------------------------------------------
  output logic last_grant_dbg,       // 0: last accepted grant was read
                                     // 1: last accepted grant was write
  output logic [1:0] arb_state_dbg,  // 00:no candidate, 01:rd only, 10:wr only, 11:both
  output logic       tie_break_dbg   // 1: current cycle tie-break active
);

  typedef enum logic {
    LAST_RD = 1'b0,
    LAST_WR = 1'b1
  } last_grant_e;

  last_grant_e last_grant;

  logic [1:0] candidate_vec;
  logic       tie_break_hit;

  // ==========================================================================
  // candidate snapshot
  // ==========================================================================
  always_comb begin
    candidate_vec = {wr_candidate, rd_candidate};
  end

  // ==========================================================================
  // combinational arbitration
  //
  // policy:
  //   - if only one side is executable, grant it
  //   - if both are executable, alternate based on last accepted grant
  //   - if accept gate is closed, do not issue any grant
  // ==========================================================================
  always_comb begin
    grant_valid   = 1'b0;
    grant_wr      = 1'b0;
    grant_rd      = 1'b0;
    tie_break_hit = 1'b0;

    if (accept_enable) begin
      unique case (candidate_vec)
        2'b10: begin
          grant_valid = 1'b1;
          grant_wr    = 1'b1;
        end

        2'b01: begin
          grant_valid = 1'b1;
          grant_rd    = 1'b1;
        end

        2'b11: begin
          grant_valid   = 1'b1;
          tie_break_hit = 1'b1;

          // alternate on every accepted tie
          // if last accepted was WR, favor RD this time
          if (last_grant == LAST_WR) begin
            grant_rd = 1'b1;
          end
          else begin
            grant_wr = 1'b1;
          end
        end

        default: begin
          grant_valid = 1'b0;
          grant_wr    = 1'b0;
          grant_rd    = 1'b0;
        end
      endcase
    end
  end

  // ==========================================================================
  // last_grant update
  //
  // update only when the currently visible grant is actually consumed
  // by controller. this prevents false fairness rotation caused by a
  // speculative combinational grant that was never accepted.
  // ==========================================================================
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      // reset preference:
      // start as LAST_RD so first tie favors WR
      last_grant <= LAST_RD;
    end
    else if (grant_valid && grant_accept) begin
      if (grant_wr) begin
        last_grant <= LAST_WR;
      end
      else if (grant_rd) begin
        last_grant <= LAST_RD;
      end
    end
  end

  // ==========================================================================
  // debug outputs
  // keep interface stable; zero-out when DEBUG_EN=0
  // ==========================================================================
  generate
    if (DEBUG_EN) begin : g_debug_on
      always_comb begin
        last_grant_dbg = last_grant;
        arb_state_dbg  = candidate_vec;
        tie_break_dbg  = tie_break_hit;
      end
    end
    else begin : g_debug_off
      always_comb begin
        last_grant_dbg = 1'b0;
        arb_state_dbg  = 2'b00;
        tie_break_dbg  = 1'b0;
      end
    end
  endgenerate

endmodule
