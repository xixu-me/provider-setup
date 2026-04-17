import pathlib
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


class ConfigDirTests(unittest.TestCase):
    def test_codex_ps1_prefers_codex_home(self) -> None:
        content = (REPO_ROOT / "codex.ps1").read_text(encoding="utf-8")

        self.assertIn('$ConfigDir = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME))', content)
        self.assertIn('$env:CODEX_HOME', content)
        self.assertIn('Join-Path $HOME ".codex"', content)

    def test_codex_sh_prefers_codex_home(self) -> None:
        content = (REPO_ROOT / "codex.sh").read_text(encoding="utf-8")

        self.assertIn('CONFIG_DIR="${CODEX_HOME:-$HOME/.codex}"', content)

    def test_claude_ps1_prefers_claude_config_dir(self) -> None:
        content = (REPO_ROOT / "claude.ps1").read_text(encoding="utf-8")

        self.assertIn('$SettingsDir = if ([string]::IsNullOrWhiteSpace($env:CLAUDE_CONFIG_DIR))', content)
        self.assertIn('$env:CLAUDE_CONFIG_DIR', content)
        self.assertIn('Join-Path $HOME ".claude"', content)

    def test_claude_sh_prefers_claude_config_dir(self) -> None:
        content = (REPO_ROOT / "claude.sh").read_text(encoding="utf-8")

        self.assertIn('SETTINGS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"', content)

    def test_readme_documents_environment_overrides(self) -> None:
        content = (REPO_ROOT / "README.md").read_text(encoding="utf-8")

        self.assertIn("`CODEX_HOME`", content)
        self.assertIn("`CLAUDE_CONFIG_DIR`", content)


if __name__ == "__main__":
    unittest.main()
