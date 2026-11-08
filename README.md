# RVC-WebUI-MacOS (Sequoia-ready fork)

A fork of [qingbo1011/RVC-WebUI-MacOS](https://github.com/qingbo1011/RVC-WebUI-MacOS) with macOS Sequoia fixes and English UI by default.

<p align="center">
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

Support the project / Поддержать проект: [PayPal](https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD)

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

## Training a model in Google Colab / Обучение модели в Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ltillegal/rvc-macos-sequoia/blob/main/colab/train-rvc-colab.ipynb)

Train an RVC v2 voice model on a free Colab GPU, then install the result here with the ZIP installer.

Обучите голосовую модель RVC v2 на бесплатном GPU в Colab и установите результат здесь через ZIP-установщик.

### Dataset / Датасет

- 10–30 minutes of clean speech from one speaker is the practical sweet spot. 4 minutes works, but the timbre will be less stable.
- No music, echo, second voice, or clipping. Even level. WAV / MP3 / FLAC / M4A / OGG are accepted.
- Do not over-denoise: aggressive cleanup is learned by the model and shows up as a metallic voice.
- 10–30 минут чистой речи одного человека — оптимум. 4 минуты тоже обучатся, но тембр будет менее стабильным. Без музыки, эха, второго голоса и клиппинга. Агрессивный денойз вредит: модель выучит «металл».

Put the files here / положите файлы сюда:

    MyDrive/rvc/Roman_lt/dataset/

Results are written to / результаты появятся в:

    MyDrive/rvc/Roman_lt/out/

### What the notebook does / Что делает ноутбук

1. Creates a Python 3.11 environment with `uv`, installs PyTorch 2.4.1 (CUDA 12.1), `fairseq` (C++17 build), `faiss`, `rmvpe` dependencies.
2. Clones this repository and downloads `hubert_base.pt`, `rmvpe.pt`, and the 48 kHz F0 pretrained weights.
3. Preprocesses the dataset: high-pass, slice into 3.7 s windows, normalize.
4. Extracts F0 with RMVPE and HuBERT features (768 for v2).
5. Trains `v2 48k f0 1` with 200 epochs, saving an inference-ready `.pth` every 25 epochs.
6. Builds the faiss `.index` and copies `.pth` + `.index` to your Drive.

1. Создаёт окружение Python 3.11, ставит PyTorch, `fairseq` (сборка C++17), `faiss` и зависимости RMVPE.
2. Клонирует репозиторий и скачивает `hubert_base.pt`, `rmvpe.pt` и претрейн 48 кГц с F0.
3. Готовит датасет: high-pass, нарезка на окна 3.7 с, нормализация.
4. Извлекает F0 (RMVPE) и признаки HuBERT (768 для v2).
5. Обучает `v2 48k f0 1`, 200 эпох, готовый `.pth` каждые 25 эпох.
6. Строит индекс faiss и складывает `.pth` + `.index` на Drive.

### Settings / Настройки

| Setting | Default | Meaning |
| --- | --- | --- |
| `SAMPLE_RATE` | `48k` | 48 kHz v2 is recommended; 40k/32k fall back to v1 / рекомендуется 48k |
| `TOTAL_EPOCHS` | `200` | 10–30 min of audio; use 100 for < 5 min |
| `SAVE_EVERY` | `25` | also writes a ready-to-use model each 25 epochs |
| `BATCH_SIZE` | `8` | lower to 6 or 4 on `CUDA out of memory` |

### Time and resume / Время и продолжение

- Preprocessing: ~10–20 min. Training: ~40–90 min for 200 epochs on a free T4.
- Checkpoints are mirrored to `out/checkpoints/` every 5 minutes.
- If Colab disconnects, reconnect and run the notebook from the top: preprocessing is redone and training resumes from the mirrored checkpoints (`G_*.pth` / `D_*.pth`).
- Подготовка ~10–20 мин, обучение ~40–90 мин на T4. Чекпоинты копируются на Drive каждые 5 минут. После обрыва запустите ноутбук заново — обучение продолжится с последнего чекпоинта.

### After training / После обучения

1. Download the `.pth` you like and the `.index` from `out/`.
2. Zip them together and install with **Install model from ZIP (.pth + .index)**, or copy the `.pth` to `assets/weights/` and the `.index` to `logs/`.
3. Inference for speech: F0 method `rmvpe`, pitch `0` (±12 for gender change), index rate `0.5–0.75`, protect `0.33`, RMS mix `0.25`.

Скачайте `.pth` и `.index` из `out/`, упакуйте в ZIP и установите через ZIP-установщик. Для речи: `rmvpe`, pitch `0`, index rate `0.5–0.75`, protect `0.33`, RMS mix `0.25`.

> **RVC and Seed-VC are different architectures.** An RVC `.pth` does not load in Seed-VC, and a Seed-VC checkpoint does not load here.
>
> **RVC и Seed-VC — разные архитектуры.** RVC-модель не открывается в Seed-VC, и наоборот.

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

## Support the project / Поддержать проект

If this fork saves you time, you can buy me a coffee / если форк сэкономил вам время:

<p>
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

PayPal: [0eskimo0@gmail.com](https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD)

## Credits

- Original RVC-WebUI: RVC-Project/Retrieval-based-Voice-Conversion-WebUI
- macOS port: qingbo1011/RVC-WebUI-MacOS

## License

MIT
