import 'package:meta/meta.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wizard/domain/wizard_failure.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';

abstract interface class WizardRepository {
  /// `true` once the user has completed the wizard for the current
  /// `kCurrentWizardVersion`. Bumping the version re-triggers the
  /// wizard for everyone — fresh installs and existing users alike,
  /// since the wizard always runs pre-init.
  Future<bool> isComplete();
  @useResult
  Future<Result<void, WizardFailure>> markComplete();

  @useResult
  Future<Result<void, WizardFailure>> savePending(WizardChoices choices);
  Future<WizardChoices?> readPending();
  Future<void> clearPending({bool keepDataBackupChoice = false});
}
