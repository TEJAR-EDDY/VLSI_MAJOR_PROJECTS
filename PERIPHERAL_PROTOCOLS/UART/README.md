
# 📡 UART Protocol Design & Verification (Verilog HDL)

## 📌 Project Overview

This project implements and verifies the **Universal Asynchronous Receiver/Transmitter (UART)** protocol using **Verilog HDL**.
UART is one of the most widely used **serial communication protocols** in embedded systems, enabling full-duplex data exchange between devices over just **TX (transmit)** and **RX (receive)** lines.

The design includes **UART Transmitter, Receiver, and Baud Rate Generator**, verified with a **self-checking testbench**.
This project is part of my **self-learning journey in VLSI Design & Verification**, focusing on communication protocols.

---

## 🎯 Key Features

* ✅ Implements **UART TX, RX, Baud Rate Generator**
* ✅ Supports configurable **baud rates** (default: 115200, CLK=50 MHz)
* ✅ Handles **start bit, data bits, parity, stop bit**
* ✅ Full-duplex **simultaneous TX/RX** operation
* ✅ Verification with multiple testcases:

  * Transmit only
  * Receive only
  * Full-duplex transfer
  * Error injection (parity, framing errors)
* ✅ Waveform outputs for each test scenario

---

## 🛠️ Technical Details

### 🔑 FSM (Transmitter)

* Idle → Start Bit → Data Shift → Parity (optional) → Stop Bit → Idle

### 🔑 FSM (Receiver)

* Idle → Start Detection → Data Sampling → Parity Check → Stop Detection → Idle

### 📐 Parameters

* **Data Width:** 8 bits
* **Baud Rate:** Configurable (115200 default)
* **Clock:** 50 MHz system clock

---

## 📂 Project Structure

```
📁 UART-Protocol
📁 RTL_Design/          # RTL code in Verilog (FSM-based controller)
📁 Test_Bench/          # Testbench code (stimulus, monitors, assertions)
📁 Simulation_Results/  # VCD waveforms, logs, coverage reports
📁 Reports_Final_docs/  # Project documentation, design report, synthesis results

```

---

## ▶️ How to Run (Icarus Verilog + GTKWave)

### 1️⃣ Compile the design and testbench

```bash
iverilog -o uart_tb.vvp RTL_Design/uart_tx.v RTL_Design/uart_rx.v RTL_Design/baud_gen.v RTL_Design/uart_top.v Test_Bench/uart_tb.v
```

### 2️⃣ Run simulation

```bash
vvp uart_tb.vvp
```

### 3️⃣ Open waveform in GTKWave

```bash
gtkwave uart_wave.vcd
```

---

## 📊 Verification Scenarios

| Test Case              | Expected Result         | Status |
| ---------------------- | ----------------------- | ------ |
| TX only                | Correct serial bits ✅   | PASS   |
| RX only                | Correct parallel data ✅ | PASS   |
| Full-Duplex TX + RX    | Data exchanged ✅        | PASS   |
| Parity Error Injection | Error flag raised ✅     | PASS   |
| Framing Error          | Error flag raised ✅     | PASS   |

---

## 📸 Example Waveforms

* https://github.com/TEJAR-EDDY/VLSI_MAJOR_PROJECTS/tree/main/PERIPHERAL_PROTOCOLS/UART/Simulation_Results
---

## 📚 References

1. [UART Protocol Basics – SparkFun](https://learn.sparkfun.com/tutorials/serial-communication)
2. [Icarus Verilog](http://iverilog.icarus.com/)
3. [GTKWave](http://gtkwave.sourceforge.net/)
4. [IEEE 1800-2023 SystemVerilog Standard](https://ieeexplore.ieee.org/document/10115428)

---

## 🚀 Future Enhancements

* Add **FIFO buffer** for TX/RX
* Implement **9-bit data transfer support**
* Add **SystemVerilog Assertions (SVA)** for protocol checks
* Extend verification using **UVM**
* FPGA implementation with real **USB-to-UART module**

---

✨ *This project is part of my self-learning journey in Digital Design & Verification, building strong protocol-level fundamentals.*

---

