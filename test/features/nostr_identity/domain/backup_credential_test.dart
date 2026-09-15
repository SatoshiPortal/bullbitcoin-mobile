import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/nostr_bech32.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/backup_credential_vectors.dart';

Seed _seed() => Seed.bytes(
  bytes: backupCredentialVectorSeed,
  masterFingerprint: hex.encode(
    bip32.Bip32Keys.fromSeed(backupCredentialVectorSeed).fingerprint,
  ),
);

void main() {
  test('the reserved path still produces the frozen BIP85 entropy', () {
    expect(Bip85Reservations.backupWords.path, "39'/0'/12'/104'");
    final root = Bip32Derivation.getCanonicalRootXprvFromSeed(
      backupCredentialVectorSeed,
    );

    expect(
      hex.encode(
        bip85.Bip85Entropy.derive(
          xprvBase58: root,
          application: bip85.MnemonicApplication(),
          path: "0'/12'/104'",
        ),
      ),
      backupCredentialVectorBip85Entropy,
    );
    // A generic BIP85 path tool given the reserved path prints the words.
    expect(
      bip85.Bip85Entropy.deriveFromHardenedPath(
        xprvBase58: root,
        path: bip85.Bip85HardenedPath(Bip85Reservations.backupWords.path),
      ),
      backupCredentialVectorWords,
    );
  });

  test('a seed yields the frozen twelve words: a standard BIP85 child', () {
    final words = BackupCredential.deriveWords(_seed());

    expect(words, backupCredentialVectorWords);
    final mnemonic = bip39.Mnemonic.fromSentence(words, bip39.Language.english);
    expect(hex.encode(mnemonic.entropy), backupCredentialVectorWordEntropy);
    expect(
      backupCredentialVectorBip85Entropy,
      startsWith(backupCredentialVectorWordEntropy),
      reason: 'BIP85 39\' takes the first 16 bytes verbatim, no Bull step',
    );
    expect(hex.encode(mnemonic.seed), backupCredentialVectorWordsSeed);
  });

  test('every key is a BIP85 child of the words, nothing Bull-specific', () {
    final root = Bip32Derivation.getCanonicalRootXprvFromSeed(
      Uint8List.fromList(hex.decode(backupCredentialVectorWordsSeed)),
    );
    String child(String path) => bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(path),
    );

    expect(BackupCredential.encryptionKeyPath, "128169'/32'/0'");
    expect(BackupCredential.nostrIdentityPath, "128002'/100'/1'");
    expect(BackupCredential.serverIdentityPath, "128002'/101'/1'");
    expect(
      child(BackupCredential.encryptionKeyPath).substring(0, 64),
      backupCredentialVectorEncryptionKey,
    );
    for (final identity in [
      (
        BackupCredential.nostrIdentityPath,
        backupCredentialVectorNostrPublicKey,
      ),
      (
        BackupCredential.serverIdentityPath,
        backupCredentialVectorServerPublicKey,
      ),
    ]) {
      expect(
        hex.encode(
          ECPrivate.fromHex(
            child(identity.$1).substring(0, 64),
          ).getPublic().toXOnly(),
        ),
        identity.$2,
      );
    }
  });

  test('the words index can never become a wallet', () {
    expect(
      Bip85Reservations.reservedWalletSeedIndices,
      contains(Bip85Reservations.backupWords.index),
    );
    expect(Bip85Reservations.backupWords.isWalletSeed, isFalse);
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
        NostrBech32.npub(hex.decode(credential.nostrPublicKeyHex)),
        backupCredentialVectorNostrNpub,
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
      '$backupCredentialVectorWords math',
      'abandon ' * 12,
      'invalid ' * 12,
      backupCredentialVectorWords.replaceFirst('disease', 'diseasee'),
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
      expect(thrown.toString(), isNot(contains('disease')));
    }
  });

  test('the credential redacts itself and keeps identity equality', () {
    final credential = BackupCredential.fromWords(backupCredentialVectorWords);
    final same = BackupCredential.fromWords(backupCredentialVectorWords);

    expect(credential.toString(), isNot(contains('disease')));
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
