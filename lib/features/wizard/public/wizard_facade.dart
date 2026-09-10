import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';

final class WizardFacade {
  final Future<Result<void, WizardFailure>> Function({
    Set<String> defaultCreatedWalletIds,
  })
  _applyPendingChoices;
  final Future<bool> Function() _hasPendingChoices;

  const WizardFacade({
    required Future<Result<void, WizardFailure>> Function({
      Set<String> defaultCreatedWalletIds,
    })
    applyPendingChoices,
    required Future<bool> Function() hasPendingChoices,
  }) : this._(applyPendingChoices, hasPendingChoices);

  const WizardFacade._(this._applyPendingChoices, this._hasPendingChoices);

  /// Applies whatever the first-run wizard left for after wallet creation:
  /// settings, and the Data Backup opt-in with its server recovery.
  @useResult
  Future<Result<void, WizardFailure>> applyPendingChoices({
    Set<String> defaultCreatedWalletIds = const {},
  }) => _applyPendingChoices(defaultCreatedWalletIds: defaultCreatedWalletIds);

  /// Whether a wizard choice is still waiting to be applied.
  Future<bool> hasPendingChoices() => _hasPendingChoices();
}
