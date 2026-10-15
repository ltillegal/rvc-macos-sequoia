#!/bin/sh

# ============================================
# RVC realtime voice changer launcher
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
  echo "Run ./run.sh first"
  exit 1
fi

# Check and install FreeSimpleGUI dependency
if ! python -c "import FreeSimpleGUI" 2>/dev/null; then
  echo "Installing FreeSimpleGUI..."
  pip install FreeSimpleGUI
  if [ $? -ne 0 ]; then
    echo "FreeSimpleGUI install failed！"
    exit 1
  fi
fi

# Check if models exist
if [ ! -f "assets/hubert/hubert_base.pt" ] || [ ! -f "assets/rmvpe/rmvpe.pt" ]; then
  echo "Error: pretrained models missing！"
  echo "Run ./run.sh first to download models"
  exit 1
fi

# Start realtime GUI
echo "Starting RVC realtime GUI......"
echo "Note: prepare your .pth 模型文件和 .index 索引文件"
python gui_v1.py
