// ---------------------------------------------------------------------
// Simple UART transmitter
//  - 8 data bits, no parity, 1 stop bit (8-N-1)
//  - LSB first
// ---------------------------------------------------------------------
module uart_tx #(
    parameter integer CLK_FREQ  = 50_000_000,  // Hz
    parameter integer BAUD_RATE = 115200       // bits per second
)(
    input  wire       clk,
    input  wire       rst,      // synchronous reset, active high

    input  wire [7:0] data_in,  // byte to send
    input  wire       start,    // pulse 1 clk to start sending
    output reg        tx,       // UART TX line
    output reg        busy      // 1 while sending a frame
);
    // Baud rate divider
    localparam integer BAUD_DIV = CLK_FREQ / BAUD_RATE;

    reg [$clog2(BAUD_DIV)-1:0] baud_cnt;
    reg [3:0]                  bit_idx;    // 0..9 (1 start + 8 data + 1 stop)
    reg [9:0]                  shift_reg;  // {stop, data[7:0], start}

    always @(posedge clk) begin
        if (rst) begin
            baud_cnt  <= 0;
            bit_idx   <= 0;
            shift_reg <= 10'b1111111111;
            tx        <= 1'b1;  // idle high
            busy      <= 1'b0;
        end else begin
            if (!busy) begin
                // Idle state: wait for start
                tx <= 1'b1; // keep line high
                if (start) begin
                    // Frame: start(0), data, stop(1)
                    shift_reg <= {1'b1, data_in, 1'b0}; // LSB is start bit
                    baud_cnt  <= 0;
                    bit_idx   <= 0;
                    busy      <= 1'b1;
                end
            end else begin
                // Busy: sending frame
                if (baud_cnt == BAUD_DIV-1) begin
                    baud_cnt <= 0;

                    // Output current bit
                    tx <= shift_reg[0];

                    // Shift right, shifting in 1's (stop-bit level) at MSB
                    shift_reg <= {1'b1, shift_reg[9:1]};

                    // Move to next bit
                    if (bit_idx == 4'd9) begin
                        // Done sending 10 bits
                        busy <= 1'b0;
                    end else begin
                        bit_idx <= bit_idx + 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end
        end
    end

endmodule
