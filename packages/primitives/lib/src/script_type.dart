/// BIP purpose / script type. Ported verbatim from the app's
/// `lib/core/wallet/domain/entities/wallet.dart`.
enum ScriptType {
  bip84(purpose: 84),
  bip49(purpose: 49),
  bip44(purpose: 44);

  final int purpose;

  const ScriptType({required this.purpose});

  factory ScriptType.fromName(String name) {
    return ScriptType.values.firstWhere(
      (script) => script.name == name,
      orElse: () =>
          throw ArgumentError.value(name, 'name', 'unknown ScriptType'),
    );
  }

  /// Non-throwing parse for untrusted input.
  static ScriptType? tryFromName(String name) {
    for (final s in ScriptType.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  factory ScriptType.fromExtendedPublicKey(String extendedPublicKey) {
    if (extendedPublicKey.length < 4) {
      throw ArgumentError.value(
          extendedPublicKey, 'extendedPublicKey', 'too short');
    }
    switch (extendedPublicKey.substring(0, 4)) {
      case 'xpub':
      case 'tpub': // testnet legacy
        return ScriptType.bip44;
      case 'ypub':
      case 'upub': // testnet nested segwit
        return ScriptType.bip49;
      case 'zpub':
      case 'vpub': // testnet native segwit
        return ScriptType.bip84;
      default:
        throw ArgumentError.value(
            extendedPublicKey, 'extendedPublicKey', 'unknown xpub prefix');
    }
  }
}
