import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';

final class GetGetPaidSettingsUsecase {
  final KeychainManifestFacade keychainManifest;

  const GetGetPaidSettingsUsecase(this.keychainManifest);

  Future<GetPaidSettings> execute() async {
    final state = await keychainManifest.getBackupState();
    return _map(state);
  }

  Stream<GetPaidSettings> watch() =>
      keychainManifest.watchBackupState().map(_map).distinct(_sameSettings);

  GetPaidSettings _map(KeychainManifestBackupState state) => GetPaidSettings(
    automatedBackupEnabled: state.enabled,
    backupPending: state.dirty,
    lastBackedUpAt: state.lastSucceededAt,
    unsupportedVersion: state.unsupportedVersion,
  );

  bool _sameSettings(GetPaidSettings previous, GetPaidSettings next) =>
      previous.automatedBackupEnabled == next.automatedBackupEnabled &&
      previous.backupPending == next.backupPending &&
      previous.lastBackedUpAt == next.lastBackedUpAt &&
      previous.unsupportedVersion == next.unsupportedVersion;
}
