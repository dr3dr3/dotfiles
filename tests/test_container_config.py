import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/link-container-config.py'

class ConfigTests(unittest.TestCase):
    def test_preserves_files_and_unfolds_directories_then_reruns_cleanly(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / 'home'
            home.mkdir()
            checkout = root / 'old-fish'
            checkout.mkdir()
            (checkout / 'config.fish').write_text('old config')
            (checkout / 'fish_variables').write_text('runtime state')
            (home / '.config').mkdir()
            (home / '.config/fish').symlink_to(checkout)
            (home / '.bashrc').write_text('# container initialization\n')
            with patch.object(Path, 'home', return_value=home), patch.dict(os.environ, {'XDG_CONFIG_HOME': str(home / '.config')}):
                runpy.run_path(str(SCRIPT))
                backups = list((home / '.config/dotfiles-backups').iterdir())
                runpy.run_path(str(SCRIPT))
                self.assertEqual(backups, list((home / '.config/dotfiles-backups').iterdir()))
            self.assertFalse((home / '.config/fish').is_symlink())
            self.assertTrue((home / '.config/fish/config.fish').is_symlink())
            (home / '.config/fish/fish_variables').write_text('new runtime state')
            self.assertEqual((checkout / 'fish_variables').read_text(), 'runtime state')
            self.assertEqual((checkout / 'config.fish').read_text(), 'old config')
            self.assertFalse((checkout / 'config.fish').is_symlink())
            self.assertIn('# container initialization', (home / '.bashrc').read_text())
            self.assertEqual((home / '.bashrc').read_text().count('starship init bash'), 1)

if __name__ == '__main__':
    unittest.main()
