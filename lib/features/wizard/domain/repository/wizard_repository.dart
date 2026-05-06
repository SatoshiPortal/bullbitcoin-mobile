import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';

abstract class WizardRepository {
  /// `true` once the user has completed the wizard for the current
  /// `kCurrentWizardVersion`. Bumping the version re-triggers the
  /// wizard for everyone — fresh installs and existing users alike,
  /// since the wizard always runs pre-init.
  Future<bool> isComplete();
  Future<void> markComplete();

  Future<void> savePending(WizardChoices choices);
  Future<WizardChoices?> readPending();
  Future<void> clearPending();
}
