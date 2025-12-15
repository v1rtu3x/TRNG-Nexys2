module top_trng_uart (
    input  wire clk_50mhz,   // board clock
    input  wire rst_n,       // active-low reset button/switch
    output wire uart_tx      // goes to Nexys 2 UART-TX pin
);
    wire rst = ~rst_n;

    // ---------------- TRNG core ----------------
    wire       rnd_bit;
    wire       rnd_valid;
    wire [7:0] rnd_byte;
    wire       byte_ready;

    // Entropy sampler: ring oscillators + debiasing
    entropy_sampler #(
        .NUM_RO (8),
        .STAGES(5)
    ) u_entropy (
        .clk      (clk_50mhz),
        .rst      (rst),
        .enable   (1'b1),
        .rnd_bit  (rnd_bit),
        .rnd_valid(rnd_valid)
    );

    // Byte packer: 8 bits -> 1 byte
    trng_byte_packer u_packer (
        .clk       (clk_50mhz),
        .rst       (rst),
        .rnd_bit   (rnd_bit),
        .rnd_valid (rnd_valid),
        .byte_out  (rnd_byte),
        .byte_ready(byte_ready)
    );

    // ---------------- UART TX ----------------
    wire       tx_busy;
    reg        tx_start;
    reg [7:0]  tx_data;

    // Handshake: whenever we have a new random byte AND UART is idle, send it
    always @(posedge clk_50mhz) begin
        if (rst) begin
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
        end else begin
            tx_start <= 1'b0;  // default: no start pulse

            if (byte_ready && !tx_busy) begin
                tx_data  <= rnd_byte;
                tx_start <= 1'b1;  // 1-cycle start pulse
            end
        end
    end

    uart_tx #(
        .CLK_FREQ (50_000_000),
        .BAUD_RATE(115200)
    ) u_uart_tx (
        .clk    (clk_50mhz),
        .rst    (rst),
        .data_in(tx_data),
        .start  (tx_start),
        .tx     (uart_tx),
        .busy   (tx_busy)
    );

endmodule
