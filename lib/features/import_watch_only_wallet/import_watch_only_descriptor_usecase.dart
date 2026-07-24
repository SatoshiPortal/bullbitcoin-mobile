import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:meta/meta.dart';

class ImportWatchOnlyDescriptorUsecase {
  final WalletRepository _wallet;
  final SettingsRepository _settings;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailable;
  final ResolveWalletBirthdayCheckpointUsecase _resolveWalletBirthdayCheckpoint;

  ImportWatchOnlyDescriptorUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
    required CheckCompactBlockFiltersAvailableUsecase
    checkCompactBlockFiltersAvailableUsecase,
    required ResolveWalletBirthdayCheckpointUsecase
    resolveWalletBirthdayCheckpointUsecase,
  }) : _wallet = walletRepository,
       _settings = settingsRepository,
       _checkCompactBlockFiltersAvailable =
           checkCompactBlockFiltersAvailableUsecase,
       _resolveWalletBirthdayCheckpoint =
           resolveWalletBirthdayCheckpointUsecase;

  /// Wraps the still-throwing core [WalletRepository]; this use-case is the
  /// boundary that catches the raw rejection, logs it, and maps it to a
  /// sanitized [ImportWatchOnlyFailure].
  ///
  /// [requestedSyncBackend] is the user's explicit choice from the import
  /// screen; `null` preserves the previous automatic behaviour (driven
  /// solely by `useCompactBlockFiltersByDefault`). [birthday] is only
  /// consulted when the resolved backend is
  /// [BitcoinSyncBackend.compactBlockFilters] — `null` means "the earliest
  /// possible date" (this network's genesis block), which can never fail to
  /// resolve (see `WalletBirthdayCheckpointRepositoryImpl`).
  @useResult
  Future<Result<Wallet, ImportWatchOnlyFailure>> execute({
    required WatchOnlyDescriptorEntity watchOnlyDescriptor,
    BitcoinSyncBackend? requestedSyncBackend,
    DateTime? birthday,
  }) async {
    final settings = await _settings.fetch();
    final bitcoinSyncBackend = await _resolveBitcoinSyncBackend(
      settings: settings,
      requestedSyncBackend: requestedSyncBackend,
    );

    WalletBirthdayCheckpoint? birthdayCheckpoint;
    if (bitcoinSyncBackend == BitcoinSyncBackend.compactBlockFilters) {
      final isTestnet = watchOnlyDescriptor.network.isTestnet;
      final requestedBirthday =
          birthday ??
          BitcoinGenesisBlock.forNetwork(isTestnet: isTestnet).timestamp;
      // A watch-only import's birthday is only ever an approximation
      // (a user-entered date, or — for genesis — the protocol's own
      // earliest point), never the exact generation instant a freshly
      // *created* wallet would have: always `recovery` mode.
      final checkpointResult = await _resolveWalletBirthdayCheckpoint.execute(
        requestedBirthday: requestedBirthday,
        isTestnet: isTestnet,
        lookupMode: WalletBirthdayLookupMode.recovery,
      );
      switch (checkpointResult) {
        case Ok(:final value):
          birthdayCheckpoint = value;
        case Err(:final failure):
          // Resolution failed before any wallet was imported — the cubit
          // surfaces this with a retry (same birthday) or a genesis
          // fallback (never requires a network lookup).
          return Err(BirthdayCheckpointFailure(failure.logMessage));
      }
    }

    try {
      final wallet = await _wallet.importDescriptor(
        watchOnlyDescriptor: watchOnlyDescriptor,
        bitcoinSyncBackend: bitcoinSyncBackend,
        birthdayCheckpoint: birthdayCheckpoint,
      );
      return Ok(wallet);
    } catch (e, st) {
      // Keep the raw descriptor/BDK rejection reason in the logs; the UI shows
      // a generic localized message. A rejected descriptor is an expected
      // user-facing condition (malformed input), so this is a warning.
      log.warning(
        'Failed to import watch-only descriptor',
        error: e,
        trace: st,
      );
      return const Err(ImportFailedFailure());
    }
  }

  /// Same availability gate (`CheckCompactBlockFiltersAvailableUsecase`) as
  /// `CreateDefaultWalletsUsecase`'s wizard-driven default wallet and
  /// `ImportWalletUsecase`'s mnemonic import (see either for the rationale,
  /// and `WalletSyncRoutingRepository._checkCbfGate` for the sync-time
  /// backstop this is layered in front of). A user's explicit choice on the
  /// import screen ([requestedSyncBackend]) wins over the global
  /// `useCompactBlockFiltersByDefault` preference, but even an explicit
  /// request can never be persisted unless the build/developer-mode gate is
  /// actually open. [WalletRepository.importDescriptor] only persists the
  /// result for a Bitcoin wallet — a Liquid descriptor always stays on
  /// `BitcoinSyncBackend.electrum` regardless of what this returns.
  Future<BitcoinSyncBackend> _resolveBitcoinSyncBackend({
    required SettingsEntity settings,
    required BitcoinSyncBackend? requestedSyncBackend,
  }) async {
    final wantsCompactBlockFilters = requestedSyncBackend != null
        ? requestedSyncBackend == BitcoinSyncBackend.compactBlockFilters
        : settings.useCompactBlockFiltersByDefault;
    final wantsCbf =
        wantsCompactBlockFilters &&
        await _checkCompactBlockFiltersAvailable.execute();
    return wantsCbf
        ? BitcoinSyncBackend.compactBlockFilters
        : BitcoinSyncBackend.electrum;
  }
}
