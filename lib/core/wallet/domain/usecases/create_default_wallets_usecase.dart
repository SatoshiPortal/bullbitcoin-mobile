import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final WalletRepository _wallet;
  final CheckCompactBlockFiltersAvailableUsecase
  _checkCompactBlockFiltersAvailable;
  final ResolveWalletBirthdayCheckpointUsecase _resolveWalletBirthdayCheckpoint;

  CreateDefaultWalletsUsecase({
    required this._seedRepository,
    required this._settingsRepository,
    required this._mnemonicGenerator,
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

  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    String? passphrase,
    // Only ever consulted for a recovery/import (`mnemonicWords != null`)
    // that opts into compact block filters. This use-case never shows a
    // birthday picker itself (it must stay Flutter-free); the caller —
    // `OnboardingBloc`/`RecoverBullBloc`, after its own birthday-picker UI —
    // resolves this with `WalletBirthdayLookupMode.recovery` (see
    // `ResolveWalletBirthdayCheckpointUsecase`'s doc for why recovery needs
    // the safety margin a freshly generated wallet does not) and passes the
    // already-resolved checkpoint in here. See the CBF branch below for
    // what happens if it is missing.
    WalletBirthdayCheckpoint? bitcoinBirthdayCheckpoint,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      const scriptType = ScriptType.bip84;
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;
      final liquidNetwork = environment.isMainnet
          ? Network.liquidMainnet
          : Network.liquidTestnet;

      final existing = await _wallet.getWallets(
        onlyDefaults: true,
        environment: environment,
      );
      final hasBitcoin = existing.any((w) => w.network.isBitcoin);
      final hasLiquid = existing.any((w) => w.network.isLiquid);
      if (hasBitcoin && hasLiquid) return existing;

      final isGenerated = mnemonicWords == null;
      final mnemonic = mnemonicWords ?? _mnemonicGenerator.generate();
      DateTime? birthday = isGenerated ? DateTime.now().toUtc() : null;
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonic,
        passphrase: passphrase,
      );

      // The wizard's privacy step lets a user opt the default Bitcoin wallet
      // into compact block filter sync instead of Electrum, whether the
      // wallet is freshly generated or recovered from a mnemonic. It never
      // changes an already-existing default wallet — this value is only used
      // by the `!hasBitcoin` branch below.
      //
      // CBF is still gated end-to-end by
      // `CheckCompactBlockFiltersAvailableUsecase` (also consulted by
      // `WalletSyncRoutingRepository._checkCbfGate` at sync time): even a
      // stale `true` preference (e.g. a debug build's choice surviving
      // into a release install) can never enable it here unless the build
      // has `ENABLE_CBF` set or is a non-release build with developer mode
      // on, so the public wizard stays safe to ship while still being
      // useful for a demo/beta APK. Tor is checked only at sync time so a
      // transient runtime setting cannot silently discard the user's backend
      // choice; the router refuses Tor before opening a CBF peer connection.
      final bitcoinSyncBackend =
          settings.useCompactBlockFiltersByDefault &&
              await _checkCompactBlockFiltersAvailable.execute()
          ? BitcoinSyncBackend.compactBlockFilters
          : BitcoinSyncBackend.electrum;

      // A freshly *generated* wallet (never a recovered/imported one — see
      // `isGenerated` above) that opted into compact block filters has no
      // prior history to scan: request the checkpoint for the current
      // chain tip (`requestedBirthday: birthday`, which is
      // `DateTime.now().toUtc()` here) instead of the wider recovery scan
      // `CbfScanTypeResolver` would otherwise use. Resolved *before* any
      // wallet is created — an explicit resolver failure must never leave
      // a partial (Bitcoin-only or Liquid-only) default wallet pair
      // behind, and is surfaced through this use-case's existing
      // exception-based failure path, which the onboarding flow already
      // turns into a retryable error (see `OnboardingBloc._handleError`).
      //
      // A recovered/imported wallet (`!isGenerated`) that opted into CBF
      // takes the opposite path: this use-case never resolves that
      // checkpoint itself (it would need `WalletBirthdayLookupMode.recovery`
      // and, per that mode's doc, a user-approximated birthday this
      // Flutter-free use-case has no way to ask for) — it only accepts one
      // already resolved by the caller's own birthday-picker UI, via
      // [bitcoinBirthdayCheckpoint]. A CBF recovery with none supplied fails
      // closed here rather than persisting a wallet `CbfScanTypeResolver`
      // could never safely scan (see `CbfMissingBirthdayCheckpointException`).
      WalletBirthdayCheckpoint? resolvedBitcoinBirthdayCheckpoint;
      if (!hasBitcoin &&
          bitcoinSyncBackend == BitcoinSyncBackend.compactBlockFilters) {
        if (isGenerated) {
          final checkpointResult = await _resolveWalletBirthdayCheckpoint
              .execute(
                requestedBirthday: birthday!,
                isTestnet: environment.isTestnet,
                // Always `newWallet`, never `recovery` — this branch only
                // ever runs for a freshly *generated* wallet (`isGenerated`
                // above), which has no prior history and so needs no safety
                // margin (see that lookup mode's own doc).
                lookupMode: WalletBirthdayLookupMode.newWallet,
              );
          switch (checkpointResult) {
            case Ok(:final value):
              resolvedBitcoinBirthdayCheckpoint = value;
            case Err(:final failure):
              throw CreateDefaultWalletsException(
                failure.logMessage ??
                    'wallet_birthday_checkpoint_resolution_failed',
              );
          }
        } else if (bitcoinBirthdayCheckpoint != null) {
          resolvedBitcoinBirthdayCheckpoint = bitcoinBirthdayCheckpoint;
          // The plain `birthday` field and the atomic `birthdayBlock*`
          // fields are only ever surfaced together as a single
          // `WalletMetadataModel.birthdayCheckpoint` (see that getter's
          // all-or-none doc) — without this, `birthdayCheckpoint` would
          // resolve to `null` even though a checkpoint was just persisted.
          birthday = bitcoinBirthdayCheckpoint.requestedBirthday;
        } else {
          throw CreateDefaultWalletsException(
            'wallet_birthday_checkpoint_required_for_recovery',
          );
        }
      }

      final created = <Wallet>[];
      try {
        if (!hasBitcoin) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: bitcoinNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
              bitcoinSyncBackend: bitcoinSyncBackend,
              birthdayCheckpoint: resolvedBitcoinBirthdayCheckpoint,
            ),
          );
        }
        if (!hasLiquid) {
          created.add(
            await _wallet.createWallet(
              seed: seed,
              network: liquidNetwork,
              scriptType: scriptType,
              isDefault: true,
              birthday: birthday,
            ),
          );
        }
      } catch (_) {
        for (final wallet in created) {
          try {
            await _wallet.deleteWallet(walletId: wallet.id);
          } catch (e, stackTrace) {
            log.severe(
              message: 'CreateDefaultWalletsUsecase: rollback failed',
              error: e,
              trace: stackTrace,
            );
          }
        }
        rethrow;
      }

      return [...existing, ...created];
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException extends BullException {
  CreateDefaultWalletsException(super.message);
}
