import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
export 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart'
    show WalletPreferences;

final class WizardFacade {
  final Future<Result<void, WizardFailure>> Function({
    List<WalletPreferences> defaultCreatedWalletPreferences,
  })
  _applyPendingChoices;
  final Future<bool> Function() _hasPendingChoices;
  final Future<bool?> Function() _pendingMetadataBackupEnabled;

  const WizardFacade({
    required Future<Result<void, WizardFailure>> Function({
      List<WalletPreferences> defaultCreatedWalletPreferences,
    })
    applyPendingChoices,
    required Future<bool> Function() hasPendingChoices,
    required Future<bool?> Function() pendingMetadataBackupEnabled,
  }) : this._(
         applyPendingChoices,
         hasPendingChoices,
         pendingMetadataBackupEnabled,
       );

  const WizardFacade._(
    this._applyPendingChoices,
    this._hasPendingChoices,
    this._pendingMetadataBackupEnabled,
  );

  /// Applies whatever the first-run wizard left for after wallet creation:
  /// settings, and the Data Backup opt-in with its server recovery.
  @useResult
  Future<Result<void, WizardFailure>> applyPendingChoices({
    List<WalletPreferences> defaultCreatedWalletPreferences = const [],
  }) => _applyPendingChoices(
    defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
  );

  /// Whether a wizard choice is still waiting to be applied.
  Future<bool> hasPendingChoices() => _hasPendingChoices();

  /// The Data Backup answer the wizard recorded and has not applied yet, or
  /// null when no answer is staged.
  ///
  /// It is the only record of whether this person asked for their wallet data
  /// to be backed up at all, so it is also what says whether a recovery may
  /// go looking for it.
  Future<bool?> pendingMetadataBackupEnabled() =>
      _pendingMetadataBackupEnabled();
}
