# RVC-WebUI-MacOS (Sequoia-ready fork)

A fork of [qingbo1011/RVC-WebUI-MacOS](https://github.com/qingbo1011/RVC-WebUI-MacOS) with macOS Sequoia fixes and English UI by default.

## What's fixed in this fork

- English UI by default - auto-detects system locale, falls back to en_US instead of hardcoded zh_CN
- Removed pyenv dependency - run.sh and run-realtime.sh use Homebrew Python 3.9 with configurable PYTHON_BIN
- Fixed fairseq / omegaconf conflict - aria2 python wrapper commented out, works with pip<24.1
- Tested on macOS Sequoia (Apple Silicon: M1/M2/M3/M4)

## Requirements

- macOS Sequoia (Apple Silicon)
- Homebrew

## Installation

    brew install ffmpeg python@3.9 aria2

    git clone https://github.com/ltillegal/rvc-macos-sequoia.git
    cd rvc-macos-sequoia

    /opt/homebrew/opt/python@3.9/bin/python3.9 -m venv .venv
    source .venv/bin/activate

    pip install pip==24.0
    pip install -r requirements.txt

    python infer-web.py

Open http://127.0.0.1:7865 in your browser.

## Real-time voice changer

    ./run-realtime.sh

## Models

- .pth files to assets/weights/
- .index files to assets/indices/

Avoid Cyrillic or Chinese characters in file paths - FFmpeg will crash.

## Troubleshooting

### fairseq / omegaconf dependency conflict

    pip install pip==24.0
    pip install -r requirements.txt

### venv does not exist

    /opt/homebrew/opt/python@3.9/bin/python3.9 -m venv .venv
    source .venv/bin/activate
    pip install pip==24.0
    pip install -r requirements.txt

### UI still shows Chinese

Check i18n/i18n.py - I18nAuto.__init__ should auto-detect locale and fall back to en_US.

## Updating from upstream

    git remote add upstream https://github.com/qingbo1011/RVC-WebUI-MacOS.git
    git fetch upstream
    git merge upstream/main

## Credits

- Original RVC-WebUI: RVC-Project/Retrieval-based-Voice-Conversion-WebUI
- macOS port: qingbo1011/RVC-WebUI-MacOS

## License

MIT
