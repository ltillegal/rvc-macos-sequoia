#!/bin/sh

# ============================================
# RVC WebUI 启动脚本
# 适用于 Mac M芯片 (Apple Silicon)
# ============================================

# macOS 特定环境变量设置
if [ "$(uname)" = "Darwin" ]; then
  # PYTORCH_ENABLE_MPS_FALLBACK=1
  # 当某些PyTorch操作在MPS(Metal Performance Shaders)上不支持时，
  # 自动回退到CPU执行，避免程序崩溃
  export PYTORCH_ENABLE_MPS_FALLBACK=1

  # PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
  # 禁用MPS设备的内存高水位限制，允许PyTorch使用更多GPU内存，
  # 避免处理大模型或长音频时出现内存不足
  export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

  # 设置语言为简体中文
  export LANG=zh_CN.UTF-8

  # 解决 faiss 与 PyTorch 的 OpenMP 库冲突问题
  # 两个库各自自带 libomp.dylib，同时运行会导致段错误
  export KMP_DUPLICATE_LIB_OK=TRUE
  # 限制 OpenMP 线程数，进一步减少冲突风险
  export OMP_NUM_THREADS=1

  echo "macOS 环境变量已设置 (MPS加速已启用, 中文界面)"
elif [ "$(uname)" != "Linux" ]; then
  echo "不支持的操作系统"
  exit 1
fi

# 检查并激活虚拟环境
if [ -d ".venv" ]; then
  echo "正在激活虚拟环境..."
  . .venv/bin/activate
else
  echo "错误: 虚拟环境 .venv 不存在！"
  echo "请先运行以下命令创建虚拟环境："
  echo "  ${PYTHON_BIN:-/opt/homebrew/opt/python@3.9/bin/python3.9} -m venv .venv"
  echo "  source .venv/bin/activate"
  echo "  pip install torch torchvision torchaudio"
  echo "  pip install -r requirements.txt"
  exit 1
fi

# 检查模型文件是否存在，不存在则下载
if [ ! -f "assets/hubert/hubert_base.pt" ] || [ ! -f "assets/rmvpe/rmvpe.pt" ]; then
  echo "正在下载预训练模型..."
  chmod +x tools/dlmodels.sh
  ./tools/dlmodels.sh
  
  if [ $? -ne 0 ]; then
    echo "模型下载失败！"
    exit 1
  fi
else
  echo "预训练模型已存在，跳过下载"
fi

# 启动 RVC WebUI
echo "正在启动 RVC WebUI..."
echo "访问地址: http://127.0.0.1:7865"
python infer-web.py

