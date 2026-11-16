#!/usr/bin/env python3
"""Check archive previews using disposable archives and the installed 7-Zip."""

import bz2
import gzip
import io
import lzma
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tarfile
import tempfile
import unittest
import zipfile
import zlib


ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "zsh/helpers/fzf-tab-preview-helper"
SEVENZIP = shutil.which("7zz") or shutil.which("7z")
ZSH = shutil.which("zsh")


class ArchivePreviewTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="dotsh-archive-preview-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.environment = dict(
            os.environ,
            HOME=str(self.home),
            ZDOTDIR=str(self.home),
            PATH=str(self.bin) + ":/usr/bin:/bin:/usr/sbin:/sbin",
            REAL_SEVENZIP=SEVENZIP or "",
            ARCHIVER_CALLS=str(self.root / "calls"),
        )
        self.member = "nested/member with spaces.txt"
        self.content = b"archive preview fixture\n"
        self.archive = self.root / "-archive with spaces.zip"
        with zipfile.ZipFile(self.archive, "w") as stream:
            stream.writestr(self.member, self.content)

    def install_wrapper(self, name):
        if not SEVENZIP:
            self.skipTest("7zz or 7z is required for real archive tests")
        wrapper = self.bin / name
        wrapper.write_text(
            '#!/bin/sh\nprintf "%s\\n" "${0##*/}" >> "$ARCHIVER_CALLS"\n'
            'exec "$REAL_SEVENZIP" "$@"\n'
        )
        wrapper.chmod(0o755)

    def preview(self, archive=None):
        result = subprocess.run(
            [ZSH, "-df", str(PREVIEW), str(archive or self.archive)],
            env=self.environment, text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertLessEqual(len(result.stdout.splitlines()), 300)
        return result.stdout

    def assert_member_listing(self, output, member, size=None):
        # Each fixture has one member: any banner/header/footer adds rows.
        self.assertEqual(len(output.splitlines()), 1, output)
        row = output.rstrip("\n")
        self.assertTrue(row.endswith(member), output)
        self.assertRegex(row[:-len(member)], r"\d", output)
        if size is not None:
            self.assertRegex(row, rf"\s{size}\s+(?:\d+\s+)?{re.escape(member)}$", output)

    def test_missing_archiver_has_readable_feedback(self):
        # Hide possible system-installed 7-Zip executables as well.
        self.environment["PATH"] = str(self.bin)
        (self.bin / "file").symlink_to(shutil.which("file"))
        self.assertIn("7-Zip is required", self.preview())

    def test_7zz_is_preferred(self):
        self.install_wrapper("7zz")
        self.install_wrapper("7z")
        self.assert_member_listing(self.preview(), self.member, len(self.content))
        self.assertEqual((self.root / "calls").read_text().splitlines(), ["7zz"])

    def test_7z_compatibility(self):
        self.install_wrapper("7z")
        self.assert_member_listing(self.preview(), self.member, len(self.content))
        self.assertEqual((self.root / "calls").read_text().splitlines(), ["7z"])

    def test_tar_and_compressed_tar_list_inner_members(self):
        self.install_wrapper("7zz")
        for suffix, mode in (("tar", "w"), ("tar.gz", "w:gz"), ("tar.xz", "w:xz"), ("tar.bz2", "w:bz2")):
            with self.subTest(suffix=suffix):
                archive = self.root / ("archive with spaces." + suffix)
                with tarfile.open(archive, mode) as stream:
                    item = tarfile.TarInfo(self.member)
                    item.size = len(self.content)
                    stream.addfile(item, io.BytesIO(self.content))
                self.assert_member_listing(self.preview(archive), self.member, len(self.content))
                if suffix != "tar":
                    renamed = self.root / (suffix + ".data")
                    archive.rename(renamed)
                    self.assert_member_listing(self.preview(renamed), self.member, len(self.content))
        self.assertFalse((self.root / "nested").exists())

    def test_single_compressed_files_list_the_container(self):
        self.install_wrapper("7zz")
        for suffix, compress in (("gz", gzip.compress), ("xz", lzma.compress), ("bz2", bz2.compress)):
            with self.subTest(suffix=suffix):
                archive = self.root / ("single file." + suffix)
                archive.write_bytes(compress(self.content))
                output = self.preview(archive)
                self.assertIn("single file", output)
                self.assertNotIn("unavailable", output)
                self.assertEqual(len(output.splitlines()), 1, output)

    def test_7z_and_encrypted_headers(self):
        self.install_wrapper("7zz")
        source = self.root / "member.txt"
        source.write_bytes(self.content)
        for encrypted in (False, True):
            with self.subTest(encrypted=encrypted):
                archive = self.root / ("encrypted.7z" if encrypted else "normal.7z")
                arguments = [SEVENZIP, "a", "-t7z"]
                if encrypted:
                    arguments += ["-mhe=on", "-pfixture-password"]
                subprocess.run(
                    arguments + ["--", str(archive), str(source)],
                    check=True, capture_output=True, timeout=10,
                )
                output = self.preview(archive)
                if encrypted:
                    self.assertIn("Archive preview unavailable", output)
                else:
                    self.assert_member_listing(output, source.name, len(self.content))

    def test_rar_listing(self):
        self.install_wrapper("7zz")
        # A RAR 4 fixture with one stored member and CRC-protected headers.
        def header(body):
            return struct.pack("<H", zlib.crc32(body) & 0xFFFF) + body

        name = self.member.encode()
        main = header(struct.pack("<BHHHI", 0x73, 0, 13, 0, 0))
        member = header(struct.pack(
            "<BHHIIBIIBBHI", 0x74, 0x8000, 32 + len(name),
            len(self.content), len(self.content), 3, zlib.crc32(self.content),
            0, 20, 0x30, len(name), 0o100644,
        ) + name)
        end = header(struct.pack("<BHH", 0x7B, 0x4000, 7))
        archive = self.root / "stored.rar"
        archive.write_bytes(b"Rar!\x1a\x07\x00" + main + member + self.content + end)
        self.assert_member_listing(self.preview(archive), self.member, len(self.content))

    def test_empty_archive_has_no_banner_or_summary(self):
        self.install_wrapper("7zz")
        with zipfile.ZipFile(self.archive, "w"):
            pass
        self.assertEqual(self.preview().strip(), "")

    def test_corrupt_archive_has_readable_feedback(self):
        self.install_wrapper("7zz")
        self.archive.write_bytes(self.archive.read_bytes()[:-10])
        self.assertIn("Archive preview unavailable", self.preview())

    def test_large_listing_is_truncated_without_failure(self):
        self.install_wrapper("7zz")
        with zipfile.ZipFile(self.archive, "w") as stream:
            for index in range(500):
                stream.writestr(f"member-{index:04}.txt", self.content)
        rows = self.preview().splitlines()
        self.assertEqual(len(rows), 300)
        for index, row in enumerate(rows):
            self.assertTrue(row.endswith(f"member-{index:04}.txt"), row)


if __name__ == "__main__":
    unittest.main()
