import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/backup_credential_vectors.dart';

Seed _seed() => Seed.bytes(
  bytes: backupCredentialVectorSeed,
  masterFingerprint: hex.encode(
    bip32.Bip32Keys.fromSeed(backupCredentialVectorSeed).fingerprint,
  ),
);

void main() {
  test('the reserved path still produces the frozen BIP85 entropy', () {
    expect(
      bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: Bip32Derivation.getCanonicalRootXprvFromSeed(
          backupCredentialVectorSeed,
        ),
        path: bip85.Bip85HardenedPath("1642'/0'/1'"),
      ),
      backupCredentialVectorBip85Entropy,
    );
  });

  test('a seed yields the frozen twelve words and their entropy', () {
    final words = BackupCredential.deriveWords(_seed());

    expect(words, backupCredentialVectorWords);
    expect(
      hex.encode(
        bip39.Mnemonic.fromSentence(words, bip39.Language.english).entropy,
      ),
      backupCredentialVectorWordEntropy,
    );
  });

  test('seed and words derive byte-identical credentials', () {
    final fromSeed = BackupCredential.fromSeed(_seed());
    final fromWords = BackupCredential.fromWords(backupCredentialVectorWords);

    for (final credential in [fromSeed, fromWords]) {
      expect(credential.encryptionKeyHex, backupCredentialVectorEncryptionKey);
      expect(
        credential.nostrPublicKeyHex,
        backupCredentialVectorNostrPublicKey,
      );
      expect(
        credential.serverPublicKeyHex,
        backupCredentialVectorServerPublicKey,
      );
      expect(
        credential.signNostrHash(backupCredentialVectorDigest),
        backupCredentialVectorNostrSignature,
      );
      expect(
        credential.signServerHash(backupCredentialVectorDigest),
        backupCredentialVectorServerSignature,
      );
    }
  });

  test('the public event author is not the server account name', () {
    final credential = BackupCredential.fromWords(backupCredentialVectorWords);

    expect(
      credential.nostrPublicKeyHex,
      isNot(credential.serverPublicKeyHex),
      reason: 'one key for both would join the public author to the account',
    );
    expect(
      credential.signNostrHash(backupCredentialVectorDigest),
      isNot(credential.signServerHash(backupCredentialVectorDigest)),
    );
  });

  test('both frozen signatures verify under their own public key', () {
    for (final identity in [
      (
        backupCredentialVectorNostrPublicKey,
        backupCredentialVectorNostrSignature,
      ),
      (
        backupCredentialVectorServerPublicKey,
        backupCredentialVectorServerSignature,
      ),
    ]) {
      expect(
        ECPublic.fromHex('02${identity.$1}').verifyBip340Signature(
          digest: hex.decode(backupCredentialVectorDigest),
          signature: hex.decode(identity.$2),
          tweak: false,
        ),
        isTrue,
      );
    }
    expect(
      ECPublic.fromHex(
        '02$backupCredentialVectorServerPublicKey',
      ).verifyBip340Signature(
        digest: hex.decode(backupCredentialVectorDigest),
        signature: hex.decode(backupCredentialVectorNostrSignature),
        tweak: false,
      ),
      isFalse,
    );
  });

  test('case and separating whitespace are normalised, nothing else', () {
    final spaced = BackupCredential.fromWords(
      '  ${backupCredentialVectorWords.toUpperCase().replaceAll(' ', '\n\t')}  ',
    );

    expect(spaced.encryptionKeyHex, backupCredentialVectorEncryptionKey);
    expect(spaced.serverPublicKeyHex, backupCredentialVectorServerPublicKey);
  });

  test('a different valid credential opens nothing of the first', () {
    final other = BackupCredential.fromWords(backupCredentialVectorOtherWords);

    expect(other.encryptionKeyHex, isNot(backupCredentialVectorEncryptionKey));
    expect(
      other.serverPublicKeyHex,
      isNot(backupCredentialVectorServerPublicKey),
    );
  });

  test('malformed words are refused without echoing the input', () {
    final words = backupCredentialVectorWords.split(' ');
    final rejected = [
      '',
      '   ',
      words.take(11).join(' '),
      '$backupCredentialVectorWords crop',
      'abandon ' * 12,
      'invalid ' * 12,
      backupCredentialVectorWords.replaceFirst('abandon', 'abandonn'),
      'x' * (BackupCredential.maxInputLength + 1),
    ];

    for (final input in rejected) {
      Object? thrown;
      try {
        BackupCredential.fromWords(input);
      } on Object catch (error) {
        thrown = error;
      }
      expect(thrown, isA<InvalidBackupWordsException>(), reason: input);
      expect(thrown.toString(), isNot(contains('abandon')));
    }
  });

  test('the credential redacts itself and keeps identity equality', () {
    final credential = BackupCredential.fromWords(backupCredentialVectorWords);
    final same = BackupCredential.fromWords(backupCredentialVectorWords);

    expect(credential.toString(), isNot(contains('abandon')));
    expect(
      credential.toString(),
      isNot(contains(backupCredentialVectorEncryptionKey)),
    );
    expect(credential == same, isFalse);
    expect(credential == credential, isTrue);
  });

  test('a digest that is not 32 bytes never reaches the signer', () {
    final credential = BackupCredential.fromWords(backupCredentialVectorWords);

    for (final digest in ['', 'abcd', 'zz' * 32, '0' * 63]) {
      expect(() => credential.signNostrHash(digest), throwsArgumentError);
      expect(() => credential.signServerHash(digest), throwsArgumentError);
    }
  });
}
