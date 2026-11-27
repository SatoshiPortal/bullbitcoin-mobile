import 'dart:io';

import 'package:exchange/migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fresh provenance performs no keychain reads or deletion', () async {
    final directory = await Directory.systemTemp.createTemp(
      'exchange-retirement-',
    );
    final keychain = FakeSecureStoragePlatform(
      entries: {
        'exchange_api_key': 'retained',
        'exchange_api_key_testnet': 'retained',
      },
    ).install();
    final admission = await NativeFileGate(
      File('${directory.path}/lock'),
    ).acquire(exclusive: true, timeout: Duration.zero) as ExclusiveAdmission;
    try {
      final result = await const ExchangeCredentialRetirement().verifyRetirable(
        admission,
        origin: OwnerOrigin.fresh,
        source: LegacySource(File('${directory.path}/legacy'), 16),
      );
      expect(result, isA<Ok>());
      expect(keychain.reads, 0);
      expect(keychain.entries.length, 2);
    } finally {
      await admission.close();
      await directory.delete(recursive: true);
    }
  });
}
