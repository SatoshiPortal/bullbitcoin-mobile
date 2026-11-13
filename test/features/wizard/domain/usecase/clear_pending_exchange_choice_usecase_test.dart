import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/wizard/data/datasource/wizard_local_datasource.dart';
import 'package:bb_mobile/features/wizard/data/repository/wizard_repository_impl.dart';
import 'package:bb_mobile/features/wizard/domain/entity/wizard_choices.dart';
import 'package:bb_mobile/features/wizard/domain/usecase/clear_pending_exchange_choice_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('clears exchange while preserving unrelated pending choices', () async {
    final repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());
    await repository.savePending(
      const WizardChoices(
        language: Language.franceFrench,
        reportingConsent: false,
        exchangeAccess: true,
        touched: {
          WizardField.language,
          WizardField.reportingConsent,
          WizardField.exchangeAccess,
        },
      ),
    );
    await ClearPendingExchangeChoiceUsecase(repository).execute();
    final pending = await repository.readPending();
    expect(pending?.language, Language.franceFrench);
    expect(pending?.reportingConsent, isFalse);
    expect(pending?.touched, {
      WizardField.language,
      WizardField.reportingConsent,
    });
  });

  test(
    'clears the pending payload when exchange was the only choice',
    () async {
      final repository = WizardRepositoryImpl(WizardLocalDatasourceImpl());
      await repository.savePending(
        const WizardChoices(
          exchangeAccess: false,
          touched: {WizardField.exchangeAccess},
        ),
      );
      await ClearPendingExchangeChoiceUsecase(repository).execute();
      expect(await repository.readPending(), isNull);
    },
  );
}
