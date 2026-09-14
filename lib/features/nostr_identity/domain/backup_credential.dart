import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/hkdf.dart';

/// Which of the credential's two signing identities an operation uses.
///
/// One credential, two scalars: the public artifact author and the private
/// server account are deliberately not the same public key (decision 6).
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
/// Twelve words derived from the originating default seed at the reserved BIP85
/// path open the metadata backup, authenticate its server account and author the
/// public vault events. Both constructors run the same derivation, so words
/// entered by an heir reproduce the originating wallet's credential byte for
/// byte.
///
/// Deriving from the words rather than from the raw BIP85 entropy is what makes
/// the server read seed-independent: a holder of the words needs no seed, no
/// fingerprint and no local database.
///
/// Nothing here is persisted, and the object keeps identity equality: two
/// credentials are never compared by value, which would turn `==` into an oracle
/// for guessing the words.
final class BackupCredential {
  static const wordCount = 12;

  /// Twelve English words are at most 8 characters each plus separators; 256
  /// bounds the work done before anything is parsed.
  static const maxInputLength = 256;

  static const _salt = 'bullbitcoin-backup-password';
  static const _mnemonicInfo = 'mnemonic-v1';
  static const _encryptionInfo = 'encryption-v1';
  static const _nostrInfo = 'nostr-auth-v1';
  static const _serverInfo = 'server-auth-v1';
  static final _hashPattern = RegExp(r'^[0-9a-fA-F]{64}$');
  static final _order = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

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
    final List<int> entropy;
    try {
      entropy = bip39.Mnemonic.fromWords(words: parsed).entropy;
    } on Exception {
      // The mnemonic package quotes the submitted words: discard it entirely.
      throw const InvalidBackupWordsException();
    }
    final encryptionKey = _hkdf(entropy, _encryptionInfo, 32);
    return BackupCredential._(
      encryptionKey,
      _signer(encryptionKey, _nostrInfo),
      _signer(encryptionKey, _serverInfo),
    );
  }

  /// The credential of the wallet that owns [seed].
  factory BackupCredential.fromSeed(Seed seed) =>
      BackupCredential.fromWords(deriveWords(seed));

  /// The twelve words [seed] owns, derived at the point of use.
  ///
  /// Only the reveal use case calls this: the words are never cached, and the
  /// credential itself does not hand them out.
  static String deriveWords(Seed seed) => bip39.Mnemonic(
    _hkdf(
      hex.decode(
        bip85.Bip85Entropy.deriveFromHardenedPath(
          xprvBase58: Bip32Derivation.getCanonicalRootXprvFromSeed(seed.bytes),
          path: bip85.Bip85HardenedPath(
            Bip85Reservations.walletBackupEncryptionKey.path,
          ),
        ),
      ),
      _mnemonicInfo,
      16,
    ),
    bip39.Language.english,
  ).sentence;

  /// The 32-byte metadata and artifact encryption key.
  late final String encryptionKeyHex = hex.encode(_encryptionKey);

  /// The x-only public key that authors public backup artifacts.
  late final String nostrPublicKeyHex = hex.encode(
    _nostr.getPublic().toXOnly(),
  );

  /// The x-only public key the backup server account is named by.
  ///
  /// It is a second scalar from the same credential rather than a second user
  /// secret, so a public event and a private server account cannot be joined by
  /// their public keys alone (decision 6).
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

  static ECPrivate _signer(Uint8List root, String info) {
    for (var counter = 0; counter < 256; counter++) {
      final digest = Hmac(
        sha256,
        root,
      ).convert([...utf8.encode(info), 0, counter]);
      final scalar = BigInt.parse(digest.toString(), radix: 16);
      if (scalar > BigInt.zero && scalar < _order) {
        return ECPrivate.fromHex(digest.toString());
      }
    }
    throw StateError('Backup identity derivation exhausted its counter');
  }

  static Uint8List _hkdf(List<int> input, String info, int length) {
    final output = Uint8List(length);
    HKDFKeyDerivator(SHA256Digest())
      ..init(
        HkdfParameters(
          Uint8List.fromList(input),
          length,
          Uint8List.fromList(utf8.encode(_salt)),
          Uint8List.fromList(utf8.encode(info)),
        ),
      )
      ..deriveKey(null, 0, output, 0);
    return output;
  }
}
