import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/features/wizard/ui/wizard_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// `WizardPage.available` reads only the `ENABLE_CBF` compile-time flag,
/// fixed for the entire `flutter test` binary. The ordinary test binary has
/// it unset, so the CBF-only privacy page is omitted.
void main() {
  test('this test binary is a non-production, non-ENABLE_CBF build (documents '
      'the fixed compile-time state every assertion below depends on)', () {
    expect(CheckCompactBlockFiltersAvailableUsecase.enableCbfFlag, isFalse);
    expect(CheckCompactBlockFiltersAvailableUsecase.isProductionBuild, isFalse);
  });

  test('privacy is hidden when ENABLE_CBF is unset', () {
    expect(WizardPage.available, isNot(contains(WizardPage.privacy)));
    expect(WizardPage.total, WizardPage.values.length - 1);
  });

  test('number is 1-indexed position within available', () {
    expect(WizardPage.welcome.number, 1);
    expect(WizardPage.customize.number, 2);
    expect(WizardPage.mission.number, 3);
    expect(WizardPage.privacy.number, 0);
    expect(WizardPage.journey.number, 4);
  });

  test('pageViewIndex is number - 1 — what PageView/PageController use', () {
    for (final page in WizardPage.values) {
      expect(page.pageViewIndex, page.number - 1);
    }
  });

  test('isFirst/isLast are relative to available, not enum declaration '
      'order', () {
    expect(WizardPage.welcome.isFirst, isTrue);
    expect(WizardPage.journey.isLast, isTrue);
    for (final page in WizardPage.values) {
      if (page != WizardPage.welcome) expect(page.isFirst, isFalse);
      if (page != WizardPage.journey) expect(page.isLast, isFalse);
    }
  });
}
