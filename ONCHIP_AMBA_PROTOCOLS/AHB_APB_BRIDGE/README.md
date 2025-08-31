
# 🔗 AHB to APB Bridge Protocol Design & Verification (Verilog HDL)

## 📌 Project Overview

This project implements and verifies an **AHB-to-APB Bridge** in **Verilog HDL**.
In an SoC, the **AMBA AHB** bus provides high-performance pipelined communication, while the **APB** bus offers simple, low-power peripheral access.
The **bridge** acts as an interface, converting AHB transactions into APB-compatible transfers.

This project includes **RTL design, FSM-based control, and verification testbenches**.
It is part of my **self-learning VLSI projects** to enhance skills in **AMBA protocol integration**.

---

## 🎯 Key Features

* ✅ Converts **AHB (high-speed pipelined)** to **APB (low-power, simple)** transfers
* ✅ Supports **read & write transactions**
* ✅ Handles **wait states, PSLVERR (error response)**
* ✅ Implements **FSM-based control for transfer sequencing**
* ✅ Testbench covers **write, read, wait states, and error injection**
* ✅ Generates **VCD waveforms** for transaction analysis

---

## 🛠️ Technical Details

### 🔑 FSM States (Bridge Controller)

* **IDLE** → **SETUP** → **ENABLE** → **TRANSFER COMPLETE**

### 📐 Parameters

* Address: 32-bit
* Data: 32-bit
* Supports **PREADY, PSLVERR, PPROT, PSEL** signals

---

## 📂 Project Structure

```
📁 AHB_APB _BRIDGE -Protocol
📁 RTL_Design/          # RTL code in Verilog (FSM-based controller)
📁 Test_Bench/          # Testbench code (stimulus, monitors, assertions)
📁 Simulation_Results/  # VCD waveforms, logs, coverage reports
📁 Reports_Final_docs/  # Project documentation, design report, synthesis results
```

---

## ▶️ How to Run (Icarus Verilog + GTKWave)

### 1️⃣ Compile the design and testbench

```bash
iverilog -o ahb_apb_tb.vvp RTL_Design/ahb_apb_bridge.v RTL_Design/ahb_master_stub.v RTL_Design/apb_slave_stub.v Test_Bench/ahb_apb_tb.v
```

### 2️⃣ Run simulation

```bash
vvp ahb_apb_tb.vvp
```

### 3️⃣ Open waveform in GTKWave

```bash
gtkwave ahb_apb_wave.vcd
```

---

## 📊 Verification Scenarios

| Test Case                 | Expected Result         | Status |
| ------------------------- | ----------------------- | ------ |
| AHB Write → APB Write     | Correct data transfer ✅ | PASS   |
| AHB Read → APB Read       | Correct data return ✅   | PASS   |
| Wait State Handling       | PREADY extension ✅      | PASS   |
| Error Injection (PSLVERR) | Error flagged ✅         | PASS   |

---

## 📸 Example Waveforms

https://github.com/TEJAR-EDDY/VLSI_MAJOR_PROJECTS/tree/main/ONCHIP_AMBA_PROTOCOLS/AHB_APB_BRIDGE/Simulation_Results

---

## 📚 References

1. [ARM AMBA Specification](https://developer.arm.com/architectures/system-architectures/amba)
2. [Icarus Verilog](http://iverilog.icarus.com/)
3. [GTKWave](http://gtkwave.sourceforge.net/)

---

## 🚀 Future Enhancements

* Add support for **multi-slave APB decoding**
* Implement **burst transfers via bridge**
* Add **SystemVerilog Assertions (SVA)** for protocol compliance
* Extend verification using **UVM methodology**
* Synthesize and test on **FPGA with real peripherals**

---

✨ *This project is part of my self-learning journey to strengthen fundamentals in AMBA bus protocols and SoC integration.*

---

