#!/bin/bash
#
# RVC WebUI launcher for macOS (Apple Silicon)
#
# Frozen into the .app bundle by packaging/build-dmg.sh; __VERSION__ is replaced
# with the release version at build time.
#
# First run: installs Homebrew dependencies, copies the bundled sources into
# ~/Library/Application Support/RVC-WebUI, creates a Python 3.10 venv, installs
# PyTorch and the requirements, downloads the pretrained models, then starts the
# WebUI. Later runs: go straight to the WebUI.
#
set -uo pipefail

VERSION="__VERSION__"

SUPPORT="$HOME/Library/Application Support/RVC-WebUI"
SRC="$SUPPORT/app"
VENV="$SRC/.venv"
LOGS="$SUPPORT/logs"
LOG="$LOGS/setup.log"
STAMP="$SUPPORT/.setup-$VERSION"

# Resolve the bundle we live in: <bundle>/Contents/MacOS/<this script>
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
RES="$(cd "$SELF_DIR/../Resources" 2>/dev/null && pwd)"
BUNDLED_SRC="$RES/app"

if [ "${RVC_NO_TERMINAL:-0}" != "1" ] && [ ! -t 1 ]; then
  # Started from Finder: stdout is not a terminal, so re-open in Terminal where
  # the user can actually see progress and errors. RVC_NO_TERMINAL=1 keeps the
  # script in the current (headless) process, which CI uses.
  /usr/bin/open -a Terminal "$0" || {
    printf 'Could not open Terminal. Run this file manually:\n  %s\n' "$0" >&2
    exit 1
  }
  exit 0
fi

c_cyan=$'\033[36m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_off=$'\033[0m'
step() { printf '%s==>%s %s\n' "$c_cyan" "$c_off" "$*"; }
ok()   { printf '    %s✓%s %s\n' "$c_cyan" "$c_off" "$*"; }
warn() { printf '    %s!%s %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '\n%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2
         printf 'Full log: %s\n' "$LOG" >&2
         [ -f "$LOG.prev" ] && printf 'Previous run: %s\n' "$LOG.prev" >&2
         printf '\n' >&2; exit 1; }

banner() {
  printf '\n%sRVC WebUI %s%s — macOS\n' "$c_cyan" "$VERSION" "$c_off"
  printf 'The first launch installs the dependencies and downloads the models:\n'
  printf '10-30 minutes and about 4 GB of disk. Later launches open the UI at once.\n\n'
}

DRY_RUN="${RVC_DRY_RUN:-0}"       # 1: install Homebrew deps, check the layout, stop before pip
SETUP_ONLY="${RVC_SETUP_ONLY:-0}" # 1: install everything, do not start the WebUI

mkdir -p "$SUPPORT" "$LOGS"
# Keep the previous run's log: after a failure it is usually the one that matters.
[ -s "$LOG" ] && mv -f "$LOG" "$LOG.prev"
: > "$LOG"

banner
printf 'Version %s, directory %s\n\n' "$VERSION" "$SUPPORT" >> "$LOG"

#
# 0. Preconditions
#
command -v brew >/dev/null 2>&1 || die "Homebrew is required. Install it from https://brew.sh and run this again."
[ -d "$BUNDLED_SRC" ] || die "The app bundle has no sources ($BUNDLED_SRC). Download the .dmg again."

#
# 1. Homebrew dependencies
#
BREW_PY="python@3.10"
step "Checking Homebrew dependencies (ffmpeg, $BREW_PY, aria2)"
missing=()
for formula in ffmpeg aria2 "$BREW_PY"; do
  brew list --versions "$formula" >/dev/null 2>&1 || missing+=("$formula")
done
if [ ${#missing[@]} -gt 0 ]; then
  warn "Missing: ${missing[*]} — installing, this takes a few minutes"
  brew install "${missing[@]}" >>"$LOG" 2>&1 || die "brew install ${missing[*]} failed"
fi
PY="$(brew --prefix)/opt/$BREW_PY/bin/python3.10"
[ -x "$PY" ] || die "Python 3.10 not found after install ($PY)"
ok "$("$PY" -V 2>&1)"

#
# 2. Sources
#
step "Copying the sources into $SRC"
mkdir -p "$SRC"
rsync -a --delete \
  --exclude '.venv' \
  --exclude 'assets' \
  --exclude '.env' \
  --exclude 'logs' \
  --exclude '__pycache__' \
  "$BUNDLED_SRC/" "$SRC/" >>"$LOG" 2>&1 || die "Could not copy the sources"
chmod +x "$SRC/tools/dlmodels.sh" 2>/dev/null || true
ok "sources in place"

#
# 3. Virtualenv + PyTorch + requirements
#
if [ -x "$VENV/bin/python" ] && [ -f "$STAMP" ]; then
  step "The $VERSION environment is already installed — skipping the setup"
else
  if [ ! -x "$VENV/bin/python" ]; then
    step "Creating the virtual environment (Python 3.10)"
    "$PY" -m venv "$VENV" >>"$LOG" 2>&1 || die "python -m venv failed"
  fi
  if [ "$DRY_RUN" = "1" ]; then
    warn "dry-run: skipping pip install (pip==24.0, torch==2.4.0, requirements.txt)"
    step "dry-run finished: Homebrew dependencies and the layout are fine"
    exit 0
  fi
  step "Upgrading pip to 24.0 (versions >= 24.1 break the fairseq build)"
  "$VENV/bin/python" -m pip install --disable-pip-version-check "pip==24.0" >>"$LOG" 2>&1 \
    || die "pip install pip==24.0 failed"

  # torch 2.4.x keeps torch.load() defaults compatible with the RVC checkpoints.
  # 2.6+ flips weights_only to True and the model import starts failing.
  step "Installing PyTorch 2.4.0 (Apple Silicon / MPS)"
  printf '    (about 2 GB to download; progress in %s)\n' "$LOG"
  "$VENV/bin/python" -m pip install --disable-pip-version-check \
      "torch==2.4.0" "torchvision==0.19.0" "torchaudio==2.4.0" >>"$LOG" 2>&1 || {
    tail -25 "$LOG" >&2
    die "pip install torch==2.4.0 failed"
  }
  ok "$("$VENV/bin/python" -c 'import torch; print("torch", torch.__version__, "- MPS:", torch.backends.mps.is_available())' 2>&1)"

  step "Installing requirements — the slowest step, keep this window open"
  printf '    (fairseq builds from source; progress in %s)\n' "$LOG"
  if ! "$VENV/bin/python" -m pip install --disable-pip-version-check \
        -r "$SRC/requirements.txt" >>"$LOG" 2>&1; then
    printf '\n%sLast lines of the log:%s\n' "$c_red" "$c_off" >&2
    tail -25 "$LOG" >&2
    die "pip install -r requirements.txt failed"
  fi
  touch "$STAMP"
  ok "dependencies installed"
fi

#
# 4. Pretrained models
#
if ( cd "$SRC" && ./tools/dlmodels.sh --check ) >>"$LOG" 2>&1; then
  step "Pretrained models already present"
else
  step "Downloading the missing pretrained models — about 4 GB"
  ( cd "$SRC" && ./tools/dlmodels.sh ) >>"$LOG" 2>&1 || {
    tail -20 "$LOG" >&2
    die "Could not download the models"
  }
  ok "models downloaded"
fi

#
# 5. Run
#
export PYTORCH_ENABLE_MPS_FALLBACK=1
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
export KMP_DUPLICATE_LIB_OK=TRUE
export OMP_NUM_THREADS=1
export LANG=en_US.UTF-8
# The bundled app must not expose the unauthenticated UI to the local network.
# Manual runs keep the upstream default unless RVC_LISTEN_HOST is set.
export RVC_LISTEN_HOST=127.0.0.1

printf '\n'
step "Starting the WebUI - http://127.0.0.1:7865"
printf '    Stop: Ctrl+C in this window. Log: %s\n\n' "$LOG"

cd "$SRC" || die "no such directory: $SRC"

if [ "$SETUP_ONLY" = "1" ]; then
  step "Setup finished (RVC_SETUP_ONLY=1: WebUI not started)"
  exit 0
fi

exec "$VENV/bin/python" infer-web.py
