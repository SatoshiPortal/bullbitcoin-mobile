import 'dart:convert';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart';
import '../fixtures/backup_secret_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart' as nostr;

import '../fixtures/backup_credential_vectors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'the default seed produces the Data Recovery Words at index 100',
    () async {
      final seed = await backupSecretFixture();
      final words =
          (await seed.derive.bip85.mnemonic(
                    wordCount: MnemonicLength.words12,
                    index: 100,
                  )
                  as Ok<List<String>, SecretFailure>)
              .value;
      expect(words.join(' '), backupCredentialVectorWords);
    },
  );

  test(
    'words-only recovery and seed derivation produce the same independent vectors',
    () async {
      final seed = await backupSecretFixture();
      for (final credential in [
        (await seed.backup.data() as Ok<BackupCredential, SecretFailure>).value,
        BackupCredential.fromWords(backupCredentialVectorWords),
      ]) {
        final plaintext = utf8.encode('public wallet metadata');
        final ciphertext = credential.encrypt(plaintext);
        expect(credential.decrypt(ciphertext), plaintext);
        expect(
          credential.artifactPublicKey,
          backupCredentialVectorNostrPublicKey,
        );
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
    'normalization preserves the credential and display remains redacted',
    () {
      final normalized = BackupCredential.fromWords(
        '  ${backupCredentialVectorWords.toUpperCase().replaceAll(' ', '\n')}  ',
      );
      expect(
        normalized.artifactPublicKey,
        backupCredentialVectorNostrPublicKey,
      );
      expect(normalized.toString(), 'BackupCredential(<redacted>)');
      expect(
        () => normalized.signServerHash('not a digest'),
        throwsFormatException,
      );
    },
  );
}
