import 'package:bull_ui/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/bank_account_cop_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/nequi_cop_form.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_event.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_state.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/bull_exchange.dart' show ExchangeLocalizations;
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecipientsBloc extends MockBloc<RecipientsEvent, RecipientsState>
    implements RecipientsBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const RecipientsEvent.refreshed()));

  Future<(_MockRecipientsBloc, ExchangeLocalizations)> pumpForm(
    WidgetTester tester,
    Widget form, {
    ExchangeFailure? failedToAddRecipient,
  }) async {
    final bloc = _MockRecipientsBloc();
    whenListen(
      bloc,
      const Stream<RecipientsState>.empty(),
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(),
        save: failedToAddRecipient == null
            ? const SaveIdle()
            : SaveFailed(failedToAddRecipient),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        localizationsDelegates: ExchangeLocalizations.localizationsDelegates,
        supportedLocales: ExchangeLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<RecipientsBloc>.value(value: bloc, child: form),
          ),
        ),
      ),
    );
    return (
      bloc,
      ExchangeLocalizations.of(tester.element(find.byWidget(form))),
    );
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextFormField),
  );

  Future<void> submit(WidgetTester tester, ExchangeLocalizations loc) async {
    await tester.ensureVisible(find.text(loc.recipientsContinue));
    await tester.tap(find.text(loc.recipientsContinue));
    await tester.pump();
  }

  for (final (name, form) in [
    ('PSE', const BankAccountCopForm()),
    ('Nequi', const NequiCopForm()),
  ]) {
    testWidgets('$name asks for first name, last name and email', (
      tester,
    ) async {
      final (_, loc) = await pumpForm(tester, form);

      expect(find.text(loc.recipientsFieldFirstName), findsOneWidget);
      expect(find.text(loc.recipientsFieldLastName), findsOneWidget);
      expect(find.text(loc.recipientsFieldEmailAddress), findsOneWidget);
      expect(find.text(loc.recipientsFieldCorporateName), findsNothing);

      await tester.tap(find.text(loc.recipientsFieldCorporateAccount));
      await tester.pump();

      expect(find.text(loc.recipientsFieldCorporateName), findsOneWidget);
      expect(find.text(loc.recipientsFieldLastName), findsNothing);
      expect(find.text(loc.recipientsFieldEmailAddress), findsOneWidget);
    });
  }

  testWidgets('Nequi without a last name is not sent', (tester) async {
    final (bloc, loc) = await pumpForm(tester, const NequiCopForm());

    await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
    await tester.enterText(find.byType(TextFormField).at(1), '99');
    await tester.enterText(field('copFirstName'), 'Ada');
    await tester.enterText(field('copEmail'), 'ada@example.com');
    await submit(tester, loc);

    verifyNever(() => bloc.add(any()));
    expect(find.text(loc.recipientsValidationFieldRequired), findsOneWidget);
  });

  testWidgets('Nequi with an email that is not an address is not sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const NequiCopForm());

    await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
    await tester.enterText(find.byType(TextFormField).at(1), '99');
    await tester.enterText(field('copFirstName'), 'Ada');
    await tester.enterText(field('copLastName'), 'Lovelace');
    await tester.enterText(field('copEmail'), 'ada');
    await submit(tester, loc);

    verifyNever(() => bloc.add(any()));
    expect(find.text(loc.recipientsValidationEmailInvalid), findsOneWidget);
  });

  testWidgets('a complete Nequi form builds a recipient the API accepts', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const NequiCopForm());

    await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
    await tester.enterText(find.byType(TextFormField).at(1), '99');
    await tester.enterText(field('copFirstName'), 'Ada');
    await tester.enterText(field('copLastName'), 'Lovelace');
    await tester.enterText(field('copEmail'), 'ada@example.com');
    await submit(tester, loc);

    final event =
        verify(() => bloc.add(captureAny())).captured.single as RecipientsAdded;
    final details = event.recipient.toDomain() as NequiColombiaDetails;
    final contact = details.payee as ColombiaContact;
    expect(contact.email, 'ada@example.com');
    expect(
      contact.holder,
      isA<ColombiaIndividual>()
          .having((h) => h.firstName, 'firstName', 'Ada')
          .having((h) => h.lastName, 'lastName', 'Lovelace'),
    );
    expect(details.phoneNumber, '3001234567');
  });

  testWidgets('a corporate Nequi form sends the corporate name', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const NequiCopForm());

    await tester.tap(find.text(loc.recipientsFieldCorporateAccount));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), '3001234567');
    await tester.enterText(find.byType(TextFormField).at(1), '900');
    await tester.enterText(field('copCorporateName'), 'ACME SAS');
    await tester.enterText(field('copEmail'), 'pay@acme.co');
    await submit(tester, loc);

    final event =
        verify(() => bloc.add(captureAny())).captured.single as RecipientsAdded;
    final details = event.recipient.toDomain() as NequiColombiaDetails;
    expect(
      (details.payee as ColombiaContact).holder,
      isA<ColombiaCorporate>().having(
        (h) => h.corporateName,
        'corporateName',
        'ACME SAS',
      ),
    );
  });

  testWidgets('the fields the exchange refused are marked under each field', (
    tester,
  ) async {
    final (_, loc) = await pumpForm(
      tester,
      const NequiCopForm(),
      failedToAddRecipient:
          ExchangeRecipientsInvalidFieldsFailure.fromFieldErrors(const {
            'email': 'ERR_VALIDATION_EMAIL',
            'lastname': 'ERR_VALIDATION_REQUIRED',
            'bankCode': 'ERR_VALIDATION_REQUIRED',
          }),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('copEmail')),
        matching: find.text(loc.recipientsErrorFieldRefused),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('copLastName')),
        matching: find.text(loc.recipientsValidationFieldRequired),
      ),
      findsOneWidget,
    );
    // Nequi has no bank code field, so the message under Continue names it.
    expect(
      find.text(loc.recipientsErrorFieldsRefused('bankCode')),
      findsOneWidget,
    );
  });
}
