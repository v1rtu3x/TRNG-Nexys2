module trng_byte_packer (
    input  wire       clk,
    input  wire       rst,
    input  wire       rnd_bit,
    input  wire       rnd_valid,

    output reg  [7:0] byte_out,
    output reg        byte_ready
);

    reg [2:0] bit_cnt;

    always @(posedge clk) begin
        if (rst) begin
            bit_cnt    <= 3'd0;
            byte_out   <= 8'd0;
            byte_ready <= 1'b0;
        end else begin
            byte_ready <= 1'b0; // default

            if (rnd_valid) begin
                // Shift in new bit (LSB-first here; you can reverse if you want)
                byte_out <= {byte_out[6:0], rnd_bit};

                if (bit_cnt == 3'd7) begin
                    bit_cnt    <= 3'd0;
                    byte_ready <= 1'b1;   // we now have 8 bits
                end else begin
                    bit_cnt <= bit_cnt + 3'd1;
                end
            end
        end
    end

endmodule
