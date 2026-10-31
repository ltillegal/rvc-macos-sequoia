# RVC-WebUI-MacOS — план и фактическое состояние

Обновлено: 2026-10-31
HEAD: 6b00767 (main, origin/main)
Fork: https://github.com/ltillegal/rvc-macos-sequoia
Локально: ~/RVC-WebUI-MacOS (Omarchy / Arch Linux)
Target: macOS Sequoia, Apple Silicon

Источник истины — git. Всё, чего нет в `git log`, считается несделанным.

## Что уже сделано (по коммитам, проверено)

- 46f147c — Initial: macOS Sequoia fork, English locale, pip fix, pyenv path removed
- 6046005 — English README with install instructions
- ce462c1 — Remove upstream CI workflows
- ea0cb56, 1c52b7f — run.sh / run-realtime.sh → English
- 054cfc5, 1290b5a, 4488984 — requirements.lock.txt cleanup
- 0ad8392 — .env.example, ignore .env
- 5b3113e — model_installer: env-aware paths + atomic copy
- cb693f8 — UI: ZIP model installer with browse button
- affcece — docs: ZIP installer + index_root behavior
- f49928a — gradio 3.x: drop type='filepath'
- 09638e4 — browse WAV via gr.Audio on Single Inference
- 1570926 — fairseq: torch.load weights_only=False
- a71c1f7, 6b00767 — ClearButton → Button for gradio 3.34

## Установленные факты о ZIP-installer (не по памяти, а по коду)

- tools/model_installer.py — существует, 3.4 KB
- Импорт: infer-web.py:55 (`from tools.model_installer import install_model_from_zip`)
- UI-панель: infer-web.py ~860–875
  - gr.File(file_types=[".zip"]) — browse ZIP
  - install_btn (gr.Button "Install")
  - install_status (gr.Textbox, interactive=False, lines=2)
- Обработчик: infer-web.py:968–977
  - install_btn.click(fn=install_model_from_zip, inputs=[zip_file], outputs=[install_status], api_name="infer_install_model")
  - .then(fn=change_choices, inputs=[], outputs=[sid0, file_index2])
- Раскладка файлов (по коду и README):
  - `.pth`   → weight_root (default assets/weights/)
  - `.index` → index_root  (default logs/)
  - outside_index_root (default assets/indices/) НЕ используется — change_choices() его не обходит
- Запись атомарная: mkstemp в целевой папке + os.replace
- Обрабатывает несколько .pth / .index в одном ZIP (копирует все)

## Открытые задачи

- [ ] End-to-end тест: реальный ZIP (.pth + .index) → Install → проверить,
      что модель появилась в dropdown и inference работает.
- [ ] Проверить поведение на macOS Sequoia / Apple Silicon (текущая среда — Arch).
- [ ] (опционально) предупреждать, если в ZIP >1 .pth или >1 .index.

## Правила на будущее (после эпизода потери контекста)

1. Источник истины — git. Перед выводом «сделано/не сделано» — `git log --all`,
   `git show <hash>`, `git merge-base --is-ancestor`.
2. Перед rebase/merge/переписыванием истории — `git tag backup-YYYY-MM-DD`.
3. Каждая фича — отдельный коммит с осмысленным сообщением (что и зачем).
4. Не полагаться на память при описании состояния репо.
5. plan.md держать в репо и обновлять при изменениях состояния.
