module ring_osc_bank #(
    parameter integer NUM_RO  = 8,
    parameter integer STAGES = 5   // must be odd
)(
    input  wire                    enable,
    output wire [NUM_RO-1:0]       ro_out
);

    genvar k;
    generate
        for (k = 0; k < NUM_RO; k = k + 1) begin : gen_ros
            ring_oscillator #(
                .STAGES(STAGES)
            ) u_ro (
                .enable(enable),
                .out   (ro_out[k])
            );
        end
    endgenerate

endmodule