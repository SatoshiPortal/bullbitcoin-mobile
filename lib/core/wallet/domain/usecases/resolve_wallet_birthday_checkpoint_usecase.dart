import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_birthday_checkpoint_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:meta/meta.dart';

/// Resolves the concrete block checkpoint for a requested wallet birthday.
///
/// Thin orchestration only — the actual lookup lives behind
/// [WalletBirthdayCheckpointRepository]. The one piece of business logic
/// this usecase owns is [lookupMode]'s safety margin (see
/// [WalletBirthdayLookupMode]'s doc for the rationale): [recoveryMargin] is
/// subtracted from [requestedBirthday] before the repository ever sees it
/// when [lookupMode] is [WalletBirthdayLookupMode.recovery]; a
/// [WalletBirthdayLookupMode.newWallet] request is passed through exactly
/// as given.
///
/// Used today by `CreateDefaultWalletsUsecase` for a freshly **generated**
/// (never a recovered or imported) wallet that opted into compact block
/// filters, always with `lookupMode: WalletBirthdayLookupMode.newWallet`
/// and `requestedBirthday: DateTime.now().toUtc()` — the current chain
/// tip. A brand-new wallet has no prior history to protect against
/// reorg/clock skew for, unlike a recovered/imported wallet's birthday.
class ResolveWalletBirthdayCheckpointUsecase {
  /// Subtracted from a [WalletBirthdayLookupMode.recovery] request before
  /// resolution, so the resolved checkpoint never lands after the wallet's
  /// real first-use block even if the requested birthday itself is off by
  /// a clock skew or was only ever an approximate, user-entered date.
  static const recoveryMargin = Duration(hours: 48);

  final WalletBirthdayCheckpointRepository _repository;

  ResolveWalletBirthdayCheckpointUsecase({
    required WalletBirthdayCheckpointRepository
    walletBirthdayCheckpointRepository,
  }) : _repository = walletBirthdayCheckpointRepository;

  @useResult
  Future<Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>>
  execute({
    required DateTime requestedBirthday,
    required bool isTestnet,
    required WalletBirthdayLookupMode lookupMode,
  }) {
    final requested = requestedBirthday.toUtc();
    final lookupInstant = switch (lookupMode) {
      WalletBirthdayLookupMode.newWallet => requested,
      WalletBirthdayLookupMode.recovery => requested.subtract(recoveryMargin),
    };

    return _repository.resolve(
      requestedBirthday: lookupInstant,
      isTestnet: isTestnet,
    );
  }
}
