import 'package:async/async.dart' hide Result;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/cbf_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/electrum_wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

/// The single [WalletSyncRepository] `WalletLocator` registers. Reads each
/// wallet's persisted [BitcoinSyncBackend] and delegates to
/// [ElectrumWalletSyncRepository] (every wallet today, and every non-Bitcoin
/// wallet always) or [CbfWalletSyncRepository] (Bitcoin wallets that opted
/// into compact block filters), applying the gates that make CBF a
/// developer-only, Tor-aware choice.
///
/// A wallet's backend selection never changes here — this class only reads
/// [WalletMetadataDatasource.bitcoinSyncBackend]; nothing in this repository
/// migrates a wallet between backends.
///
/// Unlike an earlier version of this class, a CBF-backend wallet with no
/// [WalletMetadataModel.syncedAt] yet is routed to CBF directly, not
/// silently bootstrapped through Electrum first: `CbfScanTypeResolver` now
/// starts that first sync as a `bdk.RecoveryScanType` anchored at the
/// wallet's own persisted [WalletMetadataModel.birthdayCheckpoint] — a
/// verified `(height, hash)` pair — rather than assuming a `SyncScanType`
/// would be safe. See `CbfScanTypeResolver`'s class doc for the full
/// `SyncScanType`-vs-`RecoveryScanType` decision (including how it detects
/// and recovers from a wallet's local BDK state going missing even after
/// `syncedAt` is set) and for why a wallet with no persisted checkpoint at
/// all fails the CBF attempt explicitly (`CbfMissingBirthdayCheckpointException`)
/// rather than this repository falling back to Electrum for it.
class WalletSyncRoutingRepository implements WalletSyncRepository {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SettingsRepository _settingsRepository;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailable;
  final ElectrumWalletSyncRepository _electrum;
  final CbfWalletSyncRepository _cbf;

  WalletSyncRoutingRepository({
    required this._walletMetadataDatasource,
    required this._settingsRepository,
    required CheckCompactBlockFiltersAvailableUsecase
    checkCompactBlockFiltersAvailableUsecase,
    required ElectrumWalletSyncRepository electrumWalletSyncRepository,
    required CbfWalletSyncRepository cbfWalletSyncRepository,
  }) : _checkCompactBlockFiltersAvailable =
           checkCompactBlockFiltersAvailableUsecase,
       _electrum = electrumWalletSyncRepository,
       _cbf = cbfWalletSyncRepository;

  @override
  Future<Result<void, WalletSyncFailure>> startSync({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      return const Err(WalletSyncWalletNotFoundFailure());
    }

    final wantsCbf =
        metadata.isBitcoin &&
        metadata.bitcoinSyncBackend == BitcoinSyncBackend.compactBlockFilters;
    if (!wantsCbf) {
      return _electrum.startSync(walletId: walletId);
    }

    final gate = await _checkCbfGate();
    if (gate != null) {
      log.fine(switch (gate) {
        WalletSyncTorUnsupportedFailure() =>
          'CBF sync blocked: unsupported network configuration',
        WalletSyncDeveloperGateClosedFailure() =>
          'CBF sync blocked: feature gate closed',
        _ => 'CBF sync blocked',
      });
      return Err(gate);
    }

    log.fine('CBF sync routed to compact filters');
    return _cbf.startSync(walletId: walletId);
  }

  @override
  Stream<WalletSyncProgress> watchProgress() =>
      StreamGroup.merge([_electrum.watchProgress(), _cbf.watchProgress()]);

  @override
  Future<void> cancelSync({required String walletId}) async {
    // Forwarded to both regardless of the current backend: Electrum's
    // cancellation is already a documented no-op, so this is safe even
    // when only one backend actually has an in-flight attempt.
    await Future.wait([
      _electrum.cancelSync(walletId: walletId),
      _cbf.cancelSync(walletId: walletId),
    ]);
  }

  /// Checked in this order deliberately: Tor is checked directly (not
  /// folded into [CheckCompactBlockFiltersAvailableUsecase]'s single bool)
  /// so a Tor-enabled user gets [WalletSyncTorUnsupportedFailure] rather
  /// than the generic [WalletSyncDeveloperGateClosedFailure] — V1's
  /// compact-filter peer connections do not route through the configured
  /// Tor proxy (see `docs/compact-block-filters-pr-roadmap.md`). Every
  /// other reason CBF is unavailable (production build without
  /// `ENABLE_CBF`, or developer mode disabled) collapses to the single
  /// developer-gate failure — the gate itself is the whole story.
  Future<WalletSyncFailure?> _checkCbfGate() async {
    final settings = await _settingsRepository.fetch();
    if (settings.useTorProxy) {
      return const WalletSyncTorUnsupportedFailure();
    }

    final available = await _checkCompactBlockFiltersAvailable.execute();
    if (!available) return const WalletSyncDeveloperGateClosedFailure();

    return null;
  }
}
