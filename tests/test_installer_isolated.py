# Тест A: install_model_from_zip в изоляции (stdlib-only).
# Запуск: python3 -m unittest tests.test_installer_isolated -v
import os
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from tools.model_installer import install_model_from_zip, _resolve_dirs


def make_zip(zip_path: Path, entries: dict):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in entries.items():
            z.writestr(name, data)


class InstallerIsolatedTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.weights = self.tmp / "weights"
        self.indexes = self.tmp / "indexes"
        self.weights.mkdir()
        self.indexes.mkdir()
        self._old_wr = os.environ.get("weight_root")
        self._old_ir = os.environ.get("index_root")
        os.environ["weight_root"] = str(self.weights)
        os.environ["index_root"] = str(self.indexes)

    def tearDown(self):
        for k, v in (("weight_root", self._old_wr), ("index_root", self._old_ir)):
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        self._tmp.cleanup()

    def _ls(self, d: Path):
        return sorted(p.name for p in d.iterdir())

    def test_resolve_dirs_uses_env(self):
        w, i = _resolve_dirs()
        self.assertEqual(Path(w), self.weights)
        self.assertEqual(Path(i), self.indexes)

    def test_pth_and_index_go_to_correct_dirs(self):
        zp = self.tmp / "model.zip"
        make_zip(zp, {
            "subdir/model.pth": b"PTH-DATA",
            "subdir/model.index": b"INDEX-DATA",
        })
        msg = install_model_from_zip(str(zp))
        self.assertTrue(msg.startswith("Installed model: "), msg)
        self.assertEqual(self._ls(self.weights), ["model.pth"])
        self.assertEqual(self._ls(self.indexes), ["model.index"])
        self.assertEqual((self.weights / "model.pth").read_bytes(), b"PTH-DATA")
        self.assertEqual((self.indexes / "model.index").read_bytes(), b"INDEX-DATA")

    def test_pth_only(self):
        zp = self.tmp / "model.zip"
        make_zip(zp, {"m.pth": b"X"})
        msg = install_model_from_zip(str(zp))
        self.assertTrue(msg.startswith("Installed model: "), msg)
        self.assertIn("No .index found", msg)
        self.assertEqual(self._ls(self.weights), ["m.pth"])
        self.assertEqual(self._ls(self.indexes), [])

    def test_multiple_pth_and_index(self):
        zp = self.tmp / "multi.zip"
        make_zip(zp, {
            "a.pth": b"A", "b.pth": b"B",
            "a.index": b"ia", "b.index": b"ib",
        })
        msg = install_model_from_zip(str(zp))
        self.assertTrue(msg.startswith("Installed model: "), msg)
        self.assertEqual(self._ls(self.weights), ["a.pth", "b.pth"])
        self.assertEqual(self._ls(self.indexes), ["a.index", "b.index"])

    def test_zip_without_pth_errors(self):
        zp = self.tmp / "no_pth.zip"
        make_zip(zp, {"only.index": b"i"})
        msg = install_model_from_zip(str(zp))
        self.assertEqual(msg, "Error: no .pth file found inside ZIP")
        self.assertEqual(self._ls(self.weights), [])
        self.assertEqual(self._ls(self.indexes), [])

    def test_bad_zip(self):
        zp = self.tmp / "bad.zip"
        zp.write_bytes(b"not a zip")
        msg = install_model_from_zip(str(zp))
        self.assertEqual(msg, "Error: invalid ZIP file")

    def test_missing_file(self):
        msg = install_model_from_zip(str(self.tmp / "nope.zip"))
        self.assertTrue(msg.startswith("Error: ZIP file not found"), msg)

    def test_non_zip_extension(self):
        p = self.tmp / "x.tar"
        p.write_bytes(b"")
        msg = install_model_from_zip(str(p))
        self.assertTrue(msg.startswith("Error: not a ZIP file"), msg)

    def test_none_input(self):
        self.assertEqual(install_model_from_zip(None), "Error: no file provided")

    def test_gradio_like_dict(self):
        zp = self.tmp / "model.zip"
        make_zip(zp, {"m.pth": b"X"})
        msg = install_model_from_zip({"name": str(zp)})
        self.assertTrue(msg.startswith("Installed model: "), msg)
        self.assertEqual(self._ls(self.weights), ["m.pth"])

    def test_atomic_no_tmp_leftovers(self):
        zp = self.tmp / "model.zip"
        make_zip(zp, {"m.pth": b"X", "m.index": b"I"})
        install_model_from_zip(str(zp))
        for d in (self.weights, self.indexes):
            leftovers = [n for n in self._ls(d) if n.startswith(".install_")]
            self.assertEqual(leftovers, [], f"tmp leftovers in {d}: {leftovers}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
