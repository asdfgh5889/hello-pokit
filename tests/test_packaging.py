import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import build
import manage


class PackagingTests(unittest.TestCase):
    def test_offline_bundle_is_complete_and_manifest_matches(self):
        with tempfile.TemporaryDirectory() as directory:
            output = build.build(ROOT, Path(directory) / "bundle")
            manifest = json.loads((output / "MANIFEST.sha256.json").read_text())
            for name, expected in manifest.items():
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), expected, name)
            self.assertTrue((output / "qml/HelloMotion.js").is_file())
            self.assertTrue((output / "assets/fonts/noctalia-tabler.ttf").is_file())
            self.assertFalse((output / "qml/palette.json").exists())
            self.assertFalse(any("__pycache__" in name or name.endswith(".dll") for name in manifest))
            first = manifest
            build.build(ROOT, output)
            self.assertEqual(first, json.loads((output / "MANIFEST.sha256.json").read_text()))

    def test_install_saves_previous_runtime_and_does_not_activate(self):
        with tempfile.TemporaryDirectory(prefix="hello space % ") as directory:
            base = Path(directory)
            paths = manage.Paths(base / "config/quickshell/hello-polkit", base / "config/systemd/user",
                                 base / "config/noctalia/zz-hello-polkit.toml", base / "state/backups")
            paths.target.mkdir(parents=True)
            (paths.target / "old.qml").write_text("old installation")
            (paths.target / "palette.json").write_text('{"primary":"#123456"}')
            paths.units.mkdir(parents=True)
            (paths.units / "hello-polkit.service").write_text("old service")
            with patch.object(manage, "systemctl") as service:
                backup = manage.install(ROOT, paths, "/usr/bin/qs", "/usr/lib/mate/agent")
                service.assert_not_called()
            self.assertEqual((backup / "0/old.qml").read_text(), "old installation")
            self.assertEqual((backup / "1").read_text(), "old service")
            self.assertEqual((paths.target / "qml/palette.json").read_text(), '{"primary":"#123456"}')
            self.assertFalse((paths.target / "old.qml").exists())
            config = tomllib.loads(paths.fragment.read_text())
            self.assertFalse(config["shell"]["polkit_agent"])
            template = config["theme"]["templates"]["user"]["hello_polkit"]
            self.assertEqual(template["input_path"], str(paths.target / "qml/palette.template.json"))
            self.assertTrue(Path(template["input_path"]).is_file())
            unit = (paths.units / "hello-polkit.service").read_text()
            self.assertIn("OnFailure=mate-polkit.service", unit)
            self.assertIn(manage.unit_arg(paths.target / "shell.qml"), unit)

    def test_xdg_and_noctalia_overrides(self):
        with patch.dict(os.environ, {"XDG_CONFIG_HOME": "/tmp/hp-config", "XDG_STATE_HOME": "/tmp/hp-state",
                                     "NOCTALIA_CONFIG_HOME": "/tmp/hp-noctalia"}):
            paths = manage.Paths.current()
        self.assertEqual(paths.target, Path("/tmp/hp-config/quickshell/hello-polkit"))
        self.assertEqual(paths.fragment, Path("/tmp/hp-noctalia/noctalia/zz-hello-polkit.toml"))
        self.assertEqual(paths.backups, Path("/tmp/hp-state/hello-polkit/backups"))

    def test_systemd_path_quoting(self):
        self.assertEqual(manage.unit_arg('/a b/%h/$x/"c'), '"/a b/%%h/$$x/\\"c"')
        with self.assertRaises(ValueError):
            manage.unit_arg("/a\nb")

    def test_failed_activation_restores_mate(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = manage.Paths(Path(directory), Path(directory), Path(directory), Path(directory))
            (paths.target / "qml").mkdir()
            (paths.target / "shell.qml").touch()
            with patch.dict(os.environ, {"WAYLAND_DISPLAY": "test"}), \
                    patch.object(manage.shutil, "which", return_value=None), \
                    patch.object(manage, "systemctl") as service, \
                    patch.object(manage, "status", return_value={"registered": False}), \
                    patch.object(manage.time, "monotonic", side_effect=[0, 10]), \
                    patch.object(manage, "recover") as recover:
                with self.assertRaises(RuntimeError):
                    manage.activate("/usr/bin/qs", paths)
                recover.assert_called_once()
                self.assertNotIn(unittest.mock.call("enable", "hello-polkit.service"), service.call_args_list)


class ThemeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("style_settings", ROOT / "qml/style-settings.py")
        cls.style = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.style)

    def test_missing_noctalia_uses_defaults(self):
        with patch.object(self.style.shutil, "which", return_value=None):
            self.assertEqual(self.style.resolved_style(), {"fontFamily": "sans-serif", "cornerRadiusScale": 1.0})

    def test_theme_settings_validate_and_clamp(self):
        with patch.object(self.style.shutil, "which", return_value="/bin/noctalia"), \
                patch.object(self.style.subprocess, "run") as run:
            run.return_value.stdout = '[shell]\nfont_family="Example Font"\ncorner_radius_scale=9\n'
            self.assertEqual(self.style.resolved_style(), {"fontFamily": "Example Font", "cornerRadiusScale": 2.0})
            run.return_value.stdout = '[shell]\ncorner_radius_scale=true\n'
            with self.assertRaises(ValueError):
                self.style.resolved_style()


if __name__ == "__main__":
    unittest.main()
