
# ⚡ SPI Protocol Design & Verification (Verilog HDL)

## 📌 Project Overview

This project implements and verifies the **Serial Peripheral Interface (SPI) protocol** using **Verilog HDL**.
SPI is a high-speed, full-duplex communication protocol widely used in **embedded systems, sensors, and microcontrollers**.

The design covers both **Master** and **Slave** modules, an **FSM-based controller**, and a **testbench** with functional verification.
This work is part of my **self-learning journey in VLSI Design & Verification** to build strong fundamentals in digital protocol design.

---

## 🎯 Key Features

* ✅ Supports all **4 SPI modes** (Mode 0–3: CPOL & CPHA configurable)
* ✅ Implements **Master + Multi-Slave** architecture
* ✅ Full-duplex data transfer (MOSI/MISO)
* ✅ Handles **chip select (CS)** for slave selection
* ✅ FSM-based **slave design** with edge-triggered data sampling
* ✅ Includes **testbench** with full-duplex scenarios
* ✅ Generates **VCD waveform outputs** for analysis in GTKWave

---

## 🛠️ Technical Details

### 🔑 FSM Design (Slave)

* **Idle** → **CS Active** → **Shift Data** → **Transfer Complete**

### 📐 Parameters

* Data Width: **8 bits**
* Configurable **Clock Polarity (CPOL)** and **Clock Phase (CPHA)**
* Supports **multiple slaves with independent chip select signals**

---

## 📂 Project Structure

```
📁 SPI-Protocol
📁 RTL_Design/          # RTL code in Verilog (FSM-based controller)
📁 Test_Bench/          # Testbench code (stimulus, monitors, assertions)
📁 Simulation_Results/  # VCD waveforms, logs, coverage reports
📁 Reports_Final_docs/  # Project documentation, design report, synthesis results

```

---

## ▶️ How to Run (Icarus Verilog + GTKWave)

### 1️⃣ Compile the design and testbench

```bash
iverilog -o spi_tb.vvp RTL_Design/spi_master.v RTL_Design/spi_slave.v RTL_Design/spi_top.v Test_Bench/spi_tb.v
```

### 2️⃣ Run simulation

```bash
vvp spi_tb.vvp
```

### 3️⃣ Open waveform in GTKWave

```bash
gtkwave spi_wave.vcd
```

---

## 📊 Verification Scenarios

| Test Case                        | Expected Result                 | Status |
| -------------------------------- | ------------------------------- | ------ |
| Mode 0 Transfer (CPOL=0, CPHA=0) | Correct shift on rising edge ✅  | PASS   |
| Mode 3 Transfer (CPOL=1, CPHA=1) | Correct shift on falling edge ✅ | PASS   |
| Multi-Slave Communication        | Correct CS handling ✅           | PASS   |
| Full-Duplex Operation            | MOSI/MISO exchange ✅            | PASS   |
| Invalid CS                       | No transfer ✅                   | PASS   |

---

## 📸 Example Waveforms

*https://github.com/TEJAR-EDDY/VLSI_MAJOR_PROJECTS/tree/main/PERIPHERAL_PROTOCOLS/SPI/Simulation_Results*

---

## 📚 References

1. [SPI Bus Specification – Motorola/NXP](https://www.nxp.com/docs/en/application-note/AN4255.pdf)
2. [Icarus Verilog](http://iverilog.icarus.com/)
3. [GTKWave](http://gtkwave.sourceforge.net/)
4. [Research on SPI Verification](https://arxiv.org/abs/2404.10375)

---

## 🚀 Future Enhancements

* Add **parameterized data width (16/32-bit)**
* Extend verification with **SystemVerilog & UVM**
* Apply **functional coverage + assertions**
* Prototype on FPGA with **real SPI peripherals (e.g., ADC, EEPROM)**
---

✨ *This project is a self-learning mini project to build confidence in digital protocol design and verification.*

---


