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

  const WizardFacade({
    required Future<Result<void, WizardFailure>> Function({
      List<WalletPreferences> defaultCreatedWalletPreferences,
    })
    applyPendingChoices,
    required Future<bool> Function() hasPendingChoices,
  }) : this._(applyPendingChoices, hasPendingChoices);

  const WizardFacade._(this._applyPendingChoices, this._hasPendingChoices);

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
}
