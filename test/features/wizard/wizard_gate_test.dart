import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/wizard_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('shouldShow / markComplete', () {
    test('shouldShow returns true on a fresh prefs store', () async {
      expect(await WizardGate.shouldShow(), isTrue);
    });

    test('shouldShow returns false after markComplete', () async {
      await WizardGate.markComplete();
      expect(await WizardGate.shouldShow(), isFalse);
    });

    test(
      'shouldShow returns true again if stored version is below current',
      () async {
        SharedPreferences.setMockInitialValues({
          'wizard_completed_version': kCurrentWizardVersion - 1,
        });
        expect(await WizardGate.shouldShow(), isTrue);
      },
    );
  });

  group('isSetupComplete / markSetupComplete', () {
    test('returns false on a fresh prefs store', () async {
      expect(await WizardGate.isSetupComplete(), isFalse);
    });

    test('returns true after markSetupComplete', () async {
      await WizardGate.markSetupComplete();
      expect(await WizardGate.isSetupComplete(), isTrue);
    });

    test('markSetupComplete is idempotent', () async {
      await WizardGate.markSetupComplete();
      // Second call should be a no-op — assert no throw + still true.
      await WizardGate.markSetupComplete();
      await WizardGate.markSetupComplete();
      expect(await WizardGate.isSetupComplete(), isTrue);
    });

    test('migrates legacy wallet_setup_complete=true on first read', () async {
      SharedPreferences.setMockInitialValues({'wallet_setup_complete': true});
      expect(await WizardGate.isSetupComplete(), isTrue);
      // Legacy key wiped, new key written.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('wallet_setup_complete'), isFalse);
      expect(prefs.getBool('wizard_setup_complete'), isTrue);
    });

    test(
      'does not overwrite existing wizard_setup_complete with legacy',
      () async {
        SharedPreferences.setMockInitialValues({
          'wallet_setup_complete': false,
          'wizard_setup_complete': true,
        });
        expect(await WizardGate.isSetupComplete(), isTrue);
        final prefs = await SharedPreferences.getInstance();
        // Legacy is left in place because the new key already exists —
        // we don't trample a real value with stale legacy data.
        expect(prefs.getBool('wizard_setup_complete'), isTrue);
      },
    );
  });

  group('savePending — only touched fields persist', () {
    test('untouched choices write nothing (just version + clear)', () async {
      await WizardGate.savePending(const WizardChoices());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
      expect(prefs.getString('wizard_pending_currency'), isNull);
      expect(prefs.getBool('wizard_pending_error_reporting'), isNull);
      // Version tag is the only persistent marker.
      expect(prefs.getInt('wizard_pending_version'), kCurrentWizardVersion);
    });

    test('writes only fields the user touched', () async {
      const c = WizardChoices(
        language: Language.franceFrench,
        themeMode: AppThemeMode.dark,
        touched: {WizardField.language},
      );
      await WizardGate.savePending(c);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('wizard_pending_language'),
        Language.franceFrench.name,
      );
      // Theme isn't in `touched` even though `themeMode` is set — should be skipped.
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
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
      await WizardGate.savePending(c);
      final prefs = await SharedPreferences.getInstance();
      // Stale language + currency wiped.
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_currency'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), 'dark');
    });
  });

  group('readPending — version invalidation', () {
    test('returns null when nothing has been staged', () async {
      expect(await WizardGate.readPending(), isNull);
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
      await WizardGate.savePending(c);
      final read = await WizardGate.readPending();
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
      // Version mismatch → readPending wipes and returns null.
      expect(await WizardGate.readPending(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wizard_pending_language'), isNull);
      expect(prefs.getString('wizard_pending_theme_mode'), isNull);
      expect(prefs.getInt('wizard_pending_version'), isNull);
    });
  });
}
