#!/bin/sh

# ============================================
# RVC WebUI launcher
# For Mac Apple Silicon
# ============================================

# macOS-specific environment variables
if [ "$(uname)" = "Darwin" ]; then
  # PYTORCH_ENABLE_MPS_FALLBACK=1
  # When some PyTorch ops are unsupported on MPS,
  # automatically fall back to CPU to avoid crashes
  export PYTORCH_ENABLE_MPS_FALLBACK=1

  # PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
  # Disable MPS high watermark limit, allow more GPU memory,
  # prevents OOM on large models or long audio
  export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0

  # Set locale to English
  export LANG=en_US.UTF-8

  # 解决 faiss 与 PyTorch 的 OpenMP 库冲突问题
  # Both libs ship their own libomp.dylib - conflict causes segfault
  export KMP_DUPLICATE_LIB_OK=TRUE
  # Limit OpenMP threads to reduce conflict risk
  export OMP_NUM_THREADS=1

  echo "macOS 环境变量已设置 (MPS加速已启用, English UI)"
elif [ "$(uname)" != "Linux" ]; then
  echo "不支持的操作系统"
  exit 1
fi

# Check and activate virtual environment
if [ -d ".venv" ]; then
  echo "Activating virtual environment......"
  . .venv/bin/activate
else
  echo "Error: virtual environment .venv 不存在！"
  echo "Create it first:"
  echo "  ${PYTHON_BIN:-/opt/homebrew/opt/python@3.9/bin/python3.9} -m venv .venv"
  echo "  source .venv/bin/activate"
  echo "  pip install torch torchvision torchaudio"
  echo "  pip install -r requirements.txt"
  exit 1
fi

# Check if models exist, download if missing
if [ ! -f "assets/hubert/hubert_base.pt" ] || [ ! -f "assets/rmvpe/rmvpe.pt" ]; then
  echo "Downloading pretrained models......"
  chmod +x tools/dlmodels.sh
  ./tools/dlmodels.sh
  
  if [ $? -ne 0 ]; then
    echo "Model download failed！"
    exit 1
  fi
else
  echo "Pretrained models already exist, skipping download"
fi

# Start RVC WebUI
echo "Starting RVC WebUI......"
echo "Access URL: http://127.0.0.1:7865"
python infer-web.py

