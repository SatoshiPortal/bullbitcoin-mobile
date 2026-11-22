import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:legacy_storage/coordination.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late NativeFileGate gate;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lifecycle-');
    gate = NativeFileGate(File('${directory.path}/gate'));
  });
  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  test(
    'independent descriptors exclude each other in the same process',
    () async {
      final first = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await expectLater(
        gate.acquire(exclusive: true, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      await expectLater(
        gate.acquire(exclusive: false, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      await first.close();
      final left = await gate.acquire(exclusive: false, timeout: Duration.zero);
      final right = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      );
      await expectLater(
        gate.acquire(exclusive: true, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      await left.close();
      await right.close();
      await (await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      )).close();
    },
  );

  test('separate process contends and SIGKILL releases its lease', () async {
    final child = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/support/lifecycle_child.dart',
      gate.file.path,
    ]);
    final errors = child.stderr.transform(utf8.decoder).join();
    try {
      expect(
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((line) => line == 'acquired')
            .timeout(const Duration(seconds: 45)),
        'acquired',
      );
      await expectLater(
        gate.acquire(exclusive: true, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      child.kill(ProcessSignal.sigkill);
      expect(await child.exitCode, -9);
      await (await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      )).close();
    } on Exception {
      child.kill(ProcessSignal.sigkill);
      fail('Child lease failed: ${await errors}');
    } finally {
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
    }
  });

  test('separate isolates cannot bypass an existing lease', () async {
    final first = await gate.acquire(exclusive: true, timeout: Duration.zero);
    final path = gate.file.path;
    final busy = await Isolate.run(() async {
      try {
        final lease = await NativeFileGate(File(path))
            .acquire(exclusive: true, timeout: Duration.zero);
        await lease.close();
        return false;
      } on LifecycleException {
        return true;
      }
    });
    expect(busy, isTrue);
    await first.close();
  });

  test('failed close quarantines the lease until actual closure', () async {
    final first = await gate.acquire(exclusive: false, timeout: Duration.zero);
    var live = true;
    final native = sqlite3.openInMemory();
    native.execute('CREATE TABLE probe (id INTEGER)');
    first.track(() async {
      if (live) throw const LifecycleException('injected_live_handle');
      native.close();
    });
    await expectLater(first.close(), throwsA(isA<LifecycleException>()));
    await expectLater(
      gate.acquire(exclusive: true, timeout: Duration.zero),
      throwsA(isA<LifecycleException>()),
    );
    expect(
      native.select('SELECT count(*) AS count FROM probe').single['count'],
      0,
    );
    live = false;
    await LifecycleAdmission.retryQuarantined();
    await (await gate.acquire(exclusive: true, timeout: Duration.zero)).close();
  });

  test(
    'retry confirms a handle closed before its disposal reported failure',
    () async {
      final first = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      );
      var live = true;
      first.track(() async {
        if (live) {
          live = false;
          throw const LifecycleException('reported_after_close');
        }
      });
      await expectLater(first.close(), throwsA(isA<LifecycleException>()));
      await first.close();
      await (await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      )).close();
    },
  );

  test(
    'concurrent close shares one native release and rejects late handles',
    () async {
      final admission = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      );
      final disposing = Completer<void>();
      var calls = 0;
      admission.track(() async {
        calls++;
        await disposing.future;
      });
      final first = admission.close();
      final second = admission.close();
      expect(
        () => admission.track(() async {}),
        throwsA(isA<LifecycleException>()),
      );
      disposing.complete();
      await Future.wait([first, second]);
      expect(calls, 1);
      await (await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      )).close();
    },
  );

  test('timed out acquisition cannot acquire later', () async {
    final first = await gate.acquire(exclusive: true, timeout: Duration.zero);
    await expectLater(
      gate.acquire(exclusive: true, timeout: const Duration(milliseconds: 30)),
      throwsA(isA<LifecycleException>()),
    );
    await first.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await (await gate.acquire(exclusive: true, timeout: Duration.zero)).close();
  });
}
