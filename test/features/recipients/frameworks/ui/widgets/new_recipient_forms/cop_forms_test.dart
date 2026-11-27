import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/nequi_cop_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

Finder _field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextFormField),
);

void main() {
  setUpAll(
    () => registerFallbackValue(
      const RecipientsEvent.added(
        NequiColombiaFormDataModel(
          phoneNumber: '',
          documentType: '',
          documentId: '',
          holder: CopCorporateFormData(corporateName: ''),
          email: '',
        ),
      ),
    ),
  );

  Future<(_MockRecipientsBloc, AppLocalizations)> pumpForm(
    WidgetTester tester,
    Widget form,
  ) async {
    final bloc = _MockRecipientsBloc();
    whenListen(
      bloc,
      const Stream<RecipientsState>.empty(),
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<RecipientsBloc>.value(value: bloc, child: form),
          ),
        ),
      ),
    );
    return (bloc, AppLocalizations.of(tester.element(find.byWidget(form))));
  }

  Future<void> tapContinue(WidgetTester tester) async {
    final button = find.byType(RecipientFormContinueButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> fillNequiAccount(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '3001234567');
    await tester.enterText(fields.at(1), '1020304050');
  }

  testWidgets('a Nequi recipient for a person carries both names and email', (
    tester,
  ) async {
    final (bloc, _) = await pumpForm(tester, const NequiCopForm());

    await fillNequiAccount(tester);
    await tester.enterText(_field('copFirstName'), 'Ada');
    await tester.enterText(_field('copLastName'), 'Lovelace');
    await tester.enterText(_field('copEmail'), 'ada@example.co');
    await tapContinue(tester);

    final event =
        verify(() => bloc.add(captureAny())).captured.last as RecipientsAdded;
    final data = event.recipient as NequiColombiaFormDataModel;
    final holder = data.holder as CopIndividualFormData;
    expect(holder.firstName, 'Ada');
    expect(holder.lastName, 'Lovelace');
    expect(data.email, 'ada@example.co');
  });

  testWidgets('a company holder asks for the company name instead of names', (
    tester,
  ) async {
    final (bloc, _) = await pumpForm(tester, const NequiCopForm());

    await tester.tap(find.byKey(const ValueKey('copIsCorporate')));
    await tester.pump();
    expect(_field('copFirstName'), findsNothing);
    expect(_field('copLastName'), findsNothing);

    await fillNequiAccount(tester);
    await tester.enterText(_field('copCorporateName'), 'ACME SAS');
    await tester.enterText(_field('copEmail'), 'pay@acme.co');
    await tapContinue(tester);

    final event =
        verify(() => bloc.add(captureAny())).captured.last as RecipientsAdded;
    final data = event.recipient as NequiColombiaFormDataModel;
    expect((data.holder as CopCorporateFormData).corporateName, 'ACME SAS');
  });

  testWidgets('a malformed email is marked and nothing is sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const NequiCopForm());

    await fillNequiAccount(tester);
    await tester.enterText(_field('copFirstName'), 'Ada');
    await tester.enterText(_field('copLastName'), 'Lovelace');
    await tester.enterText(_field('copEmail'), 'ada@example');
    await tapContinue(tester);

    expect(find.text(loc.recipientsValidationEmailInvalid), findsOneWidget);
    verifyNever(() => bloc.add(any(that: isA<RecipientsAdded>())));
  });
}
