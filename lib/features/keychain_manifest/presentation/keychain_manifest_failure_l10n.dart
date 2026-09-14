import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
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

extension NostrKeyFormFailureL10n on NostrKeyFormFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NostrKeyFormFailure.nameRequired =>
      context.loc.settingsNostrKeysNameRequiredError,
    NostrKeyFormFailure.nameTooLong =>
      context.loc.settingsNostrKeysNameTooLongError,
    NostrKeyFormFailure.descriptionTooLong =>
      context.loc.settingsNostrKeysDescriptionTooLongError,
    NostrKeyFormFailure.invalidNameCharacters ||
    NostrKeyFormFailure.invalidDescriptionCharacters =>
      context.loc.settingsNostrKeysInvalidCharactersError,
  };
}
