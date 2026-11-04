import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'BDK source scopes scan handles and descriptors for failure cleanup',
    () {
      final source = File(
        'lib/src/data/bdk/bdk_wallet_transaction_source.dart',
      ).readAsStringSync();

      final requests = File(
        'lib/src/data/bdk/bdk_electrum_source.dart',
      ).readAsStringSync();
      expect(source, contains('fetchBdkElectrumUpdate('));
      expect(
        requests,
        contains('final requestBuilder = wallet.startFullScan()'),
      );
      expect(
        requests,
        contains('final requestBuilder = wallet.startSyncWithRevealedSpks()'),
      );
      expect(source, contains('client?.dispose();'));
      expect(source, contains('update.dispose();'));
      expect(requests, contains('request.dispose();'));
      expect(requests, contains('requestBuilder.dispose();'));
      final session = File(
        'lib/src/data/bdk/bdk_wallet_session.dart',
      ).readAsStringSync();
      expect(session, contains('external?.dispose();'));
      expect(session, contains('internal?.dispose();'));
      expect(session, contains('} catch (_) {\n      persister.dispose();'));
      expect(
        RegExp(
          r'finally \{\s+update\.dispose\(\);',
          dotAll: true,
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'finally \{\s+request\.dispose\(\);',
          dotAll: true,
        ).hasMatch(requests),
        isTrue,
      );
      expect(
        RegExp(
          r'finally \{\s+requestBuilder\.dispose\(\);',
          dotAll: true,
        ).hasMatch(requests),
        isTrue,
      );
      expect(
        RegExp(
          r'finally \{\s+internal\?\.dispose\(\);',
          dotAll: true,
        ).hasMatch(session),
        isTrue,
      );
    },
  );
}
