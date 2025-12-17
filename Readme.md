#  True Random Number Generator (TRNG) with UART Output

**Target FPGA:** Nexys 2 DDR (Spartan-3E)  
**Language:** Verilog HDL  
**Interface:** UART (USB-UART adapter)

---

##  Project Overview

This project implements a **hardware-based True Random Number Generator (TRNG)** on an FPGA.  
Randomness is extracted from **physical timing noise** using **ring oscillators**, processed with synchronization and debiasing, packed into bytes, and transmitted to a host PC via **UART**.

Unlike pseudo-random generators, this design derives entropy from **non-deterministic hardware effects**, making it suitable for **cryptographic and security-related applications**.

---

##  System Architecture

```
Ring Oscillators
↓
Entropy Sampler
(2-FF sync + Von Neumann debias)
↓
Byte Packer (8 bits → 1 byte)
↓
UART Transmitter (115200 baud)
↓
USB-UART → PC
```

## Project Structure

```
├── ring_osc.v # Single ring oscillator (entropy source)
├── mult_osc.v # Bank of ring oscillators
├── entropy_sampler.v # Sampling, synchronization, debiasing
├── trng_byte_packer.v # Packs random bits into bytes
├── uart_tx.v # UART transmitter (8-N-1)
├── top_trng_uart.v # Top-level system integration
├── tb_top_trng_uart.v # Full end-to-end testbench
├── trng_uart.xdc # FPGA constraints file
└── README.md # This file
```


##  Module Descriptions

### `ring_osc.v`
- Implements an **odd-length inverter loop**
- Oscillates due to propagation delay
- Protected with `KEEP` and `DONT_TOUCH` to prevent synthesis optimization

---

### `mult_osc.v`
- Instantiates multiple independent ring oscillators
- Outputs a vector of oscillator bits
- Improves entropy through diversity

---

### `entropy_sampler.v`
- XOR-reduces oscillator outputs
- Synchronizes asynchronous entropy to the system clock
- Applies **Von Neumann debiasing**
- Outputs:
  - `rnd_bit`
  - `rnd_valid`

---

### `trng_byte_packer.v`
- Collects 8 valid random bits
- Outputs a full byte
- Generates a `byte_ready` pulse

---

### `uart_tx.v`
- UART transmitter finite-state machine (FSM)
- Configuration:
  - **115200 baud**
  - **8 data bits**
  - **No parity**
  - **1 stop bit (8-N-1)**
- Provides a `busy` signal for flow control

---

### `top_trng_uart.v`
- Integrates all modules
- Handles reset and transmission flow control
- Sends random bytes over UART

---

## Simulation & Verification

**Testbench:** `tb_top_trng_uart.v`

Because ring oscillators do not simulate reliably in RTL:

- Entropy is **forced** using a testbench LFSR
- This mimics asynchronous hardware noise
- A UART receiver model reconstructs transmitted bytes
- Received bytes are compared against expected bytes

 **Zero mismatches confirm correct end-to-end operation**

---

##  Performance

### Entropy Generation (Ideal Case)
- Sampling clock: **50 MHz**
- Von Neumann output rate: **≈ 12.5 Mbit/s**

### UART Throughput
- Line rate: **115200 bits/s**
- Payload rate: **92,160 random bits/s**

 **System is UART-limited, not entropy-limited**

---

##  Hardware Setup

### Required Connections

| USB-UART Adapter | Nexys 2 DDR |
|------------------|-------------|
| RX               | PMOD JA1 (example) |
| GND              | GND |

⚠️ TX/RX **must be crossed**  
⚠️ **Do NOT connect VCC**

---

##  PC-Side Data Capture (Example)

```python
import serial

ser = serial.Serial("COM3", 115200)
while True:
    print(ser.read(16).hex())
```

## How to Build & Run

1. Add all .v files to your FPGA project
2. Set top_trng_uart as the top module
3. Add trng_uart.xdc
4. Synthesize and generate the bitstream
5. Program the FPGA
6. Open a serial terminal at 115200 baud
7. Observe the random data stream

## Limitations & Future Improvements

### Current Limitations

- No cryptographic whitening (hashing)
- UART limits throughput
- No online health tests

### Future Work

- Add SHA-based post-processing
- Implement NIST health tests
- Use faster interfaces (SPI / USB)
- Increase oscillator diversity

## Conclusion

This project demonstrates a complete, verified hardware TRNG implemented on FPGA, including:

Physical entropy extraction

Safe clock-domain handling

Bias removal

Byte-level data streaming

Simulation-proven correctness

The design is modular, extensible, and suitable for further research in hardware security.