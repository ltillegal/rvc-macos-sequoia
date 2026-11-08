# RVC-WebUI-MacOS (форк под Sequoia)

<p align="center">
  <a href="README.md"><img src="https://img.shields.io/badge/English-6e7781?style=flat-square" alt="English"></a>
  <a href="README.ru.md"><img src="https://img.shields.io/badge/%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9-2ea44f?style=flat-square" alt="Русский"></a>
</p>

<p align="center">
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

Форк [qingbo1011/RVC-WebUI-MacOS](https://github.com/qingbo1011/RVC-WebUI-MacOS) с исправлениями для macOS Sequoia и английским интерфейсом по умолчанию.

English version: [README.md](README.md)

## Что исправлено в этом форке

- Английский интерфейс по умолчанию — определяется локаль системы, при отсутствии английского используется en_US вместо жёстко заданного zh_CN
- Убрана зависимость от pyenv — `run.sh` и `run-realtime.sh` используют Homebrew Python 3.9, путь задаётся через `PYTHON_BIN`
- Исправлен конфликт fairseq / omegaconf — python-обёртка aria2 закомментирована, всё работает с `pip<24.1`
- Проверено на macOS Sequoia (Apple Silicon: M1/M2/M3/M4)

## Требования

- macOS Sequoia (Apple Silicon)
- Homebrew

## Установка

    brew install ffmpeg python@3.9 aria2

    git clone https://github.com/ltillegal/rvc-macos-sequoia.git
    cd rvc-macos-sequoia

    /opt/homebrew/opt/python@3.9/bin/python3.9 -m venv .venv
    source .venv/bin/activate

    pip install pip==24.0
    pip install -r requirements.txt

    python infer-web.py

Откройте http://127.0.0.1:7865 в браузере.

## Смена голоса в реальном времени

    ./run-realtime.sh

## Обучение модели в Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/ltillegal/rvc-macos-sequoia/blob/main/colab/train-rvc-colab.ipynb)

Ноутбук `colab/train-rvc-colab.ipynb` обучает голосовую модель **RVC v2, 48 кГц, с F0** на бесплатном GPU в Colab и складывает готовые `.pth` + `.index` обратно на Google Drive. Результат устанавливается сюда через ZIP-установщик. Сам ноутбук двуязычный (английский / русский).

### Датасет

- 10–30 минут чистой речи одного человека — практический оптимум. 4 минуты тоже обучатся, но тембр будет менее стабильным.
- Без музыки, эха, второго голоса и клиппинга. Ровный уровень. Подходят WAV / MP3 / FLAC / M4A / OGG.
- Один длинный файл — нормально: ноутбук сам приводит его к моно 48 кГц и режет на части по 10 минут через ffmpeg, а предобработка уже нарезает их на окна по 3.7 с.
- Не увлекайтесь денойзом: агрессивная чистка выучивается моделью и звучит как «металл».

Положите файлы сюда:

    MyDrive/rvc/mymodel/dataset/

Результаты появятся в:

    MyDrive/rvc/mymodel/out/

`mymodel` — только имя по умолчанию: можно поставить любое (латиница, без пробелов). Оно станет именем эксперимента и префиксом готовых `.pth`.

### Что делает ноутбук

1. Создаёт окружение Python 3.11 через `uv`, ставит PyTorch 2.4.1 (CUDA 12.1), `fairseq` (сборка C++17), `faiss` и зависимости RMVPE.
2. Клонирует этот репозиторий и скачивает `hubert_base.pt`, `rmvpe.pt` и претрейн 48 кГц с F0.
3. Приводит датасет к моно 48 кГц и режет на части по 10 минут через ffmpeg (память не растёт, поэтому многочасовой файл не уронит сессию).
4. Готовит его: high-pass, нарезка на окна 3.7 с, нормализация.
5. Извлекает F0 (RMVPE) и признаки HuBERT (768 для v2).
6. Обучает `v2 48k f0 1`, 200 эпох, готовый к инференсу `.pth` каждые 25 эпох.
7. Строит индекс faiss и складывает `.pth` + `.index` на Drive.

### Настройки

| Параметр | По умолчанию | Значение |
| --- | --- | --- |
| `EXPERIMENT` | `mymodel` | имя эксперимента и итоговых файлов |
| `SAMPLE_RATE` | `48k` | рекомендуется 48 кГц v2; для 40k/32k используется v1 |
| `TOTAL_EPOCHS` | `200` | для 10–30 мин аудио; ставьте 100, если меньше 5 мин |
| `SAVE_EVERY` | `25` | каждые 25 эпох пишется готовый к использованию `.pth` |
| `BATCH_SIZE` | `8` | при `CUDA out of memory` снизьте до 6 или 4 |

### Время и продолжение

- Подготовка: ~10–20 мин. Обучение: ~40–90 мин на 200 эпох на бесплатном T4.
- Чекпоинты копируются в `out/checkpoints/` каждые 5 минут.
- Если Colab отключился — нажмите **Reconnect** и затем **Runtime → Run all**: зависимости поставятся заново, подготовка повторится (1–3 мин), а обучение продолжится с чекпоинтов на Drive (`G_*.pth` / `D_*.pth`). Уже обученное не теряется.

### После обучения

1. Скачайте понравившийся `.pth` и `.index` из `out/`.
2. Упакуйте их в один ZIP и установите через **Install model from ZIP (.pth + .index)**, либо скопируйте `.pth` в `assets/weights/`, а `.index` в `logs/`.
3. Инференс для речи: F0 `rmvpe`, pitch `0` (±12 для смены пола), index rate `0.5–0.75`, protect `0.33`, RMS mix `0.25`.

> **RVC и Seed-VC — разные архитектуры.** RVC-модель не открывается в Seed-VC, и наоборот.

## Модели

Файлы моделей раскладываются согласно `.env`:

- `.pth` -> `weight_root` (по умолчанию `assets/weights/`)
- `.index` -> `index_root` (по умолчанию `logs/`)
- внешние `.index` -> `outside_index_root` (по умолчанию `assets/indices/`)

Важно: вкладка инференса читает `.index` из `index_root` (`logs/`), а не из
`outside_index_root`. Если положить `.index` в `assets/indices/`, он не появится
в выпадающем списке на главной вкладке.

Избегайте кириллицы и китайских символов в путях — FFmpeg падает.

### Установка моделей из ZIP

На вкладке инференса есть панель **Install model from ZIP (.pth + .index)**.
Выберите ZIP-архив с файлом `.pth` (и, при желании, `.index`) и нажмите
**Install**. Установщик:

- распаковывает архив во временную папку,
- копирует `.pth` в `weight_root` (по умолчанию `assets/weights/`),
- копирует `.index` в `index_root` (по умолчанию `logs/`),
- автоматически обновляет списки моделей и индексов.

Файлы записываются атомарно (временный файл + переименование), поэтому
прерванная установка не оставит битый `.pth` или `.index`.

## Решение проблем

### Сессия падает на предобработке (`using all available RAM`)

RVC декодирует аудиофайл целиком в память перед нарезкой. Многочасовой файл может исчерпать память Colab. Ячейка 6b сначала приводит всё к моно 48 кГц и режет на части по 10 минут — запускайте 6, 6b, затем 7. Для очень длинного файла уменьшите `SEGMENT_SECONDS` до 300.

### Конфликт fairseq / omegaconf

    pip install pip==24.0
    pip install -r requirements.txt

### pyworld падает с `No module named 'pkg_resources'`

В setuptools 82+ убрали `pkg_resources`, а `pyworld` его до сих пор импортирует. Поставьте более старый setuptools:

    pip install "setuptools<80"

В ноутбуке для Colab уже закреплён `setuptools==79.0.1`.

### Нет окружения venv

    /opt/homebrew/opt/python@3.9/bin/python3.9 -m venv .venv
    source .venv/bin/activate
    pip install pip==24.0
    pip install -r requirements.txt

### Интерфейс всё ещё на китайском

Проверьте `i18n/i18n.py` — `I18nAuto.__init__` должен определять локаль и откатываться на `en_US`.

## Обновление из upstream

    git remote add upstream https://github.com/qingbo1011/RVC-WebUI-MacOS.git
    git fetch upstream
    git merge upstream/main

## Поддержать проект

Если форк сэкономил вам время, можно угостить меня кофе:

<p>
  <a href="https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" alt="Donate with PayPal" height="40">
  </a>
</p>

PayPal: [0eskimo0@gmail.com](https://www.paypal.com/donate/?business=0eskimo0%40gmail.com&no_recurring=0&item_name=Support+RVC-WebUI-MacOS&currency_code=USD)

## Благодарности

- Оригинальный RVC-WebUI: RVC-Project/Retrieval-based-Voice-Conversion-WebUI
- macOS-порт: qingbo1011/RVC-WebUI-MacOS

## Лицензия

MIT
