import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:flutter/widgets.dart';

extension KeychainManifestFailureL10n on KeychainManifestFailure {
  String toTranslated(BuildContext context) => switch (this) {
    KeychainManifestStorageFailure() ||
    KeychainManifestSeedFailure() ||
    KeychainManifestInvalidKeyFailure() => context.loc.settingsNostrKeysFailure,
  };
}
