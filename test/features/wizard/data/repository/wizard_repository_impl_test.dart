import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WizardRepositoryImpl _build() =>
    WizardRepositoryImpl(WizardLocalDatasourceImpl());

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('isComplete / markComplete', () {
    test('isComplete is false on a fresh prefs store', () async {
      expect(await _build().isComplete(), isFalse);
    });

    test('isComplete is true after markComplete', () async {
      final repo = _build();
      await repo.markComplete();
      expect(await repo.isComplete(), isTrue);
    });

    test('isComplete is false when stored version below current', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_completed_version': kCurrentWizardVersion - 1,
      });
      expect(await _build().isComplete(), isFalse);
    });
  });

  group('savePending — only touched fields persist', () {
    test('untouched choices write nothing (no version tag)', () async {
      await _build().savePending(const WizardChoices());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
      expect(prefs.getString('wizard_pending_currency'), isNull);
      expect(prefs.getBool('wizard_pending_error_reporting'), isNull);
      expect(prefs.getInt('wizard_pending_version'), isNull);
    });

    test('writes only fields the user touched (with version tag)', () async {
      const c = WizardChoices(
        language: Language.franceFrench,
        themeMode: AppThemeMode.dark,
        touched: {WizardField.language},
      );
      await _build().savePending(c);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('wizard_pending_language'),
        Language.franceFrench.name,
      );
      // Theme isn't in `touched` — should be skipped.
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
      expect(prefs.getInt('wizard_pending_version'), kCurrentWizardVersion);
    });

    test('clears stale prefs from a previous run before writing', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_pending_language': 'franceFrench',
        'wizard_pending_currency': 'EUR',
      });
      const c = WizardChoices(
        themeMode: AppThemeMode.dark,
        touched: {WizardField.themeMode},
      );
      await _build().savePending(c);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_currency'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), 'dark');
    });
  });

  group('readPending — version invalidation', () {
    test('returns null when nothing has been staged', () async {
      expect(await _build().readPending(), isNull);
    });

    test('round-trips touched fields', () async {
      const c = WizardChoices(
        language: Language.franceFrench,
        defaultCurrency: 'CAD',
        reportingConsent: true,
        touched: {
          WizardField.language,
          WizardField.defaultCurrency,
          WizardField.reportingConsent,
        },
      );
      final repo = _build();
      await repo.savePending(c);
      final read = await repo.readPending();
      expect(read, isNotNull);
      expect(read!.language, Language.franceFrench);
      expect(read.defaultCurrency, 'CAD');
      expect(read.reportingConsent, true);
      expect(read.touched, {
        WizardField.language,
        WizardField.defaultCurrency,
        WizardField.reportingConsent,
      });
    });

    test('invalidates pending blob from a stale wizard version', () async {
      SharedPreferences.setMockInitialValues({
        'wizard_pending_version': kCurrentWizardVersion - 1,
        'wizard_pending_language': 'franceFrench',
        'wizard_pending_theme_mode': 'dark',
      });
      expect(await _build().readPending(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
      expect(prefs.getInt('wizard_pending_version'), isNull);
    });
  });
}
