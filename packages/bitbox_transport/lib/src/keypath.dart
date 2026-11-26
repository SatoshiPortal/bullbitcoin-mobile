/// Helpers for reading a BIP32 keypath.
class BitBoxKeypath {
  BitBoxKeypath._();

  /// The SLIP-132 extended public key type a keypath's purpose implies.
  ///
  /// The prefix of an extended public key encodes the script type it derives,
  /// so requesting the wrong one yields a key a consumer reads as the wrong
  /// kind: a BIP84 account handed out as `xpub` produces a watch-only wallet
  /// on legacy addresses the device will never recognise.
  ///
  /// Throws [ArgumentError] for a purpose with no SLIP-132 prefix, taproot
  /// (BIP86) among them. Guessing is what made the previous default unsafe.
  static String xpubTypeFor(String keypath) {
    final trimmed = keypath.trim();
    final withoutMaster = trimmed.startsWith('m/')
        ? trimmed.substring(2)
        : trimmed;
    final segments = withoutMaster.split('/');
    if (segments.isEmpty || segments.first.isEmpty) {
      throw ArgumentError.value(keypath, 'keypath', 'Not a BIP32 keypath');
    }
    final purpose = segments.first.replaceAll(RegExp(r"['h]$"), '');
    switch (purpose) {
      case '44':
        return 'xpub';
      case '49':
        return 'ypub';
      case '84':
        return 'zpub';
      default:
        throw ArgumentError.value(
          keypath,
          'keypath',
          'No SLIP-132 extended key type for purpose $purpose',
        );
    }
  }
}
