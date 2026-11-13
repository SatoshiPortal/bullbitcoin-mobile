import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WizardRepositoryImpl _build() =>
    WizardRepositoryImpl(WizardLocalDatasourceImpl());

class _FailingWriteDatasource extends WizardLocalDatasourceImpl {
  @override
  Future<void> writePendingPayload(String payload) async {
    throw const FormatException('simulated interrupted write');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('exchange choice', () {
    test('confirmed default is staged even without toggling', () async {
      final repo = _build();
      await repo.savePending(
        const WizardChoices().copyWith(confirmExchange: true),
      );
      final choices = await repo.readPending();
      expect(choices?.exchangeAccess, isTrue);
      expect(choices?.touched, contains(WizardField.exchangeAccess));
    });

    test('confirmed disabled choice survives a round trip', () async {
      final repo = _build();
      await repo.savePending(
        const WizardChoices().copyWith(
          exchangeAccess: false,
          confirmExchange: true,
        ),
      );
      final choices = await repo.readPending();
      expect(choices?.exchangeAccess, isFalse);
      expect(choices?.touched, contains(WizardField.exchangeAccess));
    });

    test(
      'old version 1 pending remains readable without exchange choice',
      () async {
        SharedPreferences.setMockInitialValues({
          'wizard_pending_version': 1,
          'wizard_pending_error_reporting': false,
        });
        final choices = await _build().readPending();
        expect(choices?.reportingConsent, isFalse);
        expect(choices?.touched, isNot(contains(WizardField.exchangeAccess)));
      },
    );
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
      const choices = WizardChoices(
        language: Language.franceFrench,
        themeMode: AppThemeMode.dark,
        touched: {WizardField.language},
      );
      final repo = _build();
      await repo.savePending(choices);
      final read = await repo.readPending();
      expect(read?.language, Language.franceFrench);
      expect(read?.touched, {WizardField.language});
    });

    test(
      'new payload supersedes legacy fields without resurrecting them',
      () async {
        SharedPreferences.setMockInitialValues({
          'wizard_pending_version': 1,
          'wizard_pending_language': 'franceFrench',
          'wizard_pending_currency': 'EUR',
        });
        final repo = _build();
        await repo.savePending(
          const WizardChoices(
            themeMode: AppThemeMode.dark,
            touched: {WizardField.themeMode},
          ),
        );
        expect((await repo.readPending())?.touched, {WizardField.themeMode});
        await repo.clearPending();
        expect(await repo.readPending(), isNull);
      },
    );

    test('failed replacement preserves the previous payload', () async {
      final repo = _build();
      await repo.savePending(
        const WizardChoices().copyWith(confirmExchange: true),
      );
      final failing = WizardRepositoryImpl(_FailingWriteDatasource());
      await expectLater(
        failing.savePending(
          const WizardChoices().copyWith(
            exchangeAccess: false,
            confirmExchange: true,
          ),
        ),
        throwsFormatException,
      );
      expect((await repo.readPending())?.exchangeAccess, isTrue);
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
      expect(await _build().readPending(), isNull);
    });
  });
}
