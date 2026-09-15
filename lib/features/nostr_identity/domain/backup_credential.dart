import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';

/// Which of the credential's two signing identities an operation uses.
///
/// One credential, two scalars: the public artifact author and the private
/// server account are deliberately not the same public key.
enum BackupIdentityScope { nostr, server }

/// The submitted backup words are not the frozen twelve-word form.
///
/// It carries nothing about the input: the words are the credential, so even a
/// length or a mistyped word must not reach a log, a trace or a message.
final class InvalidBackupWordsException implements Exception {
  const InvalidBackupWordsException();

  @override
  String toString() => 'InvalidBackupWordsException';
}

/// The one Bull backup credential.
///
/// Twelve words, a standard BIP85 BIP39 child of the originating default seed
/// at the reserved index, open the metadata backup, authenticate its server
/// account and author the public vault events. Everything below the words is a
/// further BIP85 derivation on the words' own BIP39 root, so a holder of the
/// words reproduces every key with any BIP85 tool and nothing Bull-specific:
///
/// ```
/// default seed
///  └─ BIP85 39'/0'/12'/<reserved index>'   → the twelve words
///      ├─ BIP85 128169'/32'/0'              → 32-byte encryption key
///      ├─ BIP85 128002'/100'/1'             → artifact identity (public relays)
///      └─ BIP85 128002'/101'/1'             → server identity (backup server)
/// ```
///
/// BIP85 is one-way, so the words disclose nothing about the seed they came
/// from and no wallet is ever derived from them. Both constructors run the same
/// derivation, so words entered by an heir reproduce the originating wallet's
/// credential byte for byte, needing no seed, no fingerprint and no database.
///
/// Nothing here is persisted, and the object keeps identity equality: two
/// credentials are never compared by value, which would turn `==` into an oracle
/// for guessing the words.
final class BackupCredential {
  static const wordCount = 12;

  /// Twelve English words are at most 8 characters each plus separators; 256
  /// bounds the work done before anything is parsed.
  static const maxInputLength = 256;

  /// BIP85 HEX application on the words' root: 32 bytes at index 0.
  static const encryptionKeyPath = Bip85Reservations.backupEncryptionKeyPath;

  /// BIP85 Nostr application on the words' root, inside the block the app owns
  /// on every root (see [Bip85Reservations.nostrAppReservedIdentityStart]).
  /// The parent seed's `128002'/100'/1'` is retired; this one lives on a
  /// different root and is a different key. The keychain manifest records
  /// both identities as two-step `bip85Chain` entries under these same paths.
  static const nostrIdentityPath = Bip85Reservations.backupArtifactIdentityPath;
  static const serverIdentityPath = Bip85Reservations.backupServerIdentityPath;

  static final _hashPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final Uint8List _encryptionKey;
  final ECPrivate _nostr;
  final ECPrivate _server;

  BackupCredential._(this._encryptionKey, this._nostr, this._server);

  /// Parses the frozen twelve-word English form.
  ///
  /// Whitespace around and between the words is normalised and case is folded,
  /// because these are backup words rather than a wallet passphrase: a signing
  /// passphrase is significant whitespace and must never be treated this way.
  /// Anything else throws [InvalidBackupWordsException].
  factory BackupCredential.fromWords(String words) {
    if (words.length > maxInputLength) {
      throw const InvalidBackupWordsException();
    }
    final parsed = words.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parsed.length != wordCount) throw const InvalidBackupWordsException();
    final bip39.Mnemonic mnemonic;
    try {
      mnemonic = bip39.Mnemonic.fromWords(words: parsed);
    } on Exception {
      // The mnemonic package quotes the submitted words: discard it entirely.
      throw const InvalidBackupWordsException();
    }
    // The words' own BIP39 root, empty passphrase: what any BIP85 tool loads.
    final root = Bip32Derivation.getCanonicalRootXprvFromSeed(
      Uint8List.fromList(mnemonic.seed),
    );
    return BackupCredential._(
      Uint8List.fromList(
        hex.decode(
          bip85.Bip85Entropy.deriveHex(
            xprvBase58: root,
            numBytes: 32,
            index: 0,
          ),
        ),
      ),
      _signer(root, nostrIdentityPath),
      _signer(root, serverIdentityPath),
    );
  }

  /// The credential of the wallet that owns [seed].
  factory BackupCredential.fromSeed(Seed seed) =>
      BackupCredential.fromWords(deriveWords(seed));

  /// The twelve words [seed] owns, derived at the point of use.
  ///
  /// A standard BIP85 BIP39 child: English, twelve words, at the reserved
  /// index, so a Coldcard holding the seed prints the same words. Only the
  /// reveal use case calls this: the words are never cached, and the credential
  /// itself does not hand them out.
  static String deriveWords(Seed seed) => bip85.Bip85Entropy.deriveMnemonic(
    xprvBase58: Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes),
    language: bip39.Language.english,
    length: bip39.MnemonicLength.words12,
    index: Bip85Reservations.backupWords.index,
  ).sentence;

  /// The 32-byte metadata and artifact encryption key.
  late final String encryptionKeyHex = hex.encode(_encryptionKey);

  /// The x-only public key that authors public backup artifacts.
  late final String nostrPublicKeyHex = hex.encode(
    _nostr.getPublic().toXOnly(),
  );

  /// The x-only public key the backup server account is named by.
  ///
  /// It is a second BIP85 child of the same words rather than a second user
  /// secret, so a public event and a private server account cannot be joined by
  /// their public keys alone.
  late final String serverPublicKeyHex = hex.encode(
    _server.getPublic().toXOnly(),
  );

  String signNostrHash(String hashHex) => _sign(_nostr, hashHex);

  String signServerHash(String hashHex) => _sign(_server, hashHex);

  @override
  String toString() => 'BackupCredential(words: <redacted>)';

  static String _sign(ECPrivate key, String hashHex) {
    if (!_hashPattern.hasMatch(hashHex)) {
      throw ArgumentError('Invalid backup signing digest');
    }
    return key.signBip340(hex.decode(hashHex), tweak: false);
  }

  /// The app's Nostr key convention: the first 32 bytes of the BIP85 entropy
  /// at [path], the same rule every other BIP85 Nostr key in the app follows.
  static ECPrivate _signer(String root, String path) => ECPrivate.fromHex(
    bip85.Bip85Entropy.deriveFromHardenedPath(
      xprvBase58: root,
      path: bip85.Bip85HardenedPath(path),
    ).substring(0, 64),
  );
}
