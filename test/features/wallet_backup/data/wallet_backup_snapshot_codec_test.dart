import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_backup_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

import '../support/canonical_backup_snapshot.dart';

/// The canonical version 1 document, frozen by the golden fixtures.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final codec = canonicalCodec();

  group('golden fixtures', () {
    test('a full backup encodes to the frozen bytes', () {
      expect(codec.encode(canonicalFullSnapshot()), _fixture('full'));
    });

    test('a manifest-only backup encodes to the frozen bytes', () {
      expect(codec.encode(canonicalMinimalSnapshot()), _fixture('minimal'));
      expect(_fixture('minimal'), isNot(contains('"definitions"')));
      expect(_fixture('minimal'), isNot(contains('"metadata"')));
    });

    for (final name in const ['full', 'minimal']) {
      test('$name round-trips through the typed snapshot byte for byte', () {
        final decoded = _decode(codec, _fixture(name));

        expect(codec.encode(decoded), _fixture(name));
      });
    }

    test('decoding is insensitive to key order', () {
      final shuffled = jsonEncode(
        Map.fromEntries(
          (jsonDecode(_fixture('full')) as Map<String, Object?>).entries
              .toList()
              .reversed,
        ),
      );

      expect(codec.encode(_decode(codec, shuffled)), _fixture('full'));
    });

    test('the full document carries the typed sections', () {
      final decoded = _decode(codec, _fixture('full'));

      expect(decoded.parentFingerprint, canonicalParentFingerprint);
      expect(decoded.createdAt, canonicalCreatedAt);
      expect(decoded.recoveryManifest.wallets.single.label, 'Vacation');
      expect(
        decoded.recoveryManifest.entries
            .map((entry) => entry.description)
            .whereType<String>(),
        contains('Second word is the city we met in'),
      );
      expect(
        decoded.externalWalletDefinitions.single.walletRef,
        'external-cold-wallet',
      );
      expect(decoded.metadata!.labels.single.label, 'Coffee');
    });

    test('a manifest-only document leaves the optional sections out', () {
      final decoded = _decode(codec, _fixture('minimal'));

      expect(decoded.externalWalletDefinitions, isEmpty);
      expect(decoded.metadata, isNull);
    });
  });

  group('rejections', () {
    test('a foreign parent fingerprint is a wrong-seed failure', () {
      expect(
        () => codec.decode(
          _fixture('full'),
          expectedParentFingerprint: Fingerprint('feedface'),
        ),
        _throwsReason(
          WalletBackupSnapshotCodecFailureReason.parentFingerprintMismatch,
        ),
      );
    });

    test('a newer envelope version is distinct from malformed', () {
      expect(
        () => _decode(
          codec,
          _fixture('full').replaceFirst('"version":1,', '"version":2,'),
        ),
        _throwsReason(
          WalletBackupSnapshotCodecFailureReason.unsupportedVersion,
        ),
      );
    });

    test('a newer section version is distinct from malformed', () {
      expect(
        () => _decode(
          codec,
          _fixture(
            'full',
          ).replaceFirst('"metadata":{"version":1', '"metadata":{"version":2'),
        ),
        _throwsReason(
          WalletBackupSnapshotCodecFailureReason.unsupportedVersion,
        ),
      );
    });

    test('an unknown top-level field is malformed', () {
      expect(
        () => _decode(
          codec,
          _fixture(
            'full',
          ).replaceFirst('"createdAt":', '"extra":1,"createdAt":'),
        ),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.malformed),
      );
    });

    test('another format string is malformed', () {
      expect(
        () => _decode(
          codec,
          _fixture('full').replaceFirst('bullbitcoin.wallet_backup', 'other'),
        ),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.malformed),
      );
    });

    test('a missing manifest section is malformed', () {
      final root = jsonDecode(_fixture('full')) as Map<String, Object?>
        ..remove('manifest');

      expect(
        () => _decode(codec, jsonEncode(root)),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.malformed),
      );
    });

    test('an empty definitions section is malformed, never an empty list', () {
      expect(
        () => _decode(
          codec,
          _fixture('full').replaceFirst(
            RegExp(r'"definitions":\{.*?\}\]\},'),
            '"definitions":{"version":1,"definitions":[]},',
          ),
        ),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.malformed),
      );
    });

    test('the legacy separate-descriptor definition shape is rejected', () {
      final root = jsonDecode(_fixture('full')) as Map<String, Object?>;
      final definitions = root['definitions']! as Map<String, Object?>;
      final definition =
          (definitions['definitions']! as List).single as Map<String, Object?>;
      final descriptor = definition.remove('descriptor')! as String;
      definition['receiveDescriptor'] = descriptor.replaceFirst(
        '/<0;1>/*',
        '/0/*',
      );
      definition['changeDescriptor'] = descriptor.replaceFirst(
        '/<0;1>/*',
        '/1/*',
      );
      definition['masterFingerprint'] = '86241f88';

      expect(
        () => _decode(codec, jsonEncode(root)),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.malformed),
      );
    });

    test('a document past the plaintext limit is too large', () {
      final oversized =
          'x' * (WalletBackupSnapshotCodec.maxPlaintextSizeBytes + 1);

      expect(
        () => _decode(codec, oversized),
        _throwsReason(WalletBackupSnapshotCodecFailureReason.tooLarge),
      );
    });
  });

  group('section comparison', () {
    test('a snapshot never differs from itself', () {
      expect(
        codec.differences(canonicalFullSnapshot(), canonicalFullSnapshot()),
        isEmpty,
      );
    });

    test('the manifest stamp alone is not a difference', () {
      final restamped = WalletBackupSnapshot(
        parentFingerprint: canonicalParentFingerprint,
        createdAt: canonicalCreatedAt + 60,
        recoveryManifest: KeychainManifest(
          parentFingerprint: canonicalParentFingerprint,
          generatedAt: 1788199999,
          entries: canonicalFullSnapshot().recoveryManifest.entries,
        ),
        externalWalletDefinitions:
            canonicalFullSnapshot().externalWalletDefinitions,
        metadata: canonicalFullSnapshot().metadata,
      );

      expect(codec.differences(canonicalFullSnapshot(), restamped), isEmpty);
    });

    test('each section reports its own difference', () {
      expect(
        codec.differences(canonicalFullSnapshot(), canonicalMinimalSnapshot()),
        {
          WalletBackupDifference.walletManifest,
          WalletBackupDifference.externalWallets,
          WalletBackupDifference.protectedData,
        },
      );
    });
  });
}

String _fixture(String name) => File(
  'test/features/wallet_backup/fixtures/canonical_v1_$name.json',
).readAsStringSync();

WalletBackupSnapshot _decode(WalletBackupSnapshotCodec codec, String payload) =>
    codec.decode(
      payload,
      expectedParentFingerprint: canonicalParentFingerprint,
    );

Matcher _throwsReason(WalletBackupSnapshotCodecFailureReason reason) => throwsA(
  isA<WalletBackupSnapshotCodecException>().having(
    (error) => error.reason,
    'reason',
    reason,
  ),
);
