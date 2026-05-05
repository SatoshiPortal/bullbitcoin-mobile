import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WizardChoices defaults', () {
    test('empty constructor leaves all fields untouched', () {
      const c = WizardChoices();
      expect(c.language, Language.unitedStatesEnglish);
      expect(c.themeMode, AppThemeMode.system);
      expect(c.defaultCurrency, 'USD');
      expect(c.reportingConsent, isNull);
      expect(c.touched, isEmpty);
    });
  });

  group('WizardChoices.copyWith — touched tracking', () {
    test('language change marks language touched', () {
      const c = WizardChoices();
      final next = c.copyWith(language: Language.franceFrench);
      expect(next.language, Language.franceFrench);
      expect(next.touched, contains(WizardField.language));
      expect(next.touched, hasLength(1));
    });

    test('themeMode change marks themeMode touched', () {
      const c = WizardChoices();
      final next = c.copyWith(themeMode: AppThemeMode.dark);
      expect(next.themeMode, AppThemeMode.dark);
      expect(next.touched, contains(WizardField.themeMode));
    });

    test('defaultCurrency change marks defaultCurrency touched', () {
      const c = WizardChoices();
      final next = c.copyWith(defaultCurrency: 'CAD');
      expect(next.defaultCurrency, 'CAD');
      expect(next.touched, contains(WizardField.defaultCurrency));
    });

    test('reportingConsent ConsentValue marks reportingConsent touched', () {
      const c = WizardChoices();
      final yes = c.copyWith(reportingConsent: const ConsentValue(true));
      expect(yes.reportingConsent, true);
      expect(yes.touched, contains(WizardField.reportingConsent));

      final no = c.copyWith(reportingConsent: const ConsentValue(false));
      expect(no.reportingConsent, false);
      expect(no.touched, contains(WizardField.reportingConsent));
    });

    test('reportingConsent ConsentValue(null) marks touched too', () {
      const c = WizardChoices(reportingConsent: true);
      final next = c.copyWith(reportingConsent: const ConsentValue(null));
      expect(next.reportingConsent, isNull);
      expect(next.touched, contains(WizardField.reportingConsent));
    });

    test('omitting reportingConsent leaves touched + value unchanged', () {
      const c = WizardChoices(
        reportingConsent: true,
        touched: {WizardField.reportingConsent},
      );
      final next = c.copyWith(language: Language.franceFrench);
      expect(next.reportingConsent, true);
      expect(next.touched, contains(WizardField.reportingConsent));
      expect(next.touched, contains(WizardField.language));
    });

    test('touched accumulates across multiple copyWith calls', () {
      const c = WizardChoices();
      final after = c
          .copyWith(language: Language.franceFrench)
          .copyWith(themeMode: AppThemeMode.dark)
          .copyWith(defaultCurrency: 'EUR');
      expect(after.touched, {
        WizardField.language,
        WizardField.themeMode,
        WizardField.defaultCurrency,
      });
    });
  });

  group('WizardChoices.copyWithSilent — no touch', () {
    test('language update does NOT join touched', () {
      const c = WizardChoices();
      final next = c.copyWithSilent(language: Language.franceFrench);
      expect(next.language, Language.franceFrench);
      expect(next.touched, isEmpty);
    });

    test('themeMode update does NOT join touched', () {
      const c = WizardChoices();
      final next = c.copyWithSilent(themeMode: AppThemeMode.dark);
      expect(next.themeMode, AppThemeMode.dark);
      expect(next.touched, isEmpty);
    });

    test('preserves an already-touched set unchanged', () {
      const c = WizardChoices(
        defaultCurrency: 'CAD',
        touched: {WizardField.defaultCurrency},
      );
      final next = c.copyWithSilent(themeMode: AppThemeMode.dark);
      expect(next.touched, {WizardField.defaultCurrency});
      expect(next.themeMode, AppThemeMode.dark);
      expect(next.defaultCurrency, 'CAD');
    });
  });
}
