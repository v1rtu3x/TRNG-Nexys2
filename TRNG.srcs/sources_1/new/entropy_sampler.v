//-----------------------------------------------------------------------------
// Entropy sampler / TRNG front-end
//  - Instantiates a bank of ring oscillators
//  - XORs them to get entropy_raw
//  - Samples with system clock (and syncs)
//  - Applies a simple Von Neumann debiaser
//  - Outputs rnd_bit + rnd_valid
//-----------------------------------------------------------------------------
module entropy_sampler #(
    parameter integer NUM_RO  = 8,  // number of ring oscillators
    parameter integer STAGES  = 5   // must be odd
)(
    input  wire clk,        // system clock (e.g. 50 MHz)
    input  wire rst,        // synchronous reset, active high
    input  wire enable,     // enable for ring oscillators

    output reg  rnd_bit,    // debiased random bit
    output reg  rnd_valid   // 1-cycle pulse when rnd_bit is valid
);

    // ------------------------------------------------------------------------
    // 1) Ring oscillator bank + XOR
    // ------------------------------------------------------------------------
    wire [NUM_RO-1:0] ro_bits;
    wire              entropy_raw;

    ring_osc_bank #(
        .NUM_RO (NUM_RO),
        .STAGES(STAGES)
    ) u_ro_bank (
        .enable(enable),
        .ro_out(ro_bits)
    );

    // XOR reduction of all ROs to get a single noisy bit
    assign entropy_raw = ^ro_bits;

    // ------------------------------------------------------------------------
    // 2) Synchronize entropy_raw into clk domain (two flip-flops)
    // ------------------------------------------------------------------------
    reg e_meta;
    reg e_sync;

    always @(posedge clk) begin
        if (rst) begin
            e_meta <= 1'b0;
            e_sync <= 1'b0;
        end else begin
            e_meta <= entropy_raw; // first stage
            e_sync <= e_meta;      // second stage
        end
    end

    // ------------------------------------------------------------------------
    // 3) Von Neumann debiaser
    //
    //   Take bits in pairs (b0, b1):
    //     01 -> output 0
    //     10 -> output 1
    //     00, 11 -> discard
    //
    //   We just sample one bit per clock from e_sync and feed this logic.
    // ------------------------------------------------------------------------
    reg have_first;
    reg first_bit;

    always @(posedge clk) begin
        if (rst) begin
            have_first <= 1'b0;
            first_bit  <= 1'b0;
            rnd_bit    <= 1'b0;
            rnd_valid  <= 1'b0;
        end else begin
            // default: no new bit this cycle
            rnd_valid <= 1'b0;

            if (!have_first) begin
                // store first bit of the pair
                first_bit  <= e_sync;
                have_first <= 1'b1;
            end else begin
                // second bit of the pair arrives
                if (e_sync != first_bit) begin
                    // 01 or 10 -> valid output
                    rnd_bit   <= first_bit;  // output encodes the pair
                    rnd_valid <= 1'b1;
                end
                // in any case, pair is consumed
                have_first <= 1'b0;
            end
        end
    end

endmodule
