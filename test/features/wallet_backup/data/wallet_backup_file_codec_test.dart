import 'dart:convert';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart' as nostr;
import '../backup_snapshot_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

T value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final wrong = BackupCredential.fromWords(
    'legal winner thank year wave sausage worth useful legal winner thank yellow',
  );
  final snapshot = backupSnapshotFixture(credential);
  final codec = WalletBackupCodecRepositoryImpl(_Vaults());
  String encode(WalletBackupFileFormat format) =>
      value(codec.encodeFile(snapshot, credential, format: format));
  Map<String, dynamic> envelope(WalletBackupFileFormat format) =>
      jsonDecode(encode(format)) as Map<String, dynamic>;

  for (final format in WalletBackupFileFormat.values) {
    test('$format round-trips the same canonical snapshot', () {
      final source = encode(format);
      final decoded = value(codec.decodeFile(source, credential: credential));
      expect(decoded.format, format);
      expect(
        value(codec.contentHash(decoded.snapshot)),
        value(codec.contentHash(snapshot)),
      );
      expect(source, isNot(contains(backupFixtureWords)));
      if (format == WalletBackupFileFormat.encrypted) {
        expect(source, isNot(contains('Savings')));
      }
    });
  }
  test(
    'readable signature verifies independently over canonical content with file domain separation',
    () {
      final model = envelope(WalletBackupFileFormat.readable);
      final canonical = value(codec.encode(snapshot));
      final digest = sha256
          .convert(
            utf8.encode(
              [
                'bullbitcoin-data-backup-file',
                '1',
                'readable',
                credential.artifactPublicKey,
                (model['createdAt'] as int).toString(),
                canonical,
              ].join('\u0000'),
            ),
          )
          .toString();
      expect(
        nostr.Schnorr.verify(
          publicKey: credential.artifactPublicKey,
          message: digest,
          signature: model['signature'] as String,
        ),
        isTrue,
      );
      final alteredDomain = sha256
          .convert(
            utf8.encode(
              [
                'bullbitcoin-data-backup-file',
                '1',
                'encrypted',
                credential.artifactPublicKey,
                (model['createdAt'] as int).toString(),
                canonical,
              ].join('\u0000'),
            ),
          )
          .toString();
      expect(
        nostr.Schnorr.verify(
          publicKey: credential.artifactPublicKey,
          message: alteredDomain,
          signature: model['signature'] as String,
        ),
        isFalse,
      );
    },
  );
  test(
    'encrypted files require the matching words; readable public files can be inspected seedless',
    () {
      final encrypted = encode(WalletBackupFileFormat.encrypted);
      expect(codec.decodeFile(encrypted), isA<Err>());
      expect(codec.decodeFile(encrypted, credential: wrong), isA<Err>());
      final readable = encode(WalletBackupFileFormat.readable);
      expect(codec.decodeFile(readable), isA<Ok>());
      expect(codec.decodeFile(readable, credential: wrong), isA<Err>());
    },
  );
  test(
    'ordinary JSON formatting changes do not invalidate a readable signature',
    () {
      final model = envelope(WalletBackupFileFormat.readable);
      final formatted = const JsonEncoder.withIndent(
        '  ',
      ).convert(Map.fromEntries(model.entries.toList().reversed));
      expect(codec.decodeFile(formatted), isA<Ok>());
    },
  );
  test(
    'payload edits, key substitution, signature tampering and extra envelope fields are rejected',
    () {
      for (final mutation in ['payload', 'publicKey', 'signature', 'extra']) {
        final model = envelope(WalletBackupFileFormat.readable);
        switch (mutation) {
          case 'payload':
            (model['payload']
                    as Map<
                      String,
                      dynamic
                    >)['inventory']['wallets'][0]['label'] =
                'Changed';
          case 'publicKey':
            model['publicKey'] = wrong.artifactPublicKey;
          case 'signature':
            model['signature'] = '0' * 128;
          case 'extra':
            model['extra'] = true;
        }
        expect(
          codec.decodeFile(jsonEncode(model)),
          isA<Err>(),
          reason: mutation,
        );
      }
    },
  );
  test('encrypted bytes are authenticated before decoding or applying', () {
    final model = envelope(WalletBackupFileFormat.encrypted);
    final bytes = base64.decode(model['payload'] as String);
    bytes[20] ^= 1;
    model['payload'] = base64.encode(bytes);
    expect(
      codec.decodeFile(jsonEncode(model), credential: credential),
      isA<Err>(),
    );
  });
  test(
    'file bounds, depth, unsupported versions and malformed input fail as values',
    () {
      expect(
        codec.decodeFile('a' * (WalletBackupFile.maximumBytes + 1)),
        isA<Err<WalletBackupFile, WalletBackupFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<WalletBackupTooLargeFailure>(),
        ),
      );
      for (final source in ['{', '${'[' * 40}0${']' * 40}', '[]']) {
        expect(codec.decodeFile(source), isA<Err>());
      }
      final model = envelope(WalletBackupFileFormat.readable)..['version'] = 2;
      expect(
        codec.decodeFile(jsonEncode(model)),
        isA<Err<WalletBackupFile, WalletBackupFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<WalletBackupUnsupportedFailure>(),
        ),
      );
      model['version'] = 1;
      model['publicKey'] = 'f' * 64;
      expect(codec.decodeFile(jsonEncode(model)), isA<Err>());
    },
  );
  test('export cannot sign a snapshot belonging to a different credential', () {
    for (final format in WalletBackupFileFormat.values) {
      expect(codec.encodeFile(snapshot, wrong, format: format), isA<Err>());
    }
  });

  test(
    'the file export date is authenticated and does not alter snapshot content',
    () {
      final model = envelope(WalletBackupFileFormat.readable);
      expect(model['createdAt'], isA<int>());
      expect(
        value(
          codec.decodeFile(jsonEncode(model)),
        ).createdAt.millisecondsSinceEpoch,
        model['createdAt'],
      );
      expect(
        (model['payload'] as Map<String, dynamic>).containsKey('createdAt'),
        isFalse,
      );
      model['createdAt'] = (model['createdAt'] as int) + 1;
      expect(codec.decodeFile(jsonEncode(model)), isA<Err>());
    },
  );
}
