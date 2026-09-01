import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

/// The label and hint rules both manifest writers apply (spec 6.6).
///
/// Creation and later edits have to agree on them: a hint the app accepts at
/// creation but refuses to edit, or the other way round, is a rule that has
/// drifted rather than a rule.
abstract final class PassphraseWalletMetadataRules {
  /// Blank is no value: an empty label displays as the default name, and an
  /// empty hint is no hint.
  static String? normalize(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool rejectsLabel(String? value) =>
      _rejects(value, KeychainManifestWallet.maxLabelLength);

  static bool rejectsHint(String? value) =>
      _rejects(value, KeychainManifestEntry.maxDescriptionLength);

  static bool _rejects(String? value, int limit) =>
      value != null &&
      (value.length > limit ||
          KeychainManifestNostrKey.hasControlCharacter(value));
}
