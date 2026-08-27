import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_display.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:flutter/widgets.dart';

extension KeychainManifestFailureL10n on KeychainManifestFailure {
  String toTranslated(BuildContext context) => switch (this) {
    KeychainManifestMalformedFileFailure() ||
    KeychainManifestUnsupportedVersionFailure() ||
    KeychainManifestParentMismatchFailure() ||
    KeychainManifestUnknownReservationFailure() ||
    KeychainManifestEmptyFailure() ||
    KeychainManifestConflictFailure() ||
    KeychainManifestStorageFailure() ||
    KeychainManifestSeedFailure() ||
    KeychainManifestDerivationFailure() ||
    KeychainManifestUnexpectedFailure() => context.loc.settingsNostrKeysFailure,
  };
}

extension KeychainManifestEntryL10n on KeychainManifestEntry {
  String displayName(BuildContext context) {
    final key = materializations.single as KeychainManifestNostrKey;
    return switch (KeychainManifestNostrKeyDisplay.of(this).systemKind) {
      KeychainManifestNostrSystemKind.metadataBackup =>
        context.loc.settingsNostrKeysSystemMetadataBackup,
      KeychainManifestNostrSystemKind.bullnymAuth =>
        context.loc.settingsNostrKeysSystemBullnymAuth,
      KeychainManifestNostrSystemKind.nip05Verification =>
        context.loc.settingsNostrKeysSystemNip05Verification,
      KeychainManifestNostrSystemKind.none => key.purpose,
    };
  }

  String? description(BuildContext context) =>
      switch (KeychainManifestNostrKeyDisplay.of(this).systemKind) {
        KeychainManifestNostrSystemKind.metadataBackup =>
          context.loc.settingsNostrKeysSystemMetadataBackupDescription,
        KeychainManifestNostrSystemKind.bullnymAuth =>
          context.loc.settingsNostrKeysSystemBullnymAuthDescription,
        KeychainManifestNostrSystemKind.nip05Verification =>
          context.loc.settingsNostrKeysSystemNip05VerificationDescription,
        KeychainManifestNostrSystemKind.none =>
          (materializations.single as KeychainManifestNostrKey).description,
      };
}

extension NostrKeyFormErrorL10n on NostrKeyFormError {
  String toTranslated(BuildContext context) => switch (this) {
    NostrKeyFormError.nameRequired =>
      context.loc.settingsNostrKeysNameRequiredError,
    NostrKeyFormError.nameTooLong =>
      context.loc.settingsNostrKeysNameTooLongError,
    NostrKeyFormError.descriptionTooLong =>
      context.loc.settingsNostrKeysDescriptionTooLongError,
    NostrKeyFormError.invalidCharacters =>
      context.loc.settingsNostrKeysInvalidCharactersError,
  };
}
