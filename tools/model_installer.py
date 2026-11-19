import os
import zipfile
import shutil
import tempfile


def _resolve_dirs():
    """
    Return (weights_dir, indices_dir) using the same environment variables as
    infer-web.py.
    - weight_root -> directory with .pth files (default: assets/weights)
    - index_root  -> directory with .index files that change_choices() walks
                     (default: logs)
    outside_index_root is deliberately NOT used.
    """
    weights_dir = os.getenv("weight_root") or os.path.join("assets", "weights")
    indices_dir = os.getenv("index_root") or "logs"
    return weights_dir, indices_dir


def _atomic_copy(src, dst_dir, name):
    """
    Copy src to dst_dir/name atomically: write a temporary file in the same
    directory, then os.replace it. An interruption cannot leave a broken file.
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


def _safe_destination(target_root, member_name):
    """Return a verified absolute destination for one ZIP member."""
    normalized = member_name.replace("\\", "/")
    has_drive = len(normalized) >= 2 and normalized[0].isalpha() and normalized[1] == ":"

    if not normalized or normalized.startswith("/") or has_drive:
        raise ValueError(f"unsafe path in archive: {member_name!r}")

    parts = [part for part in normalized.split("/") if part not in ("", ".")]
    if not parts or ".." in parts:
        raise ValueError(f"unsafe path in archive: {member_name!r}")

    destination = os.path.realpath(os.path.join(target_root, *parts))
    if os.path.commonpath((target_root, destination)) != target_root:
        raise ValueError(f"unsafe path in archive: {member_name!r}")
    return destination


def _safe_extract(z, target_root):
    """Extract a ZIP without allowing paths outside target_root."""
    seen = set()
    for member in z.infolist():
        destination = _safe_destination(target_root, member.filename)
        if destination in seen:
            raise ValueError(f"duplicate path in archive: {member.filename!r}")
        seen.add(destination)

        if member.is_dir():
            os.makedirs(destination, exist_ok=True)
            continue

        os.makedirs(os.path.dirname(destination), exist_ok=True)
        with z.open(member) as source, open(destination, "wb") as target:
            shutil.copyfileobj(source, target)


def install_model_from_zip(zip_path):
    """
    Accept a ZIP path (str) or a Gradio gr.File object (dict / .name),
    extract it into a temporary directory, find the .pth and .index files and
    install them:
      - .pth   -> weight_root  (default: assets/weights)
      - .index -> index_root   (default: logs)
    Return a single status line (for gr.Textbox).
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
                _safe_extract(z, os.path.realpath(tmpdir))
        except zipfile.BadZipFile:
            return "Error: invalid ZIP file"
        except ValueError as exc:
            return f"Error: unsafe ZIP: {exc}"

        # Collect the candidates first, without writing anything to disk.
        pth_files = []
        index_files = []
        for root, _, files in os.walk(tmpdir):
            for f in files:
                src = os.path.join(root, f)
                if f.endswith(".pth"):
                    pth_files.append((src, f))
                elif f.endswith(".index"):
                    index_files.append((src, f))

        # Validate before any write: a failure must leave the disk untouched.
        if not pth_files:
            return "Error: no .pth file found inside ZIP"

        # Copy only after validation succeeded.
        for src, f in pth_files:
            _atomic_copy(src, weights_dir, f)
            extracted_pth.append(f)
        for src, f in index_files:
            _atomic_copy(src, indices_dir, f)
            extracted_index.append(f)

    msg = f"Installed model: {', '.join(extracted_pth)} -> {weights_dir}"
    if extracted_index:
        msg += f" | Indexes: {', '.join(extracted_index)} -> {indices_dir}"
    else:
        msg += " | No .index found (optional)"
    return msg
