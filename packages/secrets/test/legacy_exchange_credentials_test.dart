import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/testing.dart';

final class _PausedStore extends FakeSecureStoragePlatform {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (key == 'exchange_api_key') {
      entered.complete();
      await release.future;
    }
    return super.read(key: key, options: options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('closed admission cannot read either legacy credential', () async {
    final directory = await Directory.systemTemp.createTemp('exchange-lease-');
    final store = FakeSecureStoragePlatform().install();
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    await admission.close();
    final reads = store.reads;

    expect(
      await readLegacyExchangeCredentials(admission),
      isA<Err<({String? mainnet, String? testnet}), LegacyImportFailure>>(),
    );
    expect(store.reads, reads);
    await directory.delete(recursive: true);
  });

  test('closing an admission waits for an already admitted read', () async {
    final directory = await Directory.systemTemp.createTemp('exchange-lease-');
    final store = _PausedStore()..install();
    final gate = NativeFileGate(File('${directory.path}/gate'));
    final admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    final reading = readLegacyExchangeCredentials(admission);
    await store.entered.future.timeout(const Duration(seconds: 5));
    var closed = false;
    final closing = admission.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    store.release.complete();
    expect(await reading, isA<Ok>());
    await closing;
    expect(closed, isTrue);
    await directory.delete(recursive: true);
  });
}
