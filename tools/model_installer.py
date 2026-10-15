import os
import zipfile
import shutil
import tempfile


def _resolve_dirs():
    """
    Возвращает (weights_dir, indices_dir), беря пути из тех же переменных
    окружения, что использует infer-web.py.
    - weight_root -> папка с .pth (по умолчанию assets/weights)
    - index_root  -> папка с .index, которую обходит change_choices()
                     (по умолчанию logs)
    outside_index_root сознательно НЕ используется.
    """
    weights_dir = os.getenv("weight_root") or os.path.join("assets", "weights")
    indices_dir = os.getenv("index_root") or "logs"
    return weights_dir, indices_dir


def _atomic_copy(src, dst_dir, name):
    """
    Копирует src в dst_dir/name атомарно: сначала во временный файл в той же
    папке, затем os.replace. Прерывание не оставит битый файл.
    """
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, name)
    fd, tmp = tempfile.mkstemp(prefix=".install_", dir=dst_dir)
    os.close(fd)
    try:
        shutil.copy2(src, tmp)
        os.replace(tmp, dst)
    except Exception:
        try:
            os.remove(tmp)
        except OSError:
            pass
        raise
    return dst


def install_model_from_zip(zip_path):
    """
    Принимает путь к ZIP (str) или объект Gradio gr.File (dict / .name),
    распаковывает во временную папку, находит .pth и .index и кладёт их:
      - .pth   -> weight_root  (по умолчанию assets/weights)
      - .index -> index_root   (по умолчанию logs)
    Возвращает одну строку статуса (для gr.Textbox).
    """
    if not zip_path:
        return "Error: no file provided"

    if isinstance(zip_path, dict):
        zip_path = zip_path.get("name") or zip_path.get("path")
    elif hasattr(zip_path, "name"):
        zip_path = zip_path.name

    if not zip_path or not os.path.exists(zip_path):
        return f"Error: ZIP file not found: {zip_path}"

    if not zip_path.lower().endswith(".zip"):
        return f"Error: not a ZIP file: {zip_path}"

    weights_dir, indices_dir = _resolve_dirs()

    extracted_pth = []
    extracted_index = []

    with tempfile.TemporaryDirectory() as tmpdir:
        try:
            with zipfile.ZipFile(zip_path, "r") as z:
                z.extractall(tmpdir)
        except zipfile.BadZipFile:
            return "Error: invalid ZIP file"

        for root, _, files in os.walk(tmpdir):
            for f in files:
                src = os.path.join(root, f)
                if f.endswith(".pth"):
                    _atomic_copy(src, weights_dir, f)
                    extracted_pth.append(f)
                elif f.endswith(".index"):
                    _atomic_copy(src, indices_dir, f)
                    extracted_index.append(f)

    if not extracted_pth:
        return "Error: no .pth file found inside ZIP"

    msg = f"Installed model: {', '.join(extracted_pth)} -> {weights_dir}"
    if extracted_index:
        msg += f" | Indexes: {', '.join(extracted_index)} -> {indices_dir}"
    else:
        msg += " | No .index found (optional)"
    return msg
