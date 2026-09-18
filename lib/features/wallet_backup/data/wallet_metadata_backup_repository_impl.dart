import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/core/utils/mempool_url_parser.dart';
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
  final SettingsRepository _settingsWriter;
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
    required this._settingsWriter,
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

  @override
  Future<Result<void, WalletBackupFailure>> apply(
    WalletMetadataBackup metadata,
    Map<String, String> walletIds,
  ) async {
    try {
      final desired = metadata.settings;
      final recipientReference = desired.autoSwap.recipientWalletReference;
      final recipient = recipientReference == null
          ? null
          : _reference(walletIds, recipientReference);
      final freezes = [
        for (final output in metadata.frozenOutputs)
          (
            walletId: output.walletReference == null
                ? ''
                : _reference(walletIds, output.walletReference!),
            txId: output.txId,
            vout: output.vout,
          ),
      ];
      await _database.transaction(() async {
        final labels = await _labels.fetchAllForBackup();
        if (labels case Err()) {
          throw const _MetadataWriteException();
        }
        final current = {
          for (final label
              in (labels as Ok<List<LabelEntity>, LabelFailure>).value)
            (label.label, label.reference): label,
        };
        for (final label in metadata.labels) {
          final origin = walletIds[label.origin] ?? label.origin;
          final existing = current[(label.label, label.reference)];
          if (existing != null) {
            if (existing.type != label.type || existing.origin != origin) {
              throw const FormatException('Conflicting label identity');
            }
            continue;
          }
          if (await _labels.store(
                NewLabel(
                  type: label.type,
                  reference: label.reference,
                  label: label.label,
                  origin: origin,
                ),
              )
              case Err()) {
            throw const _MetadataWriteException();
          }
        }
        for (final output in freezes) {
          await _frozen.freezeOutpoints(
            walletId: output.walletId,
            outpoints: [(txId: output.txId, vout: output.vout)],
          );
        }
        final desiredServers = [
          for (final network in desired.electrum)
            for (final server in network.servers)
              ElectrumServerModel(
                url: server.url,
                network: network.network,
                priority: server.priority,
                isCustom: true,
              ),
        ];
        final desiredUrls = desiredServers.map((s) => s.url).toSet();
        for (final server in await _electrumServers.fetchAllServers(
          isCustom: true,
        )) {
          if (!desiredUrls.contains(server.url) &&
              !await _electrumServers.deleteServer(server.url)) {
            throw const _MetadataWriteException();
          }
        }
        await _electrumServers.storeBatch(desiredServers);
        for (final network in desired.electrum) {
          final previous = await _electrumSettings.fetchByNetwork(
            network.network,
          );
          await _electrumSettings.store(
            ElectrumSettingsModel(
              network: network.network,
              validateDomain: network.validateDomain,
              stopGap: network.stopGap,
              timeout: network.timeout,
              retry: network.retry,
              socks5: previous.socks5,
            ),
          );
        }
        for (final network in desired.mempool) {
          final url = network.customUrl;
          if (url == null) {
            final previous = await _mempoolServers.fetchCustomServerByNetwork(
              network.network,
            );
            if (previous != null &&
                !await _mempoolServers.deleteCustomServer(network.network)) {
              throw const _MetadataWriteException();
            }
          } else {
            final parsed = MempoolUrlParser.tryParse(url)!;
            await _mempoolServers.store(
              MempoolServerModel(
                url: parsed.cleanUrl,
                isTestnet: network.network.isTestnet,
                isLiquid: network.network.isLiquid,
                isCustom: true,
                enableSsl: parsed.enableSsl,
              ),
            );
          }
          await _mempoolSettings.store(
            MempoolSettingsModel(
              network: network.network.networkString,
              useForFeeEstimation: network.useForFeeEstimation,
            ),
          );
        }
      });
      // These owners emit their own value streams. Preserve their normal write
      // semantics instead of emitting values from a transaction that can roll back.
      await _settingsWriter.setBitcoinUnit(desired.app.bitcoinUnit);
      await _settingsWriter.setCurrency(desired.app.currency);
      await _settingsWriter.setLanguage(desired.app.language);
      await _settingsWriter.setThemeMode(desired.app.themeMode);
      await _settingsWriter.setHideAmounts(desired.app.hideAmounts);
      final previousSwap = await _autoSwap.getAutoSwapParams();
      await _autoSwap.updateAutoSwapParams(
        AutoSwap(
          enabled: desired.autoSwap.enabled && recipient != null,
          balanceThresholdSats: desired.autoSwap.balanceThresholdSats,
          triggerBalanceSats: desired.autoSwap.triggerBalanceSats,
          feeThresholdPercent: desired.autoSwap.feeThresholdPercent,
          alwaysBlock: desired.autoSwap.alwaysBlock,
          recipientWalletId: recipient,
          blockTillNextExecution: previousSwap.blockTillNextExecution,
          showWarning: previousSwap.showWarning,
        ),
      );
      if (await _payjoin.setMinimumAmount(desired.payjoin.minimumAmount)
          case Err()) {
        return const Err(WalletBackupIncompleteFailure());
      }
      if (await _payjoin.setSessionLifetime(desired.payjoin.sessionLifetime)
          case Err()) {
        return const Err(WalletBackupIncompleteFailure());
      }
      if (await _payjoin.setEnabled(desired.payjoin.enabled) case Err()) {
        return const Err(WalletBackupIncompleteFailure());
      }
      return const Ok(null);
    } on Exception {
      // The common recovery flow owns the durable fence. Never turn a partial
      // application or a preserved conflict into a successful recovery.
      return const Err(WalletBackupIncompleteFailure());
    }
  }

  String _reference(Map<String, String> references, String walletId) =>
      references[walletId] ??
      (throw const FormatException('Missing wallet reference'));
}

final class _MetadataWriteException implements Exception {
  const _MetadataWriteException();
}
