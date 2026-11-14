#!/bin/bash
#
# RVC WebUI launcher for macOS (Apple Silicon)
#
# Frozen into the .app bundle by packaging/build-dmg.sh; __VERSION__ is replaced
# with the release version at build time.
#
# First run: installs Homebrew dependencies, copies the bundled sources into
# ~/Library/Application Support/RVC-WebUI, creates a Python 3.9 venv, installs
# requirements, downloads the pretrained models, then starts the WebUI.
# Later runs: go straight to the WebUI.
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

if [ -t 1 ]; then :; else
  # Started from Finder: stdout is not a terminal, so re-open in Terminal where
  # the user can actually see progress and errors.
  exec /usr/bin/open -a Terminal "$0"
fi

c_cyan=$'\033[36m'; c_yellow=$'\033[33m'; c_red=$'\033[31m'; c_off=$'\033[0m'
step() { printf '%s==>%s %s\n' "$c_cyan" "$c_off" "$*"; }
ok()   { printf '    %s✓%s %s\n' "$c_cyan" "$c_off" "$*"; }
warn() { printf '    %s!%s %s\n' "$c_yellow" "$c_off" "$*"; }
die()  { printf '\n%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2
         printf 'Полный лог: %s\n\n' "$LOG" >&2; exit 1; }

banner() {
  printf '\n%sRVC WebUI %s%s — macOS\n' "$c_cyan" "$VERSION" "$c_off"
  printf 'Первый запуск ставит зависимости и качает модели: 10–30 минут и ~4 ГБ.\n'
  printf 'Повторные запуски открывают интерфейс сразу.\n\n'
}

DRY_RUN="${RVC_DRY_RUN:-0}"      # 1: проверяет предусловия и раскладку, ничего не ставит
SETUP_ONLY="${RVC_SETUP_ONLY:-0}" # 1: ставит всё, но не запускает WebUI

mkdir -p "$SUPPORT" "$LOGS"
: > "$LOG"

banner
printf 'Версия %s, каталог %s\n\n' "$VERSION" "$SUPPORT" >> "$LOG"

#
# 0. Preconditions
#
command -v brew >/dev/null 2>&1 || die "Нужен Homebrew. Установите: https://brew.sh, затем запустите снова."
[ -d "$BUNDLED_SRC" ] || die "В приложении нет исходников ($BUNDLED_SRC). Скачайте .dmg заново."

#
# 1. Homebrew dependencies
#
step "Проверяю Homebrew-зависимости (ffmpeg, python@3.9, aria2)"
missing=()
for formula in ffmpeg aria2 python@3.9; do
  brew list --versions "$formula" >/dev/null 2>&1 || missing+=("$formula")
done
if [ ${#missing[@]} -gt 0 ]; then
  if [ "$DRY_RUN" = "1" ]; then
    warn "dry-run: не хватает ${missing[*]} (установка пропущена)"
  else
    warn "Не хватает: ${missing[*]} — устанавливаю, это несколько минут"
    brew install "${missing[@]}" >>"$LOG" 2>&1 || die "brew install ${missing[*]} не удался"
  fi
fi
PY="$(brew --prefix)/opt/python@3.9/bin/python3.9"
[ -x "$PY" ] || die "Не нашёл Python 3.9 после установки ($PY)"
ok "$("$PY" -V 2>&1)"

#
# 2. Sources
#
step "Раскладываю исходники в $SRC"
mkdir -p "$SRC"
rsync -a --delete \
  --exclude '.venv' \
  --exclude 'assets' \
  --exclude '.env' \
  --exclude 'logs' \
  --exclude '__pycache__' \
  "$BUNDLED_SRC/" "$SRC/" >>"$LOG" 2>&1 || die "Не удалось скопировать исходники"
chmod +x "$SRC/tools/dlmodels.sh" 2>/dev/null || true
ok "исходники на месте"

#
# 3. Virtualenv + requirements
#
if [ -x "$VENV/bin/python" ] && [ -f "$STAMP" ]; then
  step "Окружение для $VERSION уже установлено — пропускаю установку"
else
  if [ ! -x "$VENV/bin/python" ]; then
    step "Создаю виртуальное окружение (Python 3.9)"
    "$PY" -m venv "$VENV" >>"$LOG" 2>&1 || die "python -m venv не сработал"
  fi
  if [ "$DRY_RUN" = "1" ]; then
    warn "dry-run: пропускаю pip install (pip==24.0 + requirements.txt)"
    step "dry-run завершён: предусловия и раскладка в порядке"
    exit 0
  fi
  step "Обновляю pip до 24.0 (версии >= 24.1 ломают сборку fairseq)"
  "$VENV/bin/python" -m pip install --disable-pip-version-check "pip==24.0" >>"$LOG" 2>&1 \
    || die "pip install pip==24.0 не удался"

  step "Ставлю зависимости — самый долгий шаг, не закрывайте окно"
  printf '    (torch ~2 ГБ + сборка fairseq; прогресс в %s)\n' "$LOG"
  if ! "$VENV/bin/python" -m pip install --disable-pip-version-check \
        -r "$SRC/requirements.txt" >>"$LOG" 2>&1; then
    printf '\n%sПоследние строки лога:%s\n' "$c_red" "$c_off" >&2
    tail -25 "$LOG" >&2
    die "pip install -r requirements.txt не удался"
  fi
  touch "$STAMP"
  ok "зависимости установлены"
fi

#
# 4. Pretrained models
#
if [ ! -f "$SRC/assets/hubert/hubert_base.pt" ] || [ ! -f "$SRC/assets/rmvpe/rmvpe.pt" ]; then
  step "Качаю предобученные модели (hubert, rmvpe, uvr5)"
  ( cd "$SRC" && ./tools/dlmodels.sh ) >>"$LOG" 2>&1 || {
    tail -20 "$LOG" >&2
    die "Не удалось скачать модели"
  }
  ok "модели скачаны"
else
  step "Модели уже на месте"
fi

#
# 5. Run
#
export PYTORCH_ENABLE_MPS_FALLBACK=1
export PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0
export KMP_DUPLICATE_LIB_OK=TRUE
export OMP_NUM_THREADS=1
export LANG=en_US.UTF-8

printf '\n'
step "Запускаю WebUI — http://127.0.0.1:7865"
printf '    Остановить: Ctrl+C в этом окне. Лог: %s\n\n' "$LOG"

cd "$SRC" || die "нет каталога $SRC"

if [ "$SETUP_ONLY" = "1" ]; then
  step "Установка завершена (RVC_SETUP_ONLY=1: запуск пропущен)"
  exit 0
fi

exec "$VENV/bin/python" infer-web.py
