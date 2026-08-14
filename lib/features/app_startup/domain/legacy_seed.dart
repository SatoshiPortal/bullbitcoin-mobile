import 'dart:convert';

/// A recovery phrase left behind by a pre-v5 (2023–2024 "BULL") install.
///
/// Those builds always stored the seed material itself in secure storage,
/// keyed by fingerprint, as JSON:
/// `{ "mnemonic": "...", "mnemonicFingerprint": "...", "passphrases": [...] }`.
/// Hive only ever held the wallet index, which is why this type can be read
/// without it.
class LegacySeed {
  final String mnemonic;
  final String fingerprint;

  /// Non-empty passphrases attached to this seed. A user who set one needs
  /// it on top of the mnemonic to recover — omitting it would strand funds.
  final List<String> passphrases;

  const LegacySeed({
    required this.mnemonic,
    required this.fingerprint,
    required this.passphrases,
  });

  List<String> get words => mnemonic.split(' ');

  /// Parses one secure-storage entry into a [LegacySeed], or null when the
  /// entry is not a legacy seed — other keys share the store, so entries are
  /// discriminated strictly: valid JSON, non-empty mnemonic and fingerprint,
  /// and the storage key must equal the fingerprint.
  static LegacySeed? tryFromSecureStorageEntry(String key, String value) {
    try {
      final obj = json.decode(value);
      if (obj is! Map<String, dynamic>) return null;

      final mnemonic = obj['mnemonic'];
      final fingerprint = obj['mnemonicFingerprint'];
      if (mnemonic is! String || mnemonic.isEmpty) return null;
      if (fingerprint is! String || fingerprint.isEmpty) return null;
      if (key != fingerprint) return null;

      return LegacySeed(
        mnemonic: mnemonic,
        fingerprint: fingerprint,
        passphrases: [
          for (final p in obj['passphrases'] as List? ?? const [])
            if (p case {'passphrase': final String passphrase})
              if (passphrase.isNotEmpty) passphrase,
        ],
      );
    } catch (_) {
      return null;
    }
  }
}
