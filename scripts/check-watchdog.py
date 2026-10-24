#!/usr/bin/env python3
"""Audit helper lifecycle without posting any CGEvents or requesting permissions."""
import subprocess
import sys
import time

executable = sys.argv[1]
args = [executable, "--release-watchdog", "--watchdog-audit"]
p = subprocess.run(args, input="k 49 1\nm 0 1\nk 55 1\nk 55 0\n", text=True, capture_output=True, timeout=3, check=True)
assert "key(49, false)" in p.stdout, p
assert "mouseButton(0, false)" in p.stdout, p
assert "key(55, false)" not in p.stdout, p
p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
p.stdin.write("k 49 1\n")
p.stdin.flush()
# Keep stdin open to mimic a hung parent; helper must time out and exit.
p.wait(timeout=3)
output = p.stdout.read()
p.stdin.close()
assert "key(49, false)" in output, output
assert p.returncode == 0, p.returncode
print("Watchdog EOF release and stalled-parent timeout: PASS (audit only; no CGEvents posted)")
