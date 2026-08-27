/// BIP purpose and script type.
enum ScriptType {
  bip84(purpose: 84),
  bip49(purpose: 49),
  bip44(purpose: 44);

  final int purpose;

  const ScriptType({required this.purpose});

  factory ScriptType.fromName(String name) => values.firstWhere(
    (script) => script.name == name,
    orElse: () => throw ArgumentError.value(name, 'name', 'unknown ScriptType'),
  );

  /// Non-throwing parse for untrusted input.
  static ScriptType? tryFromName(String name) {
    for (final script in values) {
      if (script.name == name) return script;
    }
    return null;
  }

  factory ScriptType.fromExtendedPublicKey(String extendedPublicKey) {
    if (extendedPublicKey.length < 4) {
      throw ArgumentError.value(
        extendedPublicKey,
        'extendedPublicKey',
        'too short',
      );
    }
    return switch (extendedPublicKey.substring(0, 4)) {
      'xpub' || 'tpub' => ScriptType.bip44,
      'ypub' || 'upub' => ScriptType.bip49,
      'zpub' || 'vpub' => ScriptType.bip84,
      _ => throw ArgumentError.value(
        extendedPublicKey,
        'extendedPublicKey',
        'unknown xpub prefix',
      ),
    };
  }
}
