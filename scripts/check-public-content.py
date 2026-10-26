#!/usr/bin/env python3
"""Small pre-publication check. Reports paths and rule names, never matched values.

This is a guardrail, not a replacement for reviewing the exact files to publish.
Only scans this project's source/docs; never follows symlinks or reads user caches.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
ignored = {".git", ".build", ".swiftpm", "dist", "__pycache__"}
blocked_suffixes = {".har", ".pcap", ".pcapng", ".p12", ".p8", ".pem", ".key", ".mobileprovision"}
patterns = {
    "private-key": re.compile(r"-----BEGIN (?:[A-Z ]+)?PRIVATE KEY-----"),
    "github-token": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})\b"),
    "literal-bearer-token": re.compile(r"Bearer\s+[A-Za-z0-9][A-Za-z0-9._~+/=-]{24,}", re.I),
    "private-workspace-path": re.compile(r"/(?:Users|home)/[^/\s]+/|" + "/var/" + "folders/"),
}
findings = []
checked = 0
for path in sorted(root.rglob("*")):
    relative = path.relative_to(root)
    if any(part in ignored for part in relative.parts):
        continue
    if path.is_symlink():
        findings.append(f"{relative}: symlink requires manual review")
        continue
    if not path.is_file():
        continue
    if path.name == ".env" or path.name.startswith(".env.") or path.suffix.lower() in blocked_suffixes:
        findings.append(f"{relative}: private-file-type")
        continue
    if path.name == "readings.json":
        findings.append(f"{relative}: health-cache-file")
        continue
    checked += 1
    if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".gif", ".icns"}:
        continue  # Public images must additionally be reviewed as synthetic data.
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeError:
        findings.append(f"{relative}: unexpected-binary-file")
        continue
    for number, line in enumerate(lines, 1):
        for name, pattern in patterns.items():
            if pattern.search(line):
                findings.append(f"{relative}:{number}: {name}")

if findings:
    print("Public-content review required (values omitted):")
    print("\n".join(findings))
    sys.exit(1)
print(f"Public-content pattern check passed: {checked} files. Review images and publication scope separately.")
