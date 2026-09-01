import 'package:bb_mobile/features/onboarding/domain/apply_pending_wizard_choices_after_wallet_creation_usecase.dart';
import 'package:bb_mobile/features/wizard/public/wizard_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('applies pending choices through the wizard boundary', () async {
    var calls = 0;
    final usecase = ApplyPendingWizardChoicesAfterWalletCreationUsecase(
      WizardFacade(() async {
        calls++;
        return const Ok(null);
      }),
    );

    await usecase.execute();

    expect(calls, 1);
  });

  test('does not fail wallet creation when pending choices cannot apply', () {
    final usecase = ApplyPendingWizardChoicesAfterWalletCreationUsecase(
      WizardFacade(() async => const Err(WizardApplyFailure())),
    );

    expect(usecase.execute(), completes);
  });
}
