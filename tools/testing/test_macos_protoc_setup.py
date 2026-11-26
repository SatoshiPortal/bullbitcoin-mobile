import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[2] / '.github/workflows/upload-app-store-connect.yml'


class MacosProtocSetupTest(unittest.TestCase):
    def compiler_step(self):
        source = WORKFLOW.read_text()
        match = re.search(
            r'      - name: Install pinned protobuf compiler\n(.*?)(?=      - name:)',
            source, re.S,
        )
        self.assertIsNotNone(match, 'macOS must provision protoc before native hooks')
        return source, textwrap.dedent(match.group(1).split('run: |\n', 1)[1])

    def test_pinned_compiler_is_verified_before_extraction_and_hooks(self):
        source, step = self.compiler_step()
        self.assertLess(source.index('Install pinned protobuf compiler'), source.index('Install Flutter and generate sources'))
        for digest in (
            'e20b5f930e886da85e7402776a4959efb1ed60c57e72794bcade765e67abaa82',
            'db7e66ff7f9080614d0f5505a6b0ac488cf89a15621b6a361672d1332ec2e14e',
        ):
            self.assertIn(digest, step)
        self.assertIn('/v33.1/protoc-33.1-osx-${protoc_arch}.zip', step)
        self.assertLess(step.index('shasum -a 256 -c -'), step.index('unzip -q'))
        self.assertLess(step.index("= 'libprotoc 33.1'"), step.index('>> "$GITHUB_ENV"'))
        self.assertIn('include/google/protobuf/descriptor.proto', step)
        self.assertEqual(subprocess.run(['bash', '-n'], input=step, text=True, capture_output=True).returncode, 0)

    def test_unknown_host_fails_before_any_download(self):
        _, step = self.compiler_step()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, body in (
                ('uname', '#!/bin/sh\nprintf "unsupported\\n"\n'),
                ('curl', '#!/bin/sh\ntouch "$RUNNER_TEMP/download-attempted"\nexit 99\n'),
            ):
                file = root / name
                file.write_text(body)
                file.chmod(0o700)
            result = subprocess.run(
                ['bash', '-c', step], text=True, capture_output=True,
                env={**os.environ, 'PATH': f'{root}:{os.environ["PATH"]}', 'RUNNER_TEMP': directory},
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Unsupported protoc host architecture', result.stderr)
            self.assertFalse((root / 'download-attempted').exists())
