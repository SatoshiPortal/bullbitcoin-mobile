import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class GetWalletBackupContentsUsecase {
  final Future<List<WalletDefinition>> Function() _wallets;
  final Future<Result<List<WalletPreferences>, WalletPreferencesFailure>>
  Function()
  _preferences;
  final Future<
    Result<WalletMetadataSnapshotInventory, WalletMetadataBackupFailure>
  >
  Function()
  _metadata;

  const GetWalletBackupContentsUsecase(
    this._wallets,
    this._preferences,
    this._metadata,
  );

  @useResult
  Future<Result<WalletBackupContents, WalletBackupFailure>> execute() async {
    try {
      final definitions = await _wallets();
      final List<WalletPreferences> preferences;
      switch (await _preferences()) {
        case Ok(:final value):
          preferences = value;
        case Err(:final failure):
          return Err(
            WalletBackupStorageFailure(failure.runtimeType.toString()),
          );
      }
      final metadata = await _metadata();
      switch (metadata) {
        case Err(:final failure):
          return Err(
            WalletBackupManifestFailure(failure.runtimeType.toString()),
          );
        case Ok(:final value):
          final labels = <String, String>{};
          for (final preference in preferences) {
            final label = preference.label;
            if (label != null) labels[preference.walletRef] = label;
          }
          final wallets =
              definitions
                  .map(
                    (definition) => WalletBackupWalletSummary(
                      label: labels[definition.walletRef],
                      network: definition.network,
                      provenance: definition.provenance,
                      signerDevice: definition.signerDevice,
                      birthday: definition.birthday,
                      seedPassphraseUsed: definition.seedPassphraseUsed,
                    ),
                  )
                  .toList(growable: false)
                ..sort(_compareWallets);
          final sections = value.sections
              .map(
                (section) => WalletBackupMetadataSummary(
                  recordType: section.type,
                  recordCount: section.recordCount,
                ),
              )
              .toList(growable: false);
          return Ok(WalletBackupContents(wallets: wallets, metadata: sections));
      }
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to read wallet backup contents',
        error: error.runtimeType,
        trace: trace,
      );
      return Err(WalletBackupStorageFailure(error.runtimeType.toString()));
    }
  }
}

int _compareWallets(
  WalletBackupWalletSummary left,
  WalletBackupWalletSummary right,
) {
  final byNetwork = left.network.index.compareTo(right.network.index);
  if (byNetwork != 0) return byNetwork;
  final byProvenance = left.provenance.index.compareTo(right.provenance.index);
  if (byProvenance != 0) return byProvenance;
  return (left.label ?? '').compareTo(right.label ?? '');
}
