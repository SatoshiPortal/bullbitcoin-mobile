/// The on-disk shape of a secret. **Frozen contract.**
///
/// These bytes are already on users' devices under `seed_<fingerprint>`,
/// written by the freezed union that used to live in
/// `core/seed/data/models/seed_model.dart`. Any drift here silently
/// orphans wallets, and there is no migration path short of asking the
/// user for their backup. Hence: written by hand rather than generated,
/// with the wire keys as named constants, so a rename in the entity can
/// never reach the file format by accident.
///
/// Shape, exactly as emitted by json_serializable before:
///   {"mnemonicWords": [...], "passphrase": null|"...",
///    "runtimeType": "mnemonic"}
///   {"bytes": [12, 34, ...], "runtimeType": "bytes"}
sealed class SecretModel {
  static const _kDiscriminator = 'runtimeType';
  static const _kMnemonic = 'mnemonic';
  static const _kBytes = 'bytes';
  static const _kWords = 'mnemonicWords';
  static const _kPassphrase = 'passphrase';

  /// The word counts BIP39 defines. A stored list of any other length
  /// was never a mnemonic: both generation and import go through bip39,
  /// which refuses every other count.
  static const _wordCounts = {12, 15, 18, 21, 24};

  /// BIP32 seed bounds, in bytes (128 to 512 bits). `Bip32Keys.fromSeed`
  /// refuses anything outside them.
  static const _minSeedBytes = 16;
  static const _maxSeedBytes = 64;

  const SecretModel();

  Map<String, dynamic> toJson();

  /// Decodes a stored entry, or refuses it.
  ///
  /// Every field is checked eagerly, element by element, and the shape
  /// is checked as a whole. `List.cast` is lazy in Dart:
  /// `{"mnemonicWords":[1,2,3]}` would decode without complaint, report
  /// a word count of three, and only throw when something read an
  /// element — and `{"mnemonicWords":[]}` would decode into a wallet
  /// with no words at all. A corrupt entry would then appear in a
  /// listing as an ordinary wallet and fail later, somewhere else. An
  /// entry that cannot be a secret must be refused here, where callers
  /// already know to skip it.
  factory SecretModel.fromJson(Map<String, dynamic> json) {
    return switch (json[_kDiscriminator]) {
      _kMnemonic => MnemonicSecretModel(
        mnemonicWords: _words(json[_kWords]),
        passphrase: _optionalString(json[_kPassphrase], _kPassphrase),
      ),
      _kBytes => BytesSecretModel(bytes: _seedBytes(json[_kBytes])),
      // Fixed string: the discriminator is stored content, never quoted.
      _ => throw const FormatException('unknown secret type'),
    };
  }

  /// Shape only. The *count* is the type's invariant, checked by
  /// [MnemonicSecretModel]'s factory so that it holds however the model
  /// was built — not only on the way in from JSON.
  static List<String> _words(Object? value) {
    if (value is! List) {
      throw FormatException(
        '"$_kWords" must be a list, found ${value.runtimeType}',
      );
    }
    return [
      for (final (index, element) in value.indexed)
        if (element is String)
          element
        else
          throw FormatException('"$_kWords"[$index] must be a string'),
    ];
  }

  /// Shape only; the length is [BytesSecretModel]'s invariant.
  static List<int> _seedBytes(Object? value) {
    if (value is! List) {
      throw FormatException(
        '"$_kBytes" must be a list, found ${value.runtimeType}',
      );
    }
    return [
      for (final (index, element) in value.indexed)
        if (element is int && element >= 0 && element <= 255)
          element
        else
          throw FormatException('"$_kBytes"[$index] must be a byte'),
    ];
  }

  static String? _optionalString(Object? value, String field) {
    if (value == null || value is String) return value as String?;
    throw FormatException('"$field" must be a string or absent');
  }
}

final class MnemonicSecretModel extends SecretModel {
  final List<String> mnemonicWords;

  /// Nullable on purpose: absent passphrases were written as `null`, and
  /// re-writing them as `""` would change the stored bytes. The entity
  /// normalises to `""`; only this layer knows the difference.
  final String? passphrase;

  const MnemonicSecretModel._({required this.mnemonicWords, this.passphrase});

  /// The only way to build one, so the invariant belongs to the type
  /// rather than to whoever remembered to check.
  ///
  /// Throws [FormatException], not [ArgumentError], on a word count
  /// BIP39 does not define: every caller is parsing something that
  /// claims to be a stored secret — from JSON, or from a vault — and a
  /// bad count means those bytes never were one. The layers above treat
  /// a `FormatException` as a corrupt entry and skip it; an
  /// `ArgumentError` would escape as an unexpected failure.
  /// The list is **copied** before anything can await it. A model that
  /// shared its caller's list would let the words change after its
  /// identity was derived and before it was written — filing one secret
  /// under another's fingerprint. See `test/secret_model_test`.
  factory MnemonicSecretModel({
    required List<String> mnemonicWords,
    String? passphrase,
  }) {
    if (!SecretModel._wordCounts.contains(mnemonicWords.length)) {
      throw FormatException(
        '${mnemonicWords.length} words is not a BIP39 word count',
      );
    }
    return MnemonicSecretModel._(
      mnemonicWords: List.unmodifiable(mnemonicWords),
      passphrase: passphrase,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    SecretModel._kWords: mnemonicWords,
    SecretModel._kPassphrase: passphrase,
    SecretModel._kDiscriminator: SecretModel._kMnemonic,
  };
}

final class BytesSecretModel extends SecretModel {
  final List<int> bytes;

  const BytesSecretModel._({required this.bytes});

  /// The only way to build one. See [MnemonicSecretModel] for why a
  /// [FormatException].
  /// Copied like [MnemonicSecretModel], and range-checked here rather
  /// than only in `fromJson`: a byte outside 0..255 is not a byte
  /// however the model was built, and it would be written to the
  /// keystore as an out-of-range JSON number.
  factory BytesSecretModel({required List<int> bytes}) {
    if (bytes.length < SecretModel._minSeedBytes ||
        bytes.length > SecretModel._maxSeedBytes) {
      throw FormatException('${bytes.length} bytes is not a BIP32 seed length');
    }
    for (final (index, byte) in bytes.indexed) {
      if (byte < 0 || byte > 255) {
        throw FormatException('byte $index is $byte, outside 0..255');
      }
    }
    return BytesSecretModel._(bytes: List.unmodifiable(bytes));
  }

  @override
  Map<String, dynamic> toJson() => {
    SecretModel._kBytes: bytes,
    SecretModel._kDiscriminator: SecretModel._kBytes,
  };
}
