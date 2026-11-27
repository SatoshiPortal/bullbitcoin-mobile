"""Print only allowlisted diagnostic events from a verbose Flutter test run."""

import hashlib
import os
import re
import subprocess
import sys
import time


def fingerprint():
    names = re.compile(
        r"ANDROID_HOME|ANDROID_NDK[A-Z0-9_]*|HOME|LIBCLANG_PATH|PATH|TEMP|TMP|TMPDIR"
        r"|HTTPS?_PROXY|NO_PROXY|no_proxy|(?:CARGO|RUSTUP|CCACHE|NIX)_[A-Z0-9_]*"
    )
    for name, value in sorted(os.environ.items()):
        if names.fullmatch(name):
            print(name, hashlib.sha256(os.fsencode(value)).hexdigest()[:12])


def trace(command):
    started = time.monotonic()
    hook = re.compile(
        r"(Running|Rerunning|Skipping) (build|link) for "
        r"(objective_c|sqlite3|bdk_dart|onion|rust_bindings) in .+"
    )
    prefix = re.compile(r"^\[ *(?:[+\d]+ ms)?\] ")
    first_loading = False
    with subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, errors="replace", bufsize=1,
    ) as process:
        for line in process.stdout:
            line = prefix.sub("", line.rstrip())
            elapsed = time.monotonic() - started
            match = hook.fullmatch(line)
            if match:
                status, phase, package = match.groups()
                reason = ""
                if status == "Rerunning":
                    reason = " (other invalidation)"
                    for marker, category in (
                        (". Hook Dart sources and ", "hook recompiled"),
                        (". Input changed", "input changed"),
                        (". File contents changed", "file contents changed"),
                        (". Directory contents changed", "directory contents changed"),
                        (". Environment variable", "environment changed"),
                    ):
                        if marker in line:
                            reason = f" ({category})"
                            break
                print(f"{elapsed:.3f}s {status} {phase} for {package}{reason}", flush=True)
            elif line in (
                "Running build hooks for linux_x64.",
                "Running build hooks for linux_x64 done.",
                "Running link hooks for linux_x64.",
                "Running link hooks for linux_x64 done.",
            ):
                print(f"{elapsed:.3f}s {line}", flush=True)
            elif not first_loading and re.match(r"^\d+:\d+ \+0: loading\s", line):
                print(f"{elapsed:.3f}s first test loading", flush=True)
                first_loading = True
            elif match := re.fullmatch(r"Compiling .+ took (\d{1,9})ms", line):
                print(f"{elapsed:.3f}s test compilation took {match[1]}ms", flush=True)
    return process.returncode if process.returncode >= 0 else 128 - process.returncode


if __name__ == "__main__":
    if sys.argv[1:] == ["--fingerprint"]:
        fingerprint()
    else:
        sys.exit(trace(sys.argv[1:]))
