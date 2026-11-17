#!/usr/bin/env python3
"""Exercise real loaders and Git downloads using disposable local repositories."""

import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")
GIT = shutil.which("git")


class ShellPackagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="dotsh-packages-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "checkout with spaces"
        self.vendor = self.root / "zsh/vendor"
        self.packages = self.vendor / "packages"
        self.lockfile = self.vendor / "packages.lock"
        self.packages.mkdir(parents=True)
        self.lockfile.write_text("# name repository pinned-commit\n")
        for directory in ("runtime", "helpers", "home"):
            shutil.copytree(
                ROOT / "zsh" / directory,
                self.root / "zsh" / directory,
                ignore=shutil.ignore_patterns("*.zwc", ".zshenv*"),
            )
        shutil.copy(ROOT / "zsh/.zshenv.init", self.root / "zsh/.zshenv.init")
        shutil.copytree(ROOT / "zsh/vendor/patches", self.vendor / "patches")
        self.home = self.base / "home"
        self.home.mkdir()
        self.environment = dict(
            os.environ,
            HOME=str(self.home),
            ZDOTDIR=str(self.home),
            DOTFILES_DIR=str(self.root),
            XDG_CACHE_HOME=str(self.home / ".cache"),
            XDG_CONFIG_HOME=str(self.home / ".config"),
            XDG_DATA_HOME=str(self.home / ".local/share"),
            XDG_STATE_HOME=str(self.home / ".local/state"),
            GIT_CONFIG_GLOBAL=str(self.base / "gitconfig"),
            GIT_CONFIG_NOSYSTEM="1",
            GIT_ALLOW_PROTOCOL="file",
            GIT_AUTHOR_NAME="Fixture",
            GIT_AUTHOR_EMAIL="fixture@example.invalid",
            GIT_COMMITTER_NAME="Fixture",
            GIT_COMMITTER_EMAIL="fixture@example.invalid",
        )
        self.origin = self.base / "origin"
        self.git("init", "-q", "--initial-branch=main", str(self.origin))
        (self.origin / "init.zsh").write_text("typeset -g DOTSH_TEST_PLUGIN=first\n")
        (self.origin / "functions").mkdir()
        (self.origin / "functions/dotsh_fixture_function").write_text("print autoloaded\n")
        nested = self.origin / "plugins/nested"
        nested.mkdir(parents=True)
        (nested / "nested.plugin.zsh").write_text("typeset -g DOTSH_TEST_PLUGIN=nested\n")
        self.first = self.commit("first")
        (self.origin / "init.zsh").write_text("typeset -g DOTSH_TEST_PLUGIN=second\n")
        self.latest = self.commit("second")
        for name in ("plugin", "other"):
            self.git(
                "config", "--global", "--add",
                f"url.{self.origin.as_uri()}.insteadOf",
                f"https://github.com/fixture/{name}.git",
            )

    def git(self, *arguments):
        return subprocess.check_output(
            [GIT, *arguments], env=self.environment, text=True, stderr=subprocess.PIPE
        ).strip()

    def commit(self, message):
        self.git("-C", str(self.origin), "add", ".")
        self.git("-C", str(self.origin), "commit", "-qm", message)
        return self.git("-C", str(self.origin), "rev-parse", "HEAD")

    def register(self, revision, name="plugin", repository=None):
        repository = repository or self.origin.as_uri()
        with self.lockfile.open("a") as stream:
            stream.write(f"{name} {repository} {revision}\n")

    def shell_command(self, script):
        return [ZSH, "-dfc", 'source "$DOTFILES_DIR/zsh/runtime/dotsh-startup.zsh" || exit\n' + script]

    def shell(self, script, success=True):
        result = subprocess.run(
            self.shell_command(script), env=self.environment, cwd=self.home,
            text=True, capture_output=True, timeout=30,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def head(self, name):
        return self.git("-C", str(self.packages / name), "rev-parse", "HEAD")

    def test_pinned_plain_load_and_autoload(self):
        self.register(self.first)
        result = self.shell('dotsh_load plugin || exit; print "$DOTSH_TEST_PLUGIN"; dotsh_fixture_function')
        self.assertEqual(result.stdout.splitlines(), ["first", "autoloaded"])
        self.assertEqual(self.head("plugin"), self.first)
        self.assertFalse((self.packages / "plugin/init.zsh.zwc").exists())

    def test_compiled_github_identifier_uses_registered_directory(self):
        self.register(self.first, repository="https://github.com/fixture/plugin.git")
        result = self.shell('dotsh_load --compile fixture/plugin || exit; print "$DOTSH_TEST_PLUGIN"')
        self.assertEqual(result.stdout.strip(), "first")
        self.assertTrue((self.packages / "plugin/init.zsh.zwc").exists())
        self.assertFalse((self.packages / "fixture/plugin").exists())

    def test_github_match_precedes_unrelated_package_prefix(self):
        self.register(self.latest, name="fixture")
        self.register(self.first, repository="https://github.com/fixture/plugin.git")
        self.shell("dotsh_load fixture/plugin")
        self.assertEqual(self.head("plugin"), self.first)
        self.assertFalse((self.packages / "fixture").exists())

    def test_new_repository_cannot_overwrite_registered_package_namespace(self):
        self.register(self.first, name="fixture")
        result = self.shell("dotsh_load fixture/plugin", success=False)
        self.assertIn("directory overlaps fixture", result.stderr)
        self.assertFalse((self.packages / "fixture").exists())

    def test_distinct_lock_name_resolves_repository_namespace_overlap(self):
        self.register(self.latest, name="fixture")
        self.register(self.first, name="separate", repository="https://github.com/fixture/plugin.git")
        self.shell("dotsh_load fixture/plugin")
        self.assertEqual(self.head("separate"), self.first)

    def test_new_github_repository_is_pinned(self):
        result = self.shell('dotsh_load -c fixture/plugin || exit; print "$DOTSH_TEST_PLUGIN"')
        self.assertEqual(result.stdout.strip(), "second")
        self.assertEqual(self.head("fixture/plugin"), self.latest)
        self.assertIn(
            f"fixture/plugin https://github.com/fixture/plugin.git {self.latest}\n",
            self.lockfile.read_text(),
        )

    def test_absent_lockfile_is_created(self):
        self.lockfile.unlink()
        self.shell("dotsh_load fixture/plugin")
        self.assertIn(self.latest, self.lockfile.read_text())

    def test_missing_and_latest_revisions_are_recorded(self):
        for revision in ("", "latest"):
            with self.subTest(revision=revision):
                name = "plugin" if not revision else "other"
                self.register(revision, name=name)
                self.shell(f"dotsh_load {name}")
                self.assertIn(f"{name} {self.origin.as_uri()} {self.latest}\n", self.lockfile.read_text())

    def test_lockfile_last_line_without_newline(self):
        self.lockfile.write_text(f"plugin {self.origin.as_uri()} {self.first}")
        self.shell("dotsh_load plugin")
        self.assertEqual(self.head("plugin"), self.first)

    def test_new_installation_uses_recorded_commit(self):
        self.shell("dotsh_load fixture/plugin")
        shutil.rmtree(self.packages / "fixture/plugin")
        (self.origin / "init.zsh").write_text("typeset -g DOTSH_TEST_PLUGIN=third\n")
        self.commit("third")
        result = self.shell('dotsh_load fixture/plugin || exit; print "$DOTSH_TEST_PLUGIN"')
        self.assertEqual(result.stdout.strip(), "second")
        self.assertEqual(self.head("fixture/plugin"), self.latest)

    def test_existing_packages_load_without_git_or_lock_writes(self):
        self.register(self.first, repository="https://github.com/fixture/plugin.git")
        self.shell("dotsh_load plugin")
        before = self.lockfile.read_bytes()
        test_bin = self.base / "bin"
        test_bin.mkdir()
        executable = test_bin / "git"
        executable.write_text('#!/bin/sh\nprintf attempted >&2\nexit 99\n')
        executable.chmod(0o755)
        self.environment["PATH"] = str(test_bin) + ":" + self.environment["PATH"]
        self.shell('dotsh_load plugin fixture/plugin "$DOTSH_PACKAGES/plugin"')
        self.assertEqual(self.lockfile.read_bytes(), before)

    def test_absolute_nested_path_installs_parent(self):
        self.register(self.first)
        result = self.shell('dotsh_load -c "$DOTSH_PACKAGES/plugin/plugins/nested" || exit; print "$DOTSH_TEST_PLUGIN"')
        self.assertEqual(result.stdout.strip(), "nested")
        self.assertEqual(self.head("plugin"), self.first)

    def test_relative_local_directory_loads(self):
        directory = self.home / "local-plugin"
        directory.mkdir()
        (directory / "local-plugin.zsh").write_text("typeset -g DOTSH_TEST_PLUGIN=local\n")
        result = self.shell('dotsh_load -c -- ./local-plugin || exit; print "$DOTSH_TEST_PLUGIN"')
        self.assertEqual(result.stdout.strip(), "local")

    def test_missing_local_source_and_unknown_alias_fail_without_download(self):
        for command in (
            'dotsh_load "$HOME/missing"',
            'dotsh_source "$DOTSH_PACKAGES/plugin/init.zsh"',
            'dotsh_load unknown',
            'dotsh_load ../outside',
        ):
            with self.subTest(command=command):
                self.shell(command, success=False)
        self.assertFalse((self.packages / ".prepare.lock").exists())

    def test_failed_fetch_preserves_lockfile_and_cleans_staging(self):
        self.register("0" * 40)
        before = self.lockfile.read_bytes()
        self.shell("dotsh_load plugin", success=False)
        self.assertEqual(self.lockfile.read_bytes(), before)
        self.assertFalse((self.packages / "plugin").exists())
        self.assertEqual(list(self.packages.glob(".prepare.*")), [self.packages / ".prepare.lock"])

    def test_failed_lock_write_leaves_package_retryable(self):
        if os.geteuid() == 0:
            self.skipTest("Requires an unprivileged filesystem user")
        self.register("")
        before = self.lockfile.read_bytes()
        self.vendor.chmod(0o555)
        try:
            self.shell("dotsh_load plugin", success=False)
        finally:
            self.vendor.chmod(0o755)
        self.assertEqual(self.lockfile.read_bytes(), before)
        self.assertFalse((self.packages / "plugin").exists())
        self.shell("dotsh_load plugin")
        self.assertEqual(self.head("plugin"), self.latest)

    def test_failed_publication_restores_previous_checkout(self):
        self.register(self.first)
        self.shell("dotsh_load plugin")
        self.lockfile.write_text(f"plugin {self.origin.as_uri()} {self.latest}\n")
        test_bin = self.home / ".local/bin"
        test_bin.mkdir(parents=True)
        wrapper = test_bin / "mv"
        wrapper.write_text(
            '#!/bin/sh\ncase "$2" in\n'
            '  */.prepare.*)\n'
            f'    if [ "$3" = {shlex.quote(str(self.packages / "plugin"))} ] && '
            '[ "${2%.previous}" = "$2" ]; then exit 1; fi\n'
            '    ;;\nesac\n'
            f'exec {shlex.quote(shutil.which("mv"))} "$@"\n'
        )
        wrapper.chmod(0o755)
        self.environment["PATH"] = str(test_bin) + ":" + self.environment["PATH"]
        self.shell(
            'source "$DOTFILES_DIR/zsh/helpers/shell-packages.zsh"; '
            'dotsh_prepare_package plugin install',
            success=False,
        )
        self.assertEqual(self.head("plugin"), self.first)
        self.assertEqual(list(self.packages.glob(".prepare.*")), [self.packages / ".prepare.lock"])

    def test_unsafe_lockfile_destination_is_rejected(self):
        self.register(self.first, name="../../escape", repository="https://github.com/fixture/plugin.git")
        self.shell("dotsh_load fixture/plugin", success=False)
        self.assertFalse((self.root / "zsh/escape").exists())
        self.assertFalse((self.packages / ".prepare.lock").exists())

    def test_concurrent_loaders_share_one_download(self):
        test_bin = self.home / ".local/bin"
        test_bin.mkdir(parents=True)
        log = self.base / "fetches"
        wrapper = test_bin / "git"
        wrapper.write_text(
            '#!/bin/sh\nif [ "$3" = fetch ]; then\n'
            f'  printf "fetch\\n" >> {shlex.quote(str(log))}\n'
            '  sleep 0.2\nfi\n'
            f'exec {shlex.quote(GIT)} "$@"\n'
        )
        wrapper.chmod(0o755)
        self.environment["PATH"] = str(test_bin) + ":" + self.environment["PATH"]
        processes = [
            subprocess.Popen(
                self.shell_command('dotsh_load -c fixture/plugin || exit; print "$DOTSH_TEST_PLUGIN"'),
                env=self.environment, cwd=self.home, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            for _ in range(2)
        ]
        for process in processes:
            stdout, stderr = process.communicate(timeout=30)
            self.assertEqual(process.returncode, 0, stdout + stderr)
            self.assertEqual(stdout.strip(), "second")
        self.assertEqual(self.lockfile.read_text().count("fixture/plugin "), 1)
        self.assertEqual(self.head("fixture/plugin"), self.latest)
        self.assertEqual(log.read_text().splitlines(), ["fetch"])

    def test_installer_and_loader_share_preparation_lock(self):
        self.register("latest", name="fixture/plugin", repository="https://github.com/fixture/plugin.git")
        processes = [
            subprocess.Popen(
                command, env=self.environment, cwd=self.home, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            for command in (
                self.shell_command("dotsh_load fixture/plugin"),
                [ZSH, "-df", str(self.root / "zsh/helpers/shell-packages.zsh")],
            )
        ]
        for process in processes:
            stdout, stderr = process.communicate(timeout=30)
            self.assertEqual(process.returncode, 0, stdout + stderr)
        self.assertEqual(self.head("fixture/plugin"), self.latest)
        self.assertEqual(self.lockfile.read_text().count("fixture/plugin "), 1)

    def test_concurrent_different_packages_preserve_both_lock_entries(self):
        processes = [
            subprocess.Popen(
                self.shell_command(f"dotsh_load fixture/{name}"), env=self.environment,
                cwd=self.home, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            for name in ("plugin", "other")
        ]
        for process in processes:
            stdout, stderr = process.communicate(timeout=30)
            self.assertEqual(process.returncode, 0, stdout + stderr)
        self.assertEqual(self.head("fixture/plugin"), self.latest)
        self.assertEqual(self.head("fixture/other"), self.latest)
        self.assertEqual(len(self.lockfile.read_text().splitlines()), 3)

    def test_full_preparation_remains_idempotent(self):
        self.register(self.first)
        command = ["sh", str(self.root / "zsh/helpers/prepare-shell-dependencies.sh")]
        for _ in range(2):
            result = subprocess.run(command, env=self.environment, text=True, capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.head("plugin"), self.first)
        self.assertTrue((self.home / ".config/mise").is_symlink())


if __name__ == "__main__":
    unittest.main()
