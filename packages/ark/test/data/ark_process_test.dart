import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_store.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String probe;
  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('ark-process-');
    final packageConfig = await Isolate.packageConfig;
    final ark = await Isolate.resolvePackageUri(
      Uri.parse('package:ark/ark.dart'),
    );
    if (packageConfig == null || ark == null) {
      throw StateError('Missing test package resolution');
    }
    final assets = File.fromUri(packageConfig.resolve('native_assets.yaml'));
    if (!assets.existsSync()) {
      throw StateError('SQLite native asset mapping is required');
    }
    final sdk = File(Platform.resolvedExecutable).parent.parent.path;
    probe = '${temp.path}/probe.dill';
    // Compile Dart only, embedding the same existing SQLite mapping as runner.
    // No dependency hooks, Rust builds or toolchain installation.
    final result = await Process.run('$sdk/bin/dartaotruntime', [
      '$sdk/bin/snapshots/gen_kernel_aot.dart.snapshot',
      '--platform',
      '$sdk/lib/_internal/vm_platform_strong.dill',
      '--packages',
      packageConfig.toFilePath(),
      '--native-assets',
      assets.path,
      '--output',
      probe,
      '${File.fromUri(ark).parent.parent.path}/test/support/writer_probe.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
  tearDownAll(() => temp.deleteSync(recursive: true));
  test('other process is excluded and release permits reopening', () async {
    final path = Directory('${temp.path}/contention')..createSync();
    final process = await Process.start(Platform.resolvedExecutable, [
      probe,
      path.path,
      'hold',
    ]);
    try {
      expect(
        await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first,
        'held',
      );
      expect(ArkWriterLock.acquire('${path.path}/lock'), isA<Err>());
      process.stdin.writeln('release');
      await process.stdin.flush();
      expect(await process.exitCode, 0);
      final result = ArkWriterLock.acquire('${path.path}/lock');
      expect(result, isA<Ok>());
      (result as Ok<ArkWriterLock, ArkWalletFailure>).value.release();
    } finally {
      process.kill();
    }
  });
  test(
    'process death releases lock and preserves admitted journal evidence',
    () async {
      final path = Directory('${temp.path}/crash')..createSync();
      final process = await Process.run(Platform.resolvedExecutable, [
        probe,
        path.path,
        'crash',
      ]);
      expect(process.exitCode, 23);
      final result = ArkWriterLock.acquire('${path.path}/lock');
      expect(result, isA<Ok>());
      final store = ArkStore.open('${path.path}/state', create: false);
      expect(store.operations.single.status, ArkOperationStatus.admitted);
      expect(
        store.operation('admitted-before-death')?.evidence?['txid'],
        'public-evidence',
      );
      store.close();
      (result as Ok<ArkWriterLock, ArkWalletFailure>).value.release();
    },
  );
}
