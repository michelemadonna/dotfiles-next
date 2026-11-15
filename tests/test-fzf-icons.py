#!/usr/bin/env python3
"""Verify eza decoration while retaining exact picker/completion values."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")
EZA = shutil.which("eza")
FZF = ROOT / "zsh/vendor/packages/fzf/bin/fzf"


class FzfIconsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="dotsh-fzf-icons-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.directory = self.base / "files with spaces"
        self.directory.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.home = self.base / "home"
        self.home.mkdir()
        self.names = ["read me.md", "中文.py", "--leading", "tab\tname.txt", "quote'\"[a]$(literal).txt", "back\\slash.txt"]
        for name in self.names:
            (self.directory / name).write_text("fixture\n")
        (self.directory / "directory with spaces").mkdir()
        (self.directory / "file-link").symlink_to(self.directory / self.names[0])
        (self.directory / "dir-link").symlink_to(self.directory / "directory with spaces")
        self.environment = dict(
            os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
            PATH=str(self.bin) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            ICON_HELPER=str(ROOT / "zsh/helpers/fzf-icons.zsh"),
            STATE_HELPER=str(ROOT / "zsh/helpers/fzf-tab-state-helper"),
            FTB_DIRECTORY=str(ROOT / "zsh/vendor/packages/fzf-tab"),
            TEST_DIRECTORY=str(self.directory), DOTSH_USE_FZF="true",
            EZA_CALLS=str(self.base / "eza-calls"), REAL_EZA=EZA or "",
        )
        if EZA:
            self.wrapper = self.bin / "eza"
            self.wrapper.write_text(
                '#!/bin/sh\nprintf "called\\n" >> "$EZA_CALLS"\n'
                'exec "$REAL_EZA" "$@"\n'
            )
            self.wrapper.chmod(0o755)

    def shell(self, script, data=None):
        result = subprocess.run(
            [ZSH, "-dfc", 'source "$ICON_HELPER" || exit\n' + script],
            cwd=self.directory, env=self.environment, input=data,
            capture_output=True, timeout=15,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
        self.assertEqual(result.stderr, b"")
        return result.stdout

    def records(self, names):
        output = self.shell("dotsh_fzf_icon_records", "".join(name + "\n" for name in names).encode())
        records = [line.split(b"\0") for line in output.split(b"\n")[:-1]]
        self.assertEqual([record[0].decode() for record in records], names)
        self.assertTrue(all(len(record) == 3 and record[2] == b"" for record in records))
        return records, output

    def require_eza(self):
        if not EZA:
            self.skipTest("eza is required to verify real icons")

    def test_icons_match_eza_and_one_batch(self):
        self.require_eza()
        names = [self.names[0], "directory with spaces", "file-link", "dir-link"]
        records, _ = self.records(names)
        for name, record in zip(names, records):
            expected = subprocess.check_output(
                [EZA, "-1dX", "--icons=always", "--color=never", "--hyperlink=never", "--no-quotes", "--", name],
                cwd=self.directory, env=dict(self.environment, EZA_ICON_SPACING="1"),
            ).split(b" ", 1)[0] + b" "
            self.assertEqual(record[1], expected)
        self.assertEqual((self.base / "eza-calls").read_text().splitlines(), ["called"])

    def test_special_names_are_returned_exactly(self):
        self.require_eza()
        _, data = self.records(self.names)
        for name in self.names:
            result = subprocess.run(
                [str(FZF), "--delimiter=\\x00", "--with-nth=2,1", "--nth=2", "--accept-nth=1", "--exact", "--no-extended", "--filter=" + name],
                input=data, capture_output=True, timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, name.encode() + b"\n")

    def test_search_excludes_the_icon(self):
        self.require_eza()
        records, data = self.records([self.names[0]])
        result = subprocess.run(
            [str(FZF), "--delimiter=\\x00", "--with-nth=2,1", "--nth=2", "--accept-nth=1", "--filter=" + records[0][1].decode().strip()],
            input=data, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, b"")

    def test_absolute_and_missing_paths(self):
        self.require_eza()
        existing = str(self.directory / self.names[0])
        records, _ = self.records([existing, "missing-file"])
        self.assertTrue(records[0][1])
        self.assertEqual(records[1][1], b"")

    def test_no_eza_retains_values(self):
        self.environment["PATH"] = str(self.base / "absent-bin")
        records, _ = self.records(self.names)
        self.assertTrue(all(record[1] == b"" for record in records))

    def test_failed_eza_retains_values(self):
        wrapper = self.bin / "eza"
        wrapper.write_text("#!/bin/sh\nexit 1\n")
        wrapper.chmod(0o755)
        records, _ = self.records(self.names)
        self.assertTrue(all(record[1] == b"" for record in records))

    def test_disabled_fzf_does_not_invoke_eza(self):
        self.environment["DOTSH_USE_FZF"] = "false"
        records, _ = self.records(self.names)
        self.assertTrue(all(record[1] == b"" for record in records))
        self.assertFalse((self.base / "eza-calls").exists())

    def test_hidden_reload_keeps_original_order_and_paths(self):
        (self.directory / ".hidden-file").touch()
        (self.directory / ".hidden-dir").mkdir()
        state = self.base / "state/hidden"
        for value in ("off", "on"):
            state.parent.mkdir(exist_ok=True)
            state.write_text(value + "\n")
            for action in ("list-files", "list-directories"):
                with self.subTest(value=value, action=action):
                    command = [ZSH, "-df", str(ROOT / "zsh/helpers/fzf-tab-state-helper"), action, str(state)]
                    raw = subprocess.check_output(command, cwd=self.directory, env=self.environment)
                    decorated = subprocess.check_output(command + ["--icons"], cwd=self.directory, env=self.environment)
                    paths = b"\n".join(line.split(b"\0")[0] for line in decorated.split(b"\n")[:-1]) + b"\n"
                    self.assertEqual(paths, raw)
                    self.assertEqual(b".hidden" in decorated, value == "on")

    def test_completion_adapter_preserves_metadata_and_groups(self):
        self.require_eza()
        script = r'''
setopt extended_glob
zmodload zsh/zle zsh/zleparameter
autoload -Uz compinit
compinit -D -i
source "$FTB_DIRECTORY/fzf-tab.zsh" || exit
typeset -ga _ftb_groups=(files options) _ftb_group_colors=($'\e[31m' $'\e[32m')
typeset -g _ftb_curcontext=:complete:fixture:
typeset -ga _ftb_compcap=(
  file-label$'\2<\0>\0group\0'1$'\0realdir\0'"$TEST_DIRECTORY/"$'\0word\0read\ me.md'
  dir-label$'\2<\0>\0group\0'1$'\0realdir\0'"$TEST_DIRECTORY/"$'\0word\0directory\ with\ spaces'
  flag-label$'\2<\0>\0group\0'2$'\0word\0--flag'
)
typeset -ga _ftb_complist=()
-ftb-generate-complist
print -r -- BASE
print -rl -- "${_ftb_complist[@]}"
dotsh_fzf_setup_icons || exit
dotsh_fzf_setup_icons || exit
-ftb-generate-complist
print -r -- ICONS
print -rl -- "${_ftb_complist[@]}"
'''
        output = self.shell(script)
        before, after = output.split(b"ICONS\n")
        original = before.removeprefix(b"BASE\n").splitlines()
        decorated = after.splitlines()
        self.assertEqual(len(original), 3)
        self.assertEqual(len(decorated), 3)
        for first, second in zip(original, decorated):
            old_fields = first.split(b"\0")
            new_fields = second.split(b"\0")
            self.assertEqual(new_fields[1:], old_fields[1:])
            if old_fields[1] == b"flag-label":
                self.assertEqual(second, first)
            else:
                self.assertTrue(new_fields[0].startswith(old_fields[0]))
                self.assertGreater(len(new_fields[0]), len(old_fields[0]))
        self.assertEqual((self.base / "eza-calls").read_text().splitlines(), ["called"])


if __name__ == "__main__":
    unittest.main()
