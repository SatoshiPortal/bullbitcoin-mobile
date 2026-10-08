#!/usr/bin/env python3
"""Exercise the pinned repository scripts with synthetic, unsigned ZIP fixtures.

Container and compiler lookups are simulated. These tests do not build BULL.
Run: python3 reproducibility/test_scripts.py
"""
import atexit
import tempfile
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import warnings
import zipfile

SOURCE = Path(__file__).resolve().parent.parent
BASE = Path(tempfile.mkdtemp(prefix='bull-repro-tests-'))
atexit.register(shutil.rmtree, BASE)
FIXTURES = BASE / 'fixtures'
FIXTURES.mkdir(exist_ok=True)
RESULTS = []


def archive(name, entries, compression=zipfile.ZIP_STORED):
    path = FIXTURES / (name + '.apk')
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', UserWarning)
        with zipfile.ZipFile(path, 'w', compression=compression) as z:
            for entry, data in entries:
                z.writestr(entry, data)
    return path


def record(name, command, secure_codes, **kwargs):
    process = subprocess.run(command, capture_output=True, text=True, timeout=30, **kwargs)
    row = {
        'name': name,
        'command': list(map(str, command)),
        'returncode': process.returncode,
        'secure_expected_codes': secure_codes,
        'meets_expectation': process.returncode in secure_codes,
        'stdout': process.stdout,
        'stderr': process.stderr,
    }
    RESULTS.append(row)
    print(('PASS' if row['meets_expectation'] else 'FINDING'), name, process.returncode)
    return process


def compare(name, left, right, codes):
    return record(name, ['sh', str(SOURCE / 'reproducibility/compare_apk_entries.sh'), str(left), str(right)], codes)


payload = [('AndroidManifest.xml', b'manifest'), ('classes.dex', b'dex-content')]
original = archive('original', payload)
compare('identical archive', original, original, [0])
compare('changed DEX bytes', original, archive('dex-change', [payload[0], ('classes.dex', b'other-dex')]), [1])
compare('added file', original, archive('added', payload + [('assets/new', b'new')]), [1])
compare('removed file', original, archive('removed', payload[:1]), [1])
compare('changed META-INF service', archive('service1', payload + [('META-INF/services/p', b'one')]), archive('service2', payload + [('META-INF/services/p', b'two')]), [1])
compare('changed AndroidX version', archive('version1', payload + [('META-INF/androidx.version', b'one')]), archive('version2', payload + [('META-INF/androidx.version', b'two')]), [1])
for suffix in ['RSA', 'SF', 'EC', 'DSA']:
    compare('allowed signature exclusion ' + suffix, original, archive('signature-' + suffix, payload + [('META-INF/CERT.' + suffix, b'signature')]), [0])
compare('allowed manifest exclusion', original, archive('signature-manifest', payload + [('META-INF/MANIFEST.MF', b'signature')]), [0])
compare('nested signature-like file stays compared', original, archive('nested-signature', payload + [('META-INF/services/CERT.RSA', b'content')]), [1])
compare('signature-like file outside META-INF stays compared', original, archive('outside-signature', payload + [('assets/CERT.RSA', b'content')]), [1])
for entry in ['assets/[x].bin', 'assets/*.bin', 'assets/?.bin', 'assets/back\\slash.bin', 'assets/sp ace.bin']:
    key = hashlib.sha256(entry.encode()).hexdigest()[:8]
    compare('literal member ' + entry, archive(key + 'a', payload + [(entry, b'one')]), archive(key + 'b', payload + [(entry, b'two')]), [1])
compare('missing archive', original, FIXTURES / 'missing.apk', [2])
invalid = FIXTURES / 'invalid.apk'
invalid.write_bytes(b'not a ZIP file')
compare('invalid archive', invalid, invalid, [2])
empty = archive('empty', [])
compare('empty archive', empty, empty, [2])
signatures_only = archive('signatures-only', [('META-INF/CERT.RSA', b'sig')])
compare('no comparable payload', signatures_only, signatures_only, [2])
corrupt = FIXTURES / 'corrupt.apk'
contents = bytearray(original.read_bytes())
contents[30 + len(payload[0][0])] ^= 1
corrupt.write_bytes(contents)
compare('CRC extraction failure', corrupt, corrupt, [2])
truncated = FIXTURES / 'truncated.apk'
truncated.write_bytes(original.read_bytes()[:50])
compare('truncated archive', truncated, truncated, [2])
compare('member ordering ignored by content contract', original, archive('reordered', list(reversed(payload))), [0])
compare('compression ignored by content contract', original, archive('compressed', payload, zipfile.ZIP_DEFLATED), [0])
duplicate1 = archive('duplicate1', [('classes.dex', b'a'), ('classes.dex', b'bc')])
duplicate2 = archive('duplicate2', [('classes.dex', b'ab'), ('classes.dex', b'c')])
compare('duplicate member partition must not claim identical', duplicate1, duplicate2, [1, 2])

mock = BASE / 'mock_container.py'
mock.write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, subprocess, sys
args = sys.argv[1:]
with open(os.environ['AUDIT_CONTAINER_LOG'], 'a') as log:
    log.write(json.dumps(args) + '\\n')
if args[0] == 'build':
    print('fixture-image'); sys.exit(0)
if args[0] in ['rm', 'rmi']:
    sys.exit(0)
if args[0] == 'cp':
    shutil.copyfile(os.environ['AUDIT_NATIVE_APK'], args[-1]); sys.exit(0)
if args[0] != 'run':
    sys.exit(1)
if 'rustc' in args:
    if os.environ.get('AUDIT_COMPILER_LOOKUP_FAIL') == '1':
        sys.exit(1)
    version = '1.85.1' if '1.85.1' in args else '1.95.0'
    if 'stable' in args and os.environ.get('AUDIT_FLOATING_STABLE') == '1': version = '1.98.0'
    print('rustc ' + version + ' (fixture)'); sys.exit(0)
if '/compare.sh' in args:
    mounts = {}
    for i, arg in enumerate(args):
        if arg == '-v':
            host, guest, *opts = args[i + 1].split(':')
            mounts[guest] = host
    def host_path(guest):
        for target, host in sorted(mounts.items(), key=lambda item: -len(item[0])):
            if guest == target or guest.startswith(target + '/'):
                return host + guest[len(target):]
        raise ValueError(guest)
    idx = args.index('/compare.sh')
    sys.exit(subprocess.call(['sh', host_path('/compare.sh'), host_path(args[idx+1]), host_path(args[idx+2])]))
if any('apktool d ' in arg for arg in args):
    import shlex
    mounts = {}
    for i, arg in enumerate(args):
        if arg == '-v':
            host, guest, *opts = args[i + 1].split(':')
            mounts[guest] = host
    command = shlex.split(args[-1])
    target = command[command.index('-o') + 1]
    output = pathlib.Path(mounts['/tfp']) / target.removeprefix('/tfp/')
    output.mkdir(parents=True, exist_ok=True)
    (output/'apktool.yml').write_text("versionName: '1.0.0'\\nversionCode: '1'\\n")
    (output/'AndroidManifest.xml').write_text('<manifest package="com.bullbitcoin.mobile"/>\\n')
    sys.exit(0)
if any('bundletool build-apks' in arg for arg in args):
    work = None
    for i, arg in enumerate(args):
        if arg == '-v' and args[i + 1].endswith(':/work'):
            work = pathlib.Path(args[i + 1].removesuffix(':/work'))
    shutil.copytree(os.environ['AUDIT_BUILT_SPLITS'], work/'built-splits', dirs_exist_ok=True)
    sys.exit(0)
if '--name' in args:
    sys.exit(0)
sys.exit(1)
''')
mock.chmod(0o755)
base_env = dict(os.environ, AUDIT_CONTAINER_LOG=str(BASE / 'container_calls.jsonl'))


def native(name, libraries):
    return archive(name, [(f'lib/{abi}/{lib}', f'rustc version {version}\0'.encode()) for abi, lib, version in libraries])


baseline = [('arm64-v8a', 'libbdk_dart_ffi.so', '1.85.1'), ('arm64-v8a', 'libonion.so', '1.95.0'), ('arm64-v8a', 'librust_lib_bull_sdk.so', '1.95.0')]


def guard(name, apk, codes, **env):
    return record(name, ['make', '--no-print-directory', '-f', str(SOURCE/'makefile'), 'verify-rustc-pins', f'APK={apk}', f'CONTAINER={mock}'], codes, env=dict(base_env, **env))


guard('current Rust libraries match', native('native-baseline', baseline + [('arm64-v8a', 'libpayjoin_ffi_wrapper.so', '1.85.1')]), [0])
guard('legacy name cannot substitute current Payjoin library', native('native-legacy', baseline + [('arm64-v8a', 'libpayjoin_flutter.so', '1.95.0')]), [2])
guard('tracked compiler mismatch', native('native-mismatch', [baseline[0], ('arm64-v8a', 'libonion.so', '1.94.0'), baseline[2]]), [2])
guard('missing version string', archive('native-no-version', [('lib/arm64-v8a/libbdk_dart_ffi.so', b'no version')]), [2])
guard('no native libraries', original, [2])
guard('no tracked Rust libraries', native('unknown-only', [('arm64-v8a', 'unknown.so', '9.99.0')]), [2])
guard('compiler lookup failure', native('native-lookup', baseline), [2], AUDIT_COMPILER_LOOKUP_FAIL='1')
guard('one tracked library cannot prove complete coverage', native('native-incomplete', baseline[:1]), [2])
guard('Payjoin compiler mismatch must fail', native('native-payjoin-wrong', baseline + [('arm64-v8a', 'libpayjoin_ffi_wrapper.so', '9.99.0')]), [2])
guard('missing ABI counterpart must fail completeness check', native('native-abi-incomplete', baseline + [('x86_64', 'libonion.so', '1.95.0')]), [2])

guard('ambient stable drift does not change expected pin', native('native-stable-drift', baseline + [('arm64-v8a', 'libpayjoin_ffi_wrapper.so', '1.85.1')]), [0], AUDIT_FLOATING_STABLE='1')

# Exercise the genuine double-build script and Makefile orchestration with a
# simulated runtime. Only command construction and control flow are tested.
mockbin = BASE / 'mockbin'
mockbin.mkdir(exist_ok=True)
(mockbin/'podman').symlink_to(mock) if not (mockbin/'podman').exists() else None
log = BASE / 'double_build_calls.jsonl'
log.write_text('')
env = dict(base_env, PATH=str(mockbin) + os.pathsep + os.environ['PATH'], AUDIT_CONTAINER_LOG=str(log), AUDIT_NATIVE_APK=str(FIXTURES/'native-baseline.apk'))
orchestration = BASE / 'double-build-repo'
orchestration.mkdir()
for name in ['makefile', '.fvmrc', 'android/gradle.properties', 'reproducibility/test.sh', 'reproducibility/compare_apk_entries.sh']:
    dest = orchestration / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / name, dest)
epoch_git = mockbin / 'git'
epoch_git.write_text('#!/bin/sh\n[ "$1" = log ] && echo 1780000000\n')
epoch_git.chmod(0o755)
record('double-build script control flow with simulated container', ['bash', str(orchestration/'reproducibility/test.sh'), 'release'], [0], env=env, cwd=orchestration)
calls = [json.loads(line) for line in log.read_text().splitlines()]
builds = [call for call in calls if call[0] == 'build' and 'Containerfile.tools' in call]
fresh = len(builds) == 2 and all('--no-cache' in call for call in builds)
RESULTS.append({'name': 'double-build must force toolchain reconstruction', 'meets_expectation': fresh, 'observed_tool_build_calls': builds, 'observed_image_removals': [c for c in calls if c[0]=='rmi'], 'scope': 'command-construction test only; no real container cache involved'})
print('PASS' if fresh else 'FINDING', 'double-build must force toolchain reconstruction')
runs = [c for c in calls if c[:2] == ['run', '--name']]
epoch_passed = len(runs) == 2 and all('SOURCE_DATE_EPOCH=1780000000' in c for c in runs)
RESULTS.append({'name': 'worktree epoch is passed from host', 'meets_expectation': epoch_passed})
print('PASS' if epoch_passed else 'FINDING', 'worktree epoch is passed from host')

# Exercise verify_build.sh control flow. Metadata decoding and AAB splitting
# are simulated; the comparator still processes real fixture ZIP bytes.
git_mock = mockbin/'git'
git_mock.write_text('''#!/usr/bin/env python3
import os, sys
args=sys.argv[1:]
if '-C' in args:
    i=args.index('-C'); del args[i:i+2]
if args[0]=='tag': print('v1.0.0')
elif args[0]=='rev-parse': print('6a79addf0285460d763af0e6e1e538fb5ed8e002')
elif args[0]=='diff': sys.exit(1 if os.environ.get('AUDIT_DIRTY')=='1' else 0)
elif args[0]=='log': print('1780000000')
elif args[0]=='ls-files': pass
elif args[0]=='status': print(' M tracked.dart')
else: sys.exit(1)
''')
git_mock.chmod(0o755)


def verify(name, official, codes, **extra_env):
    checkout = BASE/'verify_cases'/name.replace(' ', '-')
    if checkout.exists():
        shutil.rmtree(checkout)
    shutil.copytree(SOURCE, checkout, ignore=shutil.ignore_patterns('.git', '.dart_tool', '.fvm', 'build', '.gradle', 'BULL-*.apk', 'reproducibility_test_*', 'bullbitcoin_*_verification'))
    workspace = checkout/'reproducibility/bullbitcoin_1.0.0_verification'
    if workspace.exists():
        shutil.rmtree(workspace)
    venv = dict(env, AUDIT_NATIVE_APK=str(FIXTURES/'native-baseline.apk'), **extra_env)
    record(name, ['bash', str(checkout/'reproducibility/verify_build.sh'), '--version', '1.0.0', '--apk', str(official), '--yes'], codes, env=venv, cwd=checkout)
    return workspace


single_work = verify('single APK identical control flow', FIXTURES/'native-baseline.apk', [0])
report = (single_work/'RESULTS.md').read_text()
hash_recorded = hashlib.sha256((FIXTURES/'native-baseline.apk').read_bytes()).hexdigest() in report
RESULTS.append({'name':'local APK report must include reference hash', 'meets_expectation':hash_recorded, 'report': report})
print('PASS' if hash_recorded else 'FINDING', 'local APK report must include reference hash')
verify('single APK changed content', original, [1])
verify('tracked dirty checkout refused', original, [1], AUDIT_DIRTY='1')

def split_case(name, official_files, built_files, codes, abi=None, density=None):
    official_dir = BASE/'split_fixtures'/name/'official'
    built_dir = BASE/'split_fixtures'/name/'built'
    official_dir.mkdir(parents=True, exist_ok=True)
    built_dir.mkdir(parents=True, exist_ok=True)
    for n in official_files:
        shutil.copyfile(FIXTURES/'native-baseline.apk', official_dir/n)
    for n in built_files:
        shutil.copyfile(FIXTURES/'native-baseline.apk', built_dir/n)
    work=verify(name, official_dir, codes, AUDIT_BUILT_SPLITS=str(built_dir))
    spec_file=work/'device-spec.json'
    if spec_file.exists() and (abi is not None or density is not None):
        spec=json.loads(spec_file.read_text())
        if abi is not None:
            passed=spec['supportedAbis']==[abi]
            RESULTS.append({'name':name+' ABI mapping', 'meets_expectation':passed, 'expected':abi, 'actual':spec['supportedAbis']})
            print('PASS' if passed else 'FINDING', name+' ABI mapping')
        if density is not None:
            passed=spec['screenDensity']==density
            RESULTS.append({'name':name+' density mapping', 'meets_expectation':passed, 'expected':density, 'actual':spec['screenDensity']})
            print('PASS' if passed else 'FINDING', name+' density mapping')


split_case('matching split sets', ['base.apk','split_config.arm64_v8a.apk'], ['base-master.apk','base-arm64_v8a.apk'], [0], abi='arm64-v8a')
split_case('missing built counterpart', ['base.apk','split_config.arm64_v8a.apk'], ['base-master.apk'], [1])
split_case('extra built counterpart', ['base.apk'], ['base-master.apk','base-extra.apk'], [1])
split_case('x86_64 split device mapping', ['base.apk','split_config.x86_64.apk'], ['base-master.apk','base-x86_64.apk'], [0], abi='x86_64')
for qualifier, density in [('hdpi',240),('xhdpi',320),('xxhdpi',480),('xxxhdpi',640)]:
    split_case(qualifier+' split device mapping', ['base.apk','split_config.'+qualifier+'.apk'], ['base-master.apk','base-'+qualifier+'.apk'], [0], density=density)


# SDK downloads must fail before installing bytes that were not reviewed.
installer = SOURCE / 'reproducibility/install-android-pins.sh'
record('unknown Android API refused', ['bash', str(installer), str(BASE/'sdk-unknown'), '999'], [1])
curl_mock = mockbin / 'curl'
curl_mock.write_text("#!/usr/bin/env python3\nimport sys\nfrom pathlib import Path\nPath(sys.argv[sys.argv.index('-o')+1]).write_bytes(b'unreviewed download')\n")
curl_mock.chmod(0o755)
record('SDK checksum mismatch refused', ['bash', str(installer), str(BASE/'sdk-bad-hash'), '36'], [1], env=env)
RESULTS.append({'name': 'unverified SDK package was not installed', 'meets_expectation': not (BASE/'sdk-bad-hash/platform-tools').exists()})

findings = [row['name'] for row in RESULTS if not row['meets_expectation']]
print(f'{len(RESULTS)} checks, {len(findings)} failures')
if findings:
    print('\n'.join(findings))
raise SystemExit(bool(findings))
