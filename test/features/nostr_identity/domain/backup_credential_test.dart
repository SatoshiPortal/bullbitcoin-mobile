import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' as nostr;

import '../fixtures/backup_credential_vectors.dart';

void main() {
  final seed = Seed.bytes(
    bytes: backupCredentialVectorSeed,
    masterFingerprint: 'fixture',
  );

  test(
    'the default seed produces the unchanged Data Recovery Words at index 100',
    () {
      expect(BackupCredential.deriveWords(seed), backupCredentialVectorWords);
    },
  );

  test(
    'words-only recovery and seed derivation produce the same independent vectors',
    () {
      for (final credential in [
        BackupCredential.fromSeed(seed),
        BackupCredential.fromWords(backupCredentialVectorWords),
      ]) {
        expect(
          hex.encode(credential.encryptionKey),
          backupCredentialVectorEncryptionKey,
        );
        expect(
          credential.artifactPublicKey,
          backupCredentialVectorNostrPublicKey,
        );
        expect(credential.artifactNpub, backupCredentialVectorNostrNpub);
        expect(
          credential.serverPublicKey,
          backupCredentialVectorServerPublicKey,
        );
        expect(credential.serverPublicKey, isNot(credential.artifactPublicKey));
        expect(
          credential.signArtifactHash(backupCredentialVectorDigest),
          backupCredentialVectorNostrSignature,
        );
        expect(
          credential.signServerHash(backupCredentialVectorDigest),
          backupCredentialVectorServerSignature,
        );
        expect(
          nostr.Schnorr.verify(
            publicKey: credential.serverPublicKey,
            message: backupCredentialVectorDigest,
            signature: credential.signServerHash(backupCredentialVectorDigest),
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'malformed and oversized credentials fail without returning their input',
    () {
      for (final input in [
        '',
        'private input',
        List.filled(12, 'zoo').join(' '),
        'x' * 257,
      ]) {
        expect(
          () => BackupCredential.fromWords(input),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Invalid Data Recovery Words',
            ),
          ),
        );
      }
    },
  );

  test(
    'normalization preserves the credential and encryption bytes cannot mutate it',
    () {
      final normalized = BackupCredential.fromWords(
        '  ${backupCredentialVectorWords.toUpperCase().replaceAll(' ', '\n')}  ',
      );
      final exported = normalized.encryptionKey;
      exported.fillRange(0, exported.length, 0);
      expect(
        hex.encode(normalized.encryptionKey),
        backupCredentialVectorEncryptionKey,
      );
      expect(normalized.toString(), 'BackupCredential(<redacted>)');
      expect(
        () => normalized.signServerHash('not a digest'),
        throwsFormatException,
      );
    },
  );
}
