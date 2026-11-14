# RVC-WebUI-MacOS (Sequoia-ready fork)

<p align="center">
  <a href="README.md"><img src="https://img.shields.io/badge/English-2ea44f?style=flat-square" alt="English"></a>
  <a href="README.ru.md"><img src="https://img.shields.io/badge/%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-6e7781?style=flat-square" alt="Русский"></a>
</p>

<p align="center">
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

A fork of [qingbo1011/RVC-WebUI-MacOS](https://github.com/qingbo1011/RVC-WebUI-MacOS) with macOS Sequoia fixes and English UI by default.

Russian version: [README.ru.md](README.ru.md)

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

## Training a model in Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ltillegal/rvc-macos-sequoia/blob/main/colab/train-rvc-colab.ipynb)

`colab/train-rvc-colab.ipynb` trains an **RVC v2, 48 kHz, F0-conditioned** voice model on a free Colab GPU and puts the finished `.pth` + `.index` back on your Google Drive. The result installs here with the ZIP installer. The notebook itself is bilingual (English / Russian).

### Dataset

- 10–30 minutes of clean speech from one speaker is the practical sweet spot. 4 minutes works, but the timbre will be less stable.
- No music, echo, second voice, or clipping. Even level. WAV / MP3 / FLAC / M4A / OGG are accepted.
- One long file is fine: the notebook converts it to mono 48 kHz and splits it into 10-minute parts with ffmpeg, then preprocessing slices those into 3.7 s windows.
- Do not over-denoise: aggressive cleanup is learned by the model and shows up as a metallic voice.

Put the files here:

    MyDrive/rvc/mymodel/dataset/

Results are written to:

    MyDrive/rvc/mymodel/out/

`mymodel` is only a default name: change it to anything you like (Latin, no spaces). It becomes the experiment folder and the prefix of the output `.pth`.

### What the notebook does

1. Creates a Python 3.11 environment with `uv`, installs PyTorch 2.4.1 (CUDA 12.1), `fairseq` (C++17 build), `faiss`, and the RMVPE dependencies.
2. Clones this repository and downloads `hubert_base.pt`, `rmvpe.pt`, and the 48 kHz F0 pretrained weights.
3. Normalizes the dataset with ffmpeg: mono 48 kHz, split into 10-minute parts (keeps RAM flat, so a multi-hour file cannot crash the runtime).
4. Preprocesses it: high-pass, slice into 3.7 s windows, normalize.
5. Extracts F0 with RMVPE and HuBERT features (768 for v2).
6. Trains `v2 48k f0 1` with 200 epochs, saving an inference-ready `.pth` every 25 epochs.
7. Builds the faiss `.index` and copies `.pth` + `.index` to your Drive.

### Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| `EXPERIMENT` | `mymodel` | name of the experiment / output files |
| `SAMPLE_RATE` | `48k` | 48 kHz v2 is recommended; 40k/32k fall back to v1 |
| `TOTAL_EPOCHS` | `200` | 10–30 min of audio; use 100 for < 5 min |
| `SAVE_EVERY` | `25` | also writes a ready-to-use model each 25 epochs |
| `BATCH_SIZE` | `8` | lower to 6 or 4 on `CUDA out of memory` |

### Time and resume

- Preprocessing: ~10–20 min. Training: ~40–90 min for 200 epochs on a free T4.
- Checkpoints are mirrored to `out/checkpoints/` every 5 minutes.
- If Colab disconnects, click **Reconnect** and then **Runtime → Run all**: dependencies are reinstalled, preprocessing is redone (1-3 min) and training resumes from the mirrored checkpoints (`G_*.pth` / `D_*.pth`). Nothing already trained is lost.

### After training

1. Download the `.pth` you like and the `.index` from `out/`.
2. Zip them together and install with **Install model from ZIP (.pth + .index)**, or copy the `.pth` to `assets/weights/` and the `.index` to `logs/`.
3. Inference for speech: F0 method `rmvpe`, pitch `0` (±12 for gender change), index rate `0.5–0.75`, protect `0.33`, RMS mix `0.25`.

> **RVC and Seed-VC are different architectures.** An RVC `.pth` does not load in Seed-VC, and a Seed-VC checkpoint does not load here.

## Training a model in Kaggle

[![Open In Kaggle](https://www.kaggle.com/static/images/open-in-kaggle.svg)](https://www.kaggle.com/notebooks/welcome?src=https%3A%2F%2Fraw.githubusercontent.com%2Fltillegal%2Frvc-macos-sequoia%2Fmain%2Fcolab%2Ftrain-rvc-kaggle.ipynb)

> The badge opens a copy of the notebook in your Kaggle account and requires being signed in. If it does not open, use **File → Import Notebook → GitHub** in Kaggle and paste `https://github.com/ltillegal/rvc-macos-sequoia/blob/main/colab/train-rvc-kaggle.ipynb`.

`colab/train-rvc-kaggle.ipynb` is the same pipeline as the Colab notebook, adapted to Kaggle. It trains **RVC v2, 48 kHz, F0-conditioned** on a free Kaggle GPU and leaves the finished `.pth` + `.index` in `/kaggle/working`, where you download them from the **Output** tab. Kaggle is the better choice for long runs: a free account gets ~30 GPU-hours per week and a session can live up to 12 hours, and **Save & Run All (Commit)** keeps training after you close the browser.

### Setup

1. **Settings → Accelerator → GPU T4 x2** (P100 also works) and **Settings → Internet → On**. Without internet the install cell cannot run.
2. Upload the audio as a **private Kaggle Dataset**: *Datasets → New Dataset → drag the files → Create*. One long file is fine.
3. In the notebook click **Add Input → Your Datasets →** that dataset. It is mounted read-only at `/kaggle/input/<name>`, and the notebook finds the audio itself - the dataset name does not have to be typed anywhere.
4. Run the notebook. Use **Run all** for a first try, or **Save Version → Save & Run All (Commit)** for real training.

### How it differs from the Colab notebook

| | Colab | Kaggle |
| --- | --- | --- |
| Dataset | Google Drive (`/content/drive/MyDrive/rvc`) | a Kaggle Dataset mounted at `/kaggle/input` |
| Scratch space | `/content/rvc` | `/kaggle/temp/rvc` (not saved, ~20 GB) |
| Output | copied back to Drive | `/kaggle/working/rvc/<name>` + `<name>_model.zip` |
| Long runs | browser tab must stay open (free) | **Save & Run All (Commit)**, up to 12 hours headless |

Everything else is identical: the same settings (`EXPERIMENT`, `48k`, 200 epochs, `BATCH_SIZE 8`), the same 10-minute splitting of long files, and the same bilingual cells.

### After training

1. Open the **Output** tab of the notebook (or of the finished version) and download `rvc/<name>_model.zip`. The separate `.pth` and `.index` are next to it in `rvc/<name>/`.
2. Install the ZIP with **Install model from ZIP (.pth + .index)**, or copy the `.pth` to `assets/weights/` and the `.index` to `logs/`.

Inference settings are the same as above: F0 method `rmvpe`, pitch `0`, index rate `0.5–0.75`, protect `0.33`, RMS mix `0.25`.

> **Session killed?** Re-run cells 1-14. Training resumes from `/kaggle/working/rvc/<name>/checkpoints` if a version was saved, otherwise from the pretrained model.

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

### Session crashes during preprocessing (`using all available RAM`)

RVC decodes a whole audio file into memory before slicing it. A multi-hour file can exhaust the Colab runtime. Cell 6b converts everything to mono 48 kHz and splits it into 10-minute parts first - run cells 6, 6b, then 7. For an extremely long file lower `SEGMENT_SECONDS` to 300.

### fairseq / omegaconf dependency conflict

    pip install pip==24.0
    pip install -r requirements.txt

### pyworld fails: `No module named 'pkg_resources'`

setuptools 82+ dropped `pkg_resources`, which `pyworld` still imports. Pin an older setuptools:

    pip install "setuptools<80"

The Colab notebook already pins `setuptools==79.0.1`.

### venv does not exist

    /opt/homebrew/opt/python@3.9/bin/python3.9 -m venv .venv
    source .venv/bin/activate
    pip install pip==24.0
    pip install -r requirements.txt

### Inference crashes with `segmentation fault` (`Loading rmvpe model`)

Symptom: the first conversion dies right after `Loading rmvpe model,assets/rmvpe/rmvpe.pt` with `[1] ... segmentation fault python infer-web.py` and a leaked-semaphore warning on exit. The pitch extractor (RMVPE) is unstable on the Apple Silicon MPS backend. This fork now loads RMVPE on the CPU and keeps the rest of the pipeline on MPS, so no extra steps are needed beyond updating.

If it still crashes, force the whole pipeline to the CPU:

    export RVC_DEVICE=cpu
    export MPLBACKEND=Agg
    export OMP_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    python infer-web.py

CPU conversion is slower and produces the same audio. `RVC_DEVICE` is read once at startup, so restart the WebUI after changing it.

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

---

## Support the project

If this fork saves you time, you can buy me a coffee:

<p>
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

PayPal: [0eskimo0@gmail.com](https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD)
