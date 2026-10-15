<div align="center">

<h1>RVC-WebUI-MacOS</h1>
<h3>An Optimized Distribution of Retrieval-based Voice Conversion WebUI for macOS</h3>

[![Platform](https://img.shields.io/badge/Platform-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/qingbo1011/RVC-WebUI-MacOS)
[![Architecture](https://img.shields.io/badge/Arch-Apple_Silicon-orange?style=for-the-badge)](https://github.com/qingbo1011/RVC-WebUI-MacOS)
[![Licence](https://img.shields.io/badge/LICENSE-MIT-green.svg?style=for-the-badge)](https://github.com/qingbo1011/RVC-WebUI-MacOS/blob/main/LICENSE)

[**Mac Setup Guide**](#-macos-quick-start) | [**Original Project**](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) | [**Changelog**](./docs/en/Changelog_EN.md)

</div>

---

## 🌟 Why this Fork?

This repository is a specialized fork of the [RVC-WebUI](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI) project, specifically optimized for **macOS (Apple Silicon M1/M2/M3 and Intel)**. It solves common environment issues, leverages hardware acceleration, and ensures a seamless "out-of-the-box" experience for Mac users.

### ✨ Key macOS Optimizations
- 🚀 **Hardware Acceleration**: Enabled `CoreMLExecutionProvider` for UVR5 (5-10x faster vocal separation).
- 🧠 **MPS Integration**: Configured PyTorch to use Metal Performance Shaders for GPU-accelerated inference.
- 🛠️ **Environment Fixes**:
    - Fixed Tcl/Tk version conflicts for the Real-time GUI.
    - Resolved OpenMP library conflicts (Segfault fix).
    - Patched Gradio timeout issues for long audio processing (>5s).
- 🐍 **Modern Python Support**: Fully compatible with Python 3.9+ and PyTorch 2.6 (fixed `weights_only` loading errors).
- 📦 **One-Click Scripts**: Enhanced `run.sh` and added `run-realtime.sh` for easy startup.

---

## 🚀 macOS Quick Start

### 1. Prerequisites
Ensure you have [Homebrew](https://brew.sh/) installed. Then, install the necessary dependencies:

```bash
brew install ffmpeg python@3.9 aria2
```

### 2. Installation
Clone this repository and run the automated setup script:

```bash
git clone https://github.com/qingbo1011/RVC-WebUI-MacOS.git
cd RVC-WebUI-MacOS
sh ./run.sh
```
*The script will automatically create a virtual environment, install dependencies, and download required pre-trained models.*

### 3. Running the WebUI (Training & Inference)
```bash
./run.sh
```
Access at: **http://127.0.0.1:7865**

### 4. Running the Real-time GUI (Voice Conversion)
```bash
./run-realtime.sh
```
*Note: Ensure you have your `.pth` and `.index` files ready in the `assets/weights` and `assets/indices` folders.*

---

## 🔧 Development Environment Setup

| Component | Configuration |
|-----------|---------------|
| **Python** | 3.9 (Homebrew recommended) |
| **Venv** | Located in `.venv/` |
| **GUI Framework** | FreeSimpleGUI (Patched for Mac Tcl/Tk 8.6) |

### Critical Environment Variables
These are automatically handled by our startup scripts:
- `PYTORCH_ENABLE_MPS_FALLBACK=1`: Ensures stability if an operation isn't implemented in MPS.
- `KMP_DUPLICATE_LIB_OK=TRUE`: Prevents crashes caused by duplicate OpenMP runtimes.
- `CoreMLExecutionProvider`: Used in `mdxnet.py` to leverage Mac's Neural Engine.

---

## 📂 Model Management

To use your models, place them in the following directories:

- **Model Files (`.pth`)**: `/assets/weights/`
- **Index Files (`.index`)**: `/assets/indices/` (or `/logs/`)

After placing the files, click **"Refresh voice list and index path"** in the WebUI.

---

## ⚠️ Known Issues
1. **Chinese Paths**: Avoid using Chinese characters in file paths for input audio, as it may cause FFmpeg issues.
2. **MPS Warnings**: You might see "MPS fallback" warnings in the terminal; these are normal and don't affect output quality.

---

## 🤝 Contribution Guidelines

Contributions to further optimize RVC for macOS are welcome! 
1. **Bug Reports**: Open an issue describing the macOS version and chip (M1/M2/Intel) you are using.
2. **Pull Requests**: For performance optimizations, please include a brief benchmark (e.g., "Inference time reduced by 20%").
3. **Localization**: Help us improve the English/Chinese documentation.

---

## ❤️ Credits
- [RVC-Project](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI): The original amazing voice conversion framework.
- [Vocal pitch extraction: RMVPE](https://github.com/Dream-High/RMVPE)
- [Ultimate Vocal Remover](https://github.com/Anjok07/ultimatevocalremovergui)

---
*Maintained by [qingbo1011](https://github.com/qingbo1011)*
