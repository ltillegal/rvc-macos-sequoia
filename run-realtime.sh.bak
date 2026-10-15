#!/bin/sh

# ============================================
# RVC 实时变声 GUI 启动脚本
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
  echo "请先运行 ./run.sh 配置环境"
  exit 1
fi

# 检查并安装 FreeSimpleGUI 依赖
if ! python -c "import FreeSimpleGUI" 2>/dev/null; then
  echo "正在安装实时变声GUI所需依赖 FreeSimpleGUI..."
  pip install FreeSimpleGUI
  if [ $? -ne 0 ]; then
    echo "FreeSimpleGUI 安装失败！"
    exit 1
  fi
fi

# 检查模型文件是否存在
if [ ! -f "assets/hubert/hubert_base.pt" ] || [ ! -f "assets/rmvpe/rmvpe.pt" ]; then
  echo "错误: 预训练模型不存在！"
  echo "请先运行 ./run.sh 下载模型"
  exit 1
fi

# 启动实时变声 GUI
echo "正在启动 RVC 实时变声 GUI..."
echo "提示: 使用前请先准备好 .pth 模型文件和 .index 索引文件"
python gui_v1.py
