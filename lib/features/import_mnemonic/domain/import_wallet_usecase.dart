import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:meta/meta.dart';

class ImportWalletUsecase {
  final CheckDuplicateMnemonicUsecase _checkDuplicateMnemonicUsecase;
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailable;
  final ResolveWalletBirthdayCheckpointUsecase _resolveWalletBirthdayCheckpoint;

  ImportWalletUsecase({
    required this._checkDuplicateMnemonicUsecase,
    required this._seedRepository,
    required this._settingsRepository,
    required WalletRepository walletRepository,
    required CheckCompactBlockFiltersAvailableUsecase
    checkCompactBlockFiltersAvailableUsecase,
    required ResolveWalletBirthdayCheckpointUsecase
    resolveWalletBirthdayCheckpointUsecase,
  }) : _wallet = walletRepository,
       _checkCompactBlockFiltersAvailable =
           checkCompactBlockFiltersAvailableUsecase,
       _resolveWalletBirthdayCheckpoint =
           resolveWalletBirthdayCheckpointUsecase;

  @useResult
  Future<Result<Wallet, ImportMnemonicFailure>> execute({
    required List<String> mnemonicWords,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
    // User's explicit backend choice from the import screen. `null`
    // preserves the previous automatic behaviour (driven solely by
    // `useCompactBlockFiltersByDefault`) for any other caller/test that
    // doesn't pass one.
    BitcoinSyncBackend? requestedSyncBackend,
    // Only consulted when the resolved backend is
    // `BitcoinSyncBackend.compactBlockFilters`. `null` means "the earliest
    // possible date" (this network's genesis block) — the picker's own
    // default — which `ResolveWalletBirthdayCheckpointUsecase` always
    // resolves locally (see `WalletBirthdayCheckpointRepositoryImpl`), so
    // this path can never fail from a network lookup.
    DateTime? birthday,
  }) async {
    switch (await _checkDuplicateMnemonicUsecase.execute(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        break;
    }

    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      // A user's explicit choice on the import screen wins over the global
      // `useCompactBlockFiltersByDefault` preference (same fallback this
      // usecase always had, kept for any caller that never passes one).
      // Same availability gate as `CreateDefaultWalletsUsecase`'s
      // wizard-driven default wallet (see that usecase for the rationale):
      // even an explicit request for compact block filters can never be
      // persisted unless the build/developer-mode gate is actually open.
      // This never changes the pre-import discovery scan across all script
      // types (still Electrum, via `CheckWalletStatusUsecase` from the
      // cubit) — only the imported wallet's subsequent sync may use CBF
      // recovery.
      final wantsCompactBlockFilters = requestedSyncBackend != null
          ? requestedSyncBackend == BitcoinSyncBackend.compactBlockFilters
          : settings.useCompactBlockFiltersByDefault;
      final bitcoinSyncBackend =
          wantsCompactBlockFilters &&
              await _checkCompactBlockFiltersAvailable.execute()
          ? BitcoinSyncBackend.compactBlockFilters
          : BitcoinSyncBackend.electrum;

      WalletBirthdayCheckpoint? birthdayCheckpoint;
      if (bitcoinSyncBackend == BitcoinSyncBackend.compactBlockFilters) {
        final requestedBirthday =
            birthday ??
            BitcoinGenesisBlock.forNetwork(
              isTestnet: environment.isTestnet,
            ).timestamp;
        // A recovered/imported wallet's birthday is only ever an
        // approximation (a user-entered date, or — for genesis — the
        // protocol's own earliest point), never the exact generation
        // instant a freshly *created* wallet would have: always
        // `recovery` mode, never `newWallet` (see that lookup mode's own
        // doc, and `CreateDefaultWalletsUsecase` for the contrasting
        // `newWallet` case).
        final checkpointResult = await _resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: requestedBirthday,
          isTestnet: environment.isTestnet,
          lookupMode: WalletBirthdayLookupMode.recovery,
        );
        switch (checkpointResult) {
          case Ok(:final value):
            birthdayCheckpoint = value;
          case Err(:final failure):
            // Resolution failed before any wallet was created — the
            // cubit surfaces this with a retry (same birthday) or a
            // genesis fallback (never requires a network lookup, see
            // `birthday`'s own doc above).
            return Err(
              ImportMnemonicBirthdayCheckpointFailure(failure.logMessage),
            );
        }
      }

      final wallet = await _wallet.createWallet(
        seed: seed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: false,
        sync: false,
        label: label,
        bitcoinSyncBackend: bitcoinSyncBackend,
        // `birthday` must accompany `birthdayCheckpoint` here — see
        // `WalletMetadataModelBirthdayCheckpoint.birthdayCheckpoint`'s
        // all-or-none invariant (`WalletRepository.importDescriptor` has
        // the same requirement spelled out for the watch-only import
        // flows).
        birthday: birthdayCheckpoint?.requestedBirthday,
        birthdayCheckpoint: birthdayCheckpoint,
      );

      log.fine('Wallet imported');

      return Ok(wallet);
    } catch (e, st) {
      log.severe(message: 'Import wallet failed', error: e, trace: st);
      return Err(ImportMnemonicUnexpectedFailure(e.toString()));
    }
  }
}
