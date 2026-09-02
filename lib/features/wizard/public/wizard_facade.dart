import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

export 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';

final class WizardFacade {
  final Future<Result<void, WizardFailure>> Function() _applyPendingChoices;

  const WizardFacade(this._applyPendingChoices);

  @useResult
  Future<Result<void, WizardFailure>> applyPendingChoices() =>
      _applyPendingChoices();
}
