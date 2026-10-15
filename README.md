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

Model files are placed according to `.env`:

- `.pth` files -> `weight_root` (default: `assets/weights/`)
- `.index` files -> `index_root` (default: `logs/`)
- external `.index` files -> `outside_index_root` (default: `assets/indices/`)

Note: the inference tab reads `.index` files from `index_root` (`logs/`),
not from `outside_index_root`. If you place an `.index` in `assets/indices/`,
it will not show up in the dropdown on the main tab.

Avoid Cyrillic or Chinese characters in file paths - FFmpeg will crash.

### Installing models from a ZIP

The inference tab has an **Install model from ZIP (.pth + .index)** panel.
Select a ZIP archive containing a `.pth` file (and, optionally, an `.index`
file) and click **Install**. The installer:

- extracts the archive into a temporary directory,
- copies any `.pth` file to `weight_root` (default: `assets/weights/`),
- copies any `.index` file to `index_root` (default: `logs/`),
- refreshes the model and index dropdowns automatically.

Files are written atomically (temp file + rename), so an interrupted
install will not leave a corrupted `.pth` or `.index`.

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
