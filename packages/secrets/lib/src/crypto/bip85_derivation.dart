import 'dart:math';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart' as conv;

import 'package:secrets/src/domain/value_objects/mnemonic_length.dart' as vo;

/// Pure-Dart BIP85 derivation. Ports the app's `RecoverbullBip85Utils` +
/// `bip85_datasource` derivations onto the package. INTERNAL.
class Bip85Crypto {
  static final bip85.CustomApplication recoverbullApp =
      bip85.CustomApplication.fromNumber(1608);

  /// ARK: `m/83696968'/128169'/32'/11811'`, 32 bytes (dev-mode feature).
  static const int arkIndex = 11811;
  static const int arkLength = 32;

  /// Validates a templated BIP85 path through the library's
  /// [bip85.Bip85HardenedPath] (every component must be hardened). A missing
  /// `'` in a string template would silently derive the WRONG key; this turns
  /// that into a thrown error. Returns the path unchanged when valid, so the
  /// derived output (and the KAT vectors) are untouched.
  static String _validatedPath(String path) =>
      bip85.Bip85HardenedPath(path).toString();

  /// Strips a LEADING `m/`, a LEADING `83696968'/` (the BIP85 root purpose, for
  /// an absolute path), and a LEADING `1608'/` app-number from a recoverbull
  /// path. `m/1608'/0'/586053381`, `1608'/0'/586053381`, and
  /// `m/83696968'/1608'/0'/586053381` all → `0'/586053381`. Anchored (not global
  /// `replaceAll`) so a `1608` appearing as a later path element is never
  /// stripped (would derive the wrong key).
  static String clearRecoverbullPath(String path) {
    var p = path;
    if (p.startsWith('m/')) p = p.substring(2);
    const rootPrefix = "83696968'/";
    if (p.startsWith(rootPrefix)) p = p.substring(rootPrefix.length);
    final appPrefix = "${recoverbullApp.number}'/";
    if (p.startsWith(appPrefix)) p = p.substring(appPrefix.length);
    return p;
  }

  /// The 32-byte recoverbull backup key (hex) for a recoverbull path.
  static String deriveBackupKeyHex(String xprvBase58, String recoverbullPath) {
    final cleared = clearRecoverbullPath(recoverbullPath);
    final entropy = bip85.Bip85Entropy.derive(
      xprvBase58: xprvBase58,
      application: recoverbullApp,
      path: cleared,
    );
    return conv.hex.encode(entropy.sublist(0, 32));
  }

  /// A BIP85 child BIP39 mnemonic.
  static bip39.Mnemonic deriveChildMnemonic({
    required String xprvBase58,
    required vo.MnemonicLength length,
    required int index,
    bip39.Language language = bip39.Language.english,
  }) {
    return bip85.Bip85Entropy.deriveMnemonic(
      xprvBase58: xprvBase58,
      language: language,
      length: length.asBip39,
      index: index,
    );
  }

  /// The BIP85 mnemonic derivation path string (for display/indexing):
  /// `{39}'/{langCode}'/{wordCount}'/{index}'`. English = 0.
  static String childMnemonicPath({
    required vo.MnemonicLength length,
    required int index,
  }) =>
      _validatedPath("39'/0'/${length.words}'/$index'");

  /// Raw hex entropy of [numBytes] bytes at the hex application, given [index].
  static String deriveHex({
    required String xprvBase58,
    required int numBytes,
    required int index,
  }) =>
      bip85.Bip85Entropy.deriveHex(
        xprvBase58: xprvBase58,
        numBytes: numBytes,
        index: index,
      );

  /// The ARK secret bytes (32) at index 11811.
  static Uint8List deriveArk(String xprvBase58) {
    final hexStr = deriveHex(
      xprvBase58: xprvBase58,
      numBytes: arkLength,
      index: arkIndex,
    );
    return Uint8List.fromList(conv.hex.decode(hexStr));
  }

  static String arkPath() => _validatedPath("128169'/32'/$arkIndex'");

  /// A fresh recoverbull backup-key path `1608'/0'/{randomIndex}'`
  /// (matches the app's `generateBackupKeyPath`).
  static String generateRecoverbullPath() {
    final index = Random.secure().nextInt((1 << 31) - 1);
    return _validatedPath("${recoverbullApp.number}'/0'/$index'");
  }
}
