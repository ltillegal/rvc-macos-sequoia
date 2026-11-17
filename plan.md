# RVC WebUI for macOS — plan and current state

Updated: 2026-11-16
Fork: https://github.com/ltillegal/rvc-macos-sequoia
Local checkout: `~/RVC-WebUI-MacOS` (Omarchy / Arch Linux)
Target: macOS 13+ on Apple Silicon, developed against Sequoia

The source of truth is git. Anything that is not in `git log` counts as not
done; this file only summarises the shape of the project and the open tasks.

## What this fork changes

- English UI by default: the locale auto-detection falls back to `en_US`
  instead of the upstream hardcoded `zh_CN`.
- No pyenv: `run.sh` and `run-realtime.sh` use Homebrew `python@3.10` through
  `PYTHON_BIN`. Homebrew disabled `python@3.9` on 2026-10-15.
- PyTorch 2.4.0 / torchvision 0.19.0 / torchaudio 2.4.0 are pinned in
  `requirements.txt`, the launcher and the README. 2.4.x is the last line where
  `torch.load()` defaults to `weights_only=False`, which the RVC checkpoints
  rely on.
- `pip==24.0` is installed before the rest: later versions break the fairseq
  build.
- The bundled app binds Gradio to `127.0.0.1` (`RVC_LISTEN_HOST`). Manual runs
  keep the upstream `0.0.0.0` default.
- One-click `.dmg` installer: `RVC WebUI.app` installs the Homebrew
  dependencies, creates the environment, downloads the models and starts the
  WebUI.
- A ZIP model installer in the UI, atomic writes, and `change_choices()`
  refreshes the model dropdown after an install.

## Repository layout

| Path | Purpose |
| --- | --- |
| `packaging/launcher.sh` | Frozen into the `.app`; first-run installer and launcher |
| `packaging/build-dmg.sh` | Stages the bundle, writes `Info.plist`, signs ad-hoc, builds the `.dmg` and its `.sha256` |
| `tools/dlmodels.sh` | Downloads the 19 required model files; `--check` reports what is missing |
| `tools/model_installer.py` | ZIP model installer used by the WebUI |
| `.github/workflows/release.yml` | Build and smoke-test on PRs, dry-run the first launch, publish on tags |
| `.github/workflows/lock.yml` | Regenerates `requirements.lock.txt` on `macos-latest` |
| `.github/workflows/verify.yml` | Installs the lockfile, imports the stack and boots the WebUI on `macos-latest` |
| `docs/en/` | The only docs that ship inside the bundle; the FAQ tab reads `docs/en/faq_en.md` |

## Installer flow

`RVC WebUI.app` is a shell launcher with a version stamp. On first launch it:

1. Checks for Homebrew and installs `ffmpeg`, `python@3.10` and `aria2` if
   missing (the CI dry-run exercises this for real).
2. Copies `Contents/Resources/app` into
   `~/Library/Application Support/RVC-WebUI/app`, dropping `.venv`, `assets`,
   `.env` and logs from the source tree.
3. Creates `.venv`, installs `pip==24.0`, the pinned PyTorch and
   `requirements.txt`, then writes `.setup-<version>`.
4. Runs `tools/dlmodels.sh --check`; downloads only when files are missing.
5. Starts `infer-web.py` on `http://127.0.0.1:7865`.

The setup log lives in `logs/setup.log`; the previous run is kept as
`setup.log.prev` because the failed run is usually the one that matters.

Environment flags used by CI and debugging:

- `RVC_DRY_RUN=1` — install the Homebrew dependencies for real, stop before pip.
- `RVC_SETUP_ONLY=1` — install everything, do not start the WebUI.
- `RVC_NO_TERMINAL=1` — do not re-open the script in Terminal (headless runs).
- `RVC_LISTEN_HOST` — bind address for the WebUI.

## CI and releases

- `release.yml` runs on every pull request: it builds the `.dmg`, opens it,
  checks the bundle layout and the embedded version, verifies the signature and
  runs the launcher with `RVC_DRY_RUN=1` on macOS.
- Tags matching `v*` publish `RVC-WebUI-<version>-macos.dmg` plus a `.sha256`
  that verifies from the download directory with
  `shasum -a 256 -c RVC-WebUI-<version>-macos.dmg.sha256`.
- `lock.yml` runs on `workflow_dispatch` and whenever `requirements.txt`
  changes. It installs the real requirements on macOS arm64, checks that the
  torch 2.4 and `gradio_client` 0.2.x pins survive, and uploads
  `requirements.lock.txt` as an artifact (nothing is committed automatically).
  The lock is produced with `pip freeze --all`, because plain `pip freeze`
  drops setuptools and gradio needs `pkg_resources` at import time.
- `verify.yml` runs on `workflow_dispatch`, on changes to either requirements
  file and weekly. It installs `requirements.lock.txt` into a fresh virtualenv
  on macOS arm64, imports every heavyweight dependency, checks that gradio
  still finds `media_data` in `gradio_client`, then boots `infer-web.py` and
  waits for an HTTP answer on `127.0.0.1:7865`. This is the job that proves a
  release installs, so it must be green before tagging.
- Published releases: `v0.2.4` is current. `v0.2.3` and older resolve
  `gradio_client` 2.x and fail to start the WebUI on a fresh install;
  `v0.1.0` does not install (disabled `python@3.9`) and `v0.2.0` ships a
  `.sha256` with a `dist/` path. All of them are marked in their release notes
  and kept for history.

## Open tasks

- [ ] Migrate to Python 3.11 (`numba` 0.58, `llvmlite` 0.43). `python@3.10` is
      deprecated and will be disabled on 2027-10-01.
- [ ] Notarize the app. Until then macOS needs right-click -> Open, or
      `xattr -dr com.apple.quarantine "/Applications/RVC WebUI.app"`.
- [ ] Translate the remaining CJK text that is not user-facing documentation:
      the `zh_CN` / `ja_JP` / `ko_KR` UI locale files, comments and strings in
      `infer-web.py`, and `configs/config.py`.
- [X] Regenerate `requirements.lock.txt` on macOS with the torch 2.4 pins.
- [X] Pin `gradio_client` 0.2.x, `huggingface_hub` 0.16.4, `httpx` 0.24.1 and
      setuptools so `import gradio` works on a fresh install, and add the
      `verify` workflow that installs the lockfile and boots the WebUI.
- [X] Strip `plan.md`, `tests/`, `colab/`, `.github/`, `packaging/` and the
      non-English docs from the `.app` bundle.
- [X] Make the FAQ tab fall back to `docs/en/faq_en.md` instead of a traceback.
- [X] Remove the CJK docs (`docs/cn`, `docs/jp`, `docs/kr`, the local setup
      guide) and translate `CONTRIBUTING.md` and the third-party license file.

## Working agreements

1. Git is the source of truth: check `git log` before claiming a task is done.
2. Every change goes through a branch and a pull request; CI must be green.
3. A release is a tag plus a downloaded-and-verified `.sha256`.
4. Do not delete published releases to fix a mistake; mark them in the release
   notes instead.
