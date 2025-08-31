
# VLSI Major Projects in Verilog HDL 🚀  

This repository contains my self-developed **VLSI major projects** implemented in **Verilog HDL**.  
I created these projects as part of my **advanced learning journey** to strengthen RTL design, verification, and on-chip communication protocol understanding.  

Each project includes Verilog design files, testbenches, and simulation support.

---

## 📂 Project Structure

### 🔹 On-Chip AMBA Protocols
- **[AHB](./ONCHIP_AMBA_PROTOCOLS/AHB)**  
- **[APB](./ONCHIP_AMBA_PROTOCOLS/APB)**  
- **[AXI](./ONCHIP_AMBA_PROTOCOLS/AXI)**  
- **[AHB–APB Bridge](./ONCHIP_AMBA_PROTOCOLS/AHB_APB_BRIDGE)**  

### 🔹 Peripheral Protocols
- **[I2C](./PERIPHERAL_PROTOCOLS/I2C)**  
- **[SPI](./PERIPHERAL_PROTOCOLS/SPI)**  
- **[UART](./PERIPHERAL_PROTOCOLS/UART)**  

---

## 🛠️ Tools Used
- **Icarus Verilog** → [Download Here](https://steveicarus.github.io/iverilog/)  
- **GTKWave** (for waveform viewing) → [Download Here](http://gtkwave.sourceforge.net/)  

---

## ▶️ How to Run the Projects

1. **Clone this Repository**
   ```bash
   git clone https://github.com/TEJAR-EDDY/VLSI_MAJOR_PROJECTS.git
   cd VLSI_MAJOR_PROJECTS


2. **Navigate to a specific project folder**

   ```bash
   cd ONCHIP_AMBA_PROTOCOLS/AHB
   ```

3. **Compile the design and testbench**

   ```bash
   iverilog -o sim_out design.v testbench.v
   ```

4. **Run the simulation**

   ```bash
   vvp sim_out
   ```

5. **View waveforms in GTKWave**

   ```bash
   gtkwave dump.vcd
   ```

---

## 📖 Key Learning Outcomes

* Gained hands-on skills in **RTL design using Verilog HDL**
* Implemented and verified **on-chip bus protocols (AHB, APB, AXI)**
* Designed and tested **peripheral protocols (I2C, SPI, UART)**
* Built **self-contained testbenches** for verification
* Analyzed and debugged results using **GTKWave**
* Strengthened knowledge in **protocol-based SoC design**

---

## 🌟 About

This repository represents my **major-level VLSI projects**, developed independently to build **strong fundamentals in digital design, verification, and SoC protocols**.
It is a continuation of my earlier [Mini Projects Repository](https://github.com/TEJAR-EDDY/VLSI_MINI_PROJECTS), showcasing my step-by-step growth in VLSI design and verification.

---

💡 *All projects are designed and verified from scratch to enhance my learning and practical expertise in the VLSI field.*

