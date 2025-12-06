module ring_oscillator #(
    parameter integer STAGES = 5  // must be odd and >= 3
)(
    input  wire enable,
    output wire out
);
    // Internal nodes of the inverter chain
    // KEEP / DONT_TOUCH so synthesis doesn't remove or collapse the loop
    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *)
    wire [STAGES-1:0] n;

    // First stage: feedback from the last stage, gated by enable
    assign n[0] = enable ? ~n[STAGES-1] : 1'b0;

    // Remaining inverters in the chain
    genvar i;
    generate
        for (i = 1; i < STAGES; i = i + 1) begin : gen_inverters
            assign n[i] = ~n[i-1];
        end
    endgenerate

    // Output of the ring
    assign out = n[STAGES-1];

endmodule