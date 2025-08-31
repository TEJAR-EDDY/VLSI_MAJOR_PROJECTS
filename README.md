
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
````

2. **Navigate to Any Project Folder**

   ```bash
   cd ONCHIP_AMBA_PROTOCOLS/AHB
   ```

3. **Compile the Design and Testbench**

   ```bash
   iverilog -o sim_out design.v testbench.v
   ```

4. **Run the Simulation**

   ```bash
   vvp sim_out
   ```

5. **View the Waveform**

   ```bash
   gtkwave dump.vcd
   ```

---

## 📖 Learning Outcomes

Through these projects, I gained hands-on experience in:

* RTL design and Verilog HDL coding
* On-chip communication protocols (AHB, APB, AXI)
* Peripheral protocol implementation (I2C, SPI, UART)
* Testbench development and simulation
* Verification of complex digital systems
* Debugging and waveform analysis with GTKWave

---

## 🌟 About

This repository represents my **major VLSI projects** focused on **SoC-level communication protocols**.
It demonstrates the practical application of **digital design, verification, and protocol-based RTL implementation** in Verilog HDL.

```
