import 'package:async/async.dart' show StreamGroup;
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/auto_swap_settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_portable_settings_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

final class WalletMetadataBackupRepositoryImpl
    implements WalletMetadataBackupRepository {
  final SqliteDatabase _database;
  final LabelsFacade _labels;
  final FrozenWalletUtxoDatasource _frozen;
  final SettingsDatasource _settings;
  final AutoSwapSettingsRepository _autoSwap;
  final PayjoinPolicyAccess _payjoin;
  final ElectrumServerStorageDatasource _electrumServers;
  final ElectrumSettingsStorageDatasource _electrumSettings;
  final MempoolServerStorageDatasource _mempoolServers;
  final MempoolSettingsStorageDatasource _mempoolSettings;

  const WalletMetadataBackupRepositoryImpl({
    required this._database,
    required this._labels,
    required this._frozen,
    required this._settings,
    required this._autoSwap,
    required this._payjoin,
    required this._electrumServers,
    required this._electrumSettings,
    required this._mempoolServers,
    required this._mempoolSettings,
  });

  @override
  Stream<void> get changes => StreamGroup.merge([
    _labels.watchChanges(),
    _frozen.changes,
    _settings.changes,
    _autoSwap.watchAutoSwapParams().map((_) {}),
    _payjoin.watch().map((_) {}),
    _electrumServers.changes,
    _electrumSettings.changes,
    _mempoolServers.changes,
    _mempoolSettings.changes,
  ]);

  @override
  Future<Result<WalletMetadataBackup, WalletBackupFailure>> capture(
    Map<String, String> walletReferences,
  ) async {
    try {
      // Payjoin owns a separate store. The coordinator observes its stream and
      // reconciles the captured content; this read is not a cross-store lock.
      final policy = await _payjoin.load();
      if (policy case Err()) {
        return const Err(WalletBackupStorageFailure());
      }
      return await _database.transaction(() async {
        final labels = await _labels.fetchAllForBackup();
        if (labels case Err()) {
          return const Err(WalletBackupIncompleteFailure());
        }
        final freezes = await _frozen.getAllFrozen();
        final app = await _settings.fetch();
        final autoSwap = await _autoSwap.getAutoSwapParams();
        final electrum = <PortableElectrumSettings>[];
        for (final network in ElectrumServerNetwork.values) {
          final prefs = await _electrumSettings.fetchByNetwork(network);
          final servers = await _electrumServers.fetchCustomServersByNetwork(
            network,
          );
          servers.sort((a, b) {
            final priority = a.priority.compareTo(b.priority);
            return priority == 0 ? a.url.compareTo(b.url) : priority;
          });
          electrum.add(
            PortableElectrumSettings(
              network: network,
              servers: [
                for (final server in servers)
                  PortableElectrumServer(
                    url: server.url,
                    priority: server.priority,
                  ),
              ],
              validateDomain: prefs.validateDomain,
              stopGap: prefs.stopGap,
              timeout: prefs.timeout,
              retry: prefs.retry,
            ),
          );
        }
        final mempool = <PortableMempoolSettings>[];
        for (final network in MempoolServerNetwork.values) {
          final server = await _mempoolServers.fetchCustomServerByNetwork(
            network,
          );
          final prefs = await _mempoolSettings.fetchByNetwork(network);
          mempool.add(
            PortableMempoolSettings(
              network: network,
              customUrl: server?.toEntity().fullUrl,
              useForFeeEstimation: prefs.useForFeeEstimation,
            ),
          );
        }
        return Ok(
          WalletMetadataBackup(
            labels: [
              for (final label
                  in (labels as Ok<List<LabelEntity>, LabelFailure>).value)
                LabelEntity(
                  id: 0,
                  type: label.type,
                  label: label.label,
                  reference: label.reference,
                  origin: walletReferences[label.origin] ?? label.origin,
                ),
            ],
            frozenOutputs: [
              for (final output in freezes)
                BackupFrozenOutput(
                  walletReference: output.walletId.isEmpty
                      ? null
                      : _reference(walletReferences, output.walletId),
                  txId: output.txId.toLowerCase(),
                  vout: output.vout,
                ),
            ],
            settings: WalletPortableSettingsBackup(
              app: PortableAppSettings(
                bitcoinUnit: app.bitcoinUnit,
                currency: app.currency,
                language: app.language,
                themeMode: app.themeMode,
                hideAmounts: app.hideAmounts,
              ),
              autoSwap: PortableAutoSwapSettings(
                enabled: autoSwap.enabled,
                balanceThresholdSats: autoSwap.balanceThresholdSats,
                triggerBalanceSats: autoSwap.triggerBalanceSats,
                feeThresholdPercent: autoSwap.feeThresholdPercent,
                alwaysBlock: autoSwap.alwaysBlock,
                recipientWalletReference: autoSwap.recipientWalletId == null
                    ? null
                    : _reference(walletReferences, autoSwap.recipientWalletId!),
              ),
              payjoin: (policy as Ok<PayjoinPolicy, PayjoinFailure>).value,
              electrum: electrum,
              mempool: mempool,
            ),
          ),
        );
      });
    } on FormatException {
      return const Err(WalletBackupIncompleteFailure());
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }

  String _reference(Map<String, String> references, String walletId) =>
      references[walletId] ??
      (throw const FormatException('Missing wallet reference'));
}
