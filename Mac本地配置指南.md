# RVC 项目本地配置指南

> 本文档记录了在 **Mac M芯片 (Apple Silicon)** 上配置和运行 RVC 项目的完整过程。

---

## 🚀 极速启动

### 训练推理界面 (Web)

```bash
cd /Users/qingbo/Documents/RVC/Retrieval-based-Voice-Conversion-WebUI
./run.sh
```

访问地址：**http://127.0.0.1:7865**

### 实时变声界面 (桌面 GUI)

```bash
cd /Users/qingbo/Documents/RVC/Retrieval-based-Voice-Conversion-WebUI
./run-realtime.sh
```

> ⚠️ 使用实时变声前，需要先准备好 `.pth` 模型文件和 `.index` 索引文件

---

## 🔧 环境配置修改记录

### 1. Python 环境

| 项目 | 配置 |
|-----|------|
| Python 版本 | 3.9.22 (Homebrew) |
| 虚拟环境 | `.venv` |
| Tcl/Tk 版本 | 8.6 (用于实时变声 GUI) |

**原因**：pyenv 编译的 Python 默认链接旧版 Tcl/Tk 8.5，导致实时变声 GUI 崩溃。改用 Homebrew 的 Python 3.9 解决。

### 2. requirements.txt 修改

```diff
- aria2
+ # aria2 - 移除：Mac M芯片不支持该Python包，系统已安装aria2c命令行工具
```

### 3. i18n/i18n.py 修改 (中文界面)

将语言固定为简体中文，不依赖系统语言检测：

```python
# 原代码：自动检测系统语言
# language = locale.getdefaultlocale()[0]

# 修改后：固定使用简体中文
language = "zh_CN"
```

### 4. run.sh 改进

- ✅ 添加 `LANG=zh_CN.UTF-8` 环境变量
- ✅ 移除 Python 3.8 硬编码，改用虚拟环境中的 python
- ✅ 智能模型下载（仅在模型不存在时下载）
- ✅ 添加中文注释和友好输出

### 5. 新建 run-realtime.sh

创建实时变声 GUI 的启动脚本，包含：
- MPS 加速环境变量
- 中文语言设置
- 自动检测并安装 `FreeSimpleGUI` 依赖
- 模型文件检查

### 6. 额外安装的依赖

```bash
pip install FreeSimpleGUI  # 实时变声 GUI 框架
pip install sounddevice    # 音频设备访问
```

---

## 📝 环境变量说明

| 环境变量 | 作用 |
|---------|------|
| `PYTORCH_ENABLE_MPS_FALLBACK=1` | 当某些 PyTorch 操作在 MPS (Apple GPU) 上不支持时，自动回退到 CPU 执行，防止程序崩溃 |
| `PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0` | 禁用 GPU 内存高水位限制，允许 PyTorch 使用更多内存，避免处理大模型时内存不足 |
| `LANG=zh_CN.UTF-8` | 设置语言为简体中文 |

---

## 📁 关键文件路径

```
项目根目录
├── run.sh              # 训练推理界面启动脚本
├── run-realtime.sh     # 实时变声 GUI 启动脚本
├── .venv/              # Python 虚拟环境
├── assets/
│   ├── hubert/hubert_base.pt     # Hubert 模型
│   ├── rmvpe/rmvpe.pt            # RMVPE 音高提取模型
│   ├── pretrained/               # v1 预训练模型
│   ├── pretrained_v2/            # v2 预训练模型
│   └── uvr5_weights/             # UVR5 人声分离模型
└── i18n/i18n.py        # 语言配置 (已改为中文)
```

---

*配置日期：2026-01-17*
*更新日期：2026-01-20*

---

## 🔨 PyTorch 2.6+ 兼容性修复

PyTorch 2.6 版本更改了 `torch.load()` 的默认行为，`weights_only` 参数默认值从 `False` 改为 `True`，导致加载旧版模型时报错：

```
_pickle.UnpicklingError: Weights only load failed.
```

### 修改的文件

| 文件 | 修改说明 |
|-----|---------|
| `.venv/.../fairseq/checkpoint_utils.py:315` | 添加 `weights_only=False` 参数 |
| `infer/modules/vc/modules.py:103` | 音色模型加载添加 `weights_only=False` |
| `infer/lib/rmvpe.py:544` | RMVPE 模型加载添加 `weights_only=False` |

### 修改示例

```python
# 原代码
ckpt = torch.load(model_path, map_location="cpu")

# 修改后
ckpt = torch.load(model_path, map_location="cpu", weights_only=False)
```

---

## 🛠️ OpenMP 库冲突修复

faiss 库（用于索引搜索）和 PyTorch 各自自带了 OpenMP 运行时 (`libomp.dylib`)，同时运行会导致段错误 (Segmentation fault)。

### run.sh 新增环境变量

```bash
# 解决 faiss 与 PyTorch 的 OpenMP 库冲突问题
export KMP_DUPLICATE_LIB_OK=TRUE
# 限制 OpenMP 线程数，进一步减少冲突风险
export OMP_NUM_THREADS=1
```

| 环境变量 | 作用 |
|---------|------|
| `KMP_DUPLICATE_LIB_OK=TRUE` | 允许多个 OpenMP 运行时库共存，避免冲突检测导致的崩溃 |
| `OMP_NUM_THREADS=1` | 限制 OpenMP 线程数为1，从根本上避免多线程竞争 |

---

## 🕐 Gradio 长音频处理超时修复

### 问题现象

在 WebUI 中转换较长的音频（如 230 秒）时，前端显示 **Error**，但终端无报错信息。直接用 Python 命令行调用转换函数则正常成功。

### 根本原因

Gradio 3.34 的 queue 模式内部调用链如下：

```
浏览器 → WebSocket → Gradio Queue → httpx POST /api/predict → vc_single()
```

`httpx.AsyncClient` 的默认 **read 超时仅 5 秒**，而长音频处理需要 30-40 秒，导致内部请求被中断。后端推理实际上仍在运行并生成了临时文件（位于 `/private/var/folders/.../T/gradio/` 下），但结果无法传回前端。

### 修改文件

`infer-web.py`（在 `import gradio as gr` 之后添加 monkey-patch）：

```python
# 修复 Gradio queue 模式下长音频处理超时问题
# httpx 默认 read 超时仅 5 秒，长音频处理会被中断导致前端报 Error
import httpx
_original_async_client_init = httpx.AsyncClient.__init__
def _patched_async_client_init(self, *args, **kwargs):
    kwargs.setdefault("timeout", None)
    _original_async_client_init(self, *args, **kwargs)
httpx.AsyncClient.__init__ = _patched_async_client_init
```

> 💡 **设计说明**：使用 monkey-patch 而非直接修改 `.venv` 下的 Gradio 源码，避免 `pip install` 升级后修改丢失。

---

## 📂 模型和索引文件加载

### 模型文件 (.pth)

放置路径：`assets/weights/`

### 索引文件 (.index)

放置路径（二选一）：
- `assets/indices/` (推荐)
- `logs/`

### 刷新文件列表

放置文件后，在 WebUI 中点击 **"刷新音色列表和索引路径"** 按钮即可识别。

> ⚠️ **注意**：索引文件名不能包含 `trained` 字符串，否则会被自动排除。

---

## ⚠️ 已知问题

### 1. 中文路径不支持

**现象**：输入音频路径包含中文时，转换报错。

**原因**：`ffmpeg-python` 库通过 `subprocess` 调用 ffmpeg 命令行，中文路径在传递给子进程时可能未正确编码/解码为 UTF-8。

**解决方案**：将音频文件放在纯英文路径下，或重命名为英文文件名。

### 2. MPS 部分操作回退到 CPU

**现象**：日志中偶尔出现 MPS 回退警告。

**原因**：部分 PyTorch 操作在 Apple MPS 上尚未实现，自动回退到 CPU 执行。

**影响**：对整体性能影响较小，属于正常现象。

---

## ⚡ 性能优化记录 (M芯片专属)

### 1. UVR5 人声分离 CoreML 加速

**问题描述**：使用 `onnx_dereverb_By_FoxJoy` 模型进行人声分离/去混响时，处理速度极慢且 Mac 风扇狂转。
**原因**：源码中固定了 ONNX 的执行提供者 (Providers)，未包含 Apple 专属的 `CoreMLExecutionProvider`，导致模型被迫使用纯 CPU 运算，完全没有利用到 M 系列芯片的 GPU 和 NPU。

**修改文件**：`infer/modules/uvr5/mdxnet.py`
**修改位置**：`Predictor` 类初始化 (`__init__`) 中的 `ort.InferenceSession`
**修改内容**：在 `providers` 列表中加入 `"CoreMLExecutionProvider"`。

```python
# 原代码
        self.model = ort.InferenceSession(
            os.path.join(args.onnx, self.model_.target_name + ".onnx"),
            providers=[
                "CUDAExecutionProvider",
                "DmlExecutionProvider",
                "CPUExecutionProvider",
            ],
        )

# 修改后
        self.model = ort.InferenceSession(
            os.path.join(args.onnx, self.model_.target_name + ".onnx"),
            providers=[
                "CUDAExecutionProvider",
                "DmlExecutionProvider",
                "CoreMLExecutionProvider", # 新增：开启 Mac 硬件加速
                "CPUExecutionProvider",
            ],
        )
```

**效果**：处理速度提升显著（约 5-10 倍），同时大幅降低 CPU 占用和发热。运行终端会打印类似 `CoreMLExecutionProvider::GetCapability` 的黄色日志，表示加速已成功启用。