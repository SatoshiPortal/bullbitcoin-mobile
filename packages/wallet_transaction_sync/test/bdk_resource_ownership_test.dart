import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'BDK source scopes scan handles and descriptors for failure cleanup',
    () {
      final source = File(
        'lib/src/data/bdk/bdk_wallet_transaction_source.dart',
      ).readAsStringSync();

      expect(source, contains('final requestBuilder = wallet.startFullScan()'));
      expect(
        source,
        contains('final requestBuilder = wallet.startSyncWithRevealedSpks()'),
      );
      expect(source, contains('client?.dispose();'));
      expect(source, contains('update.dispose();'));
      expect(source, contains('request.dispose();'));
      expect(source, contains('requestBuilder.dispose();'));
      expect(source, contains('external?.dispose();'));
      expect(source, contains('internal?.dispose();'));
      expect(source, contains('} catch (_) {\n      persister.dispose();'));
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
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'finally \{\s+requestBuilder\.dispose\(\);',
          dotAll: true,
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'finally \{\s+internal\?\.dispose\(\);',
          dotAll: true,
        ).hasMatch(source),
        isTrue,
      );
    },
  );
}
