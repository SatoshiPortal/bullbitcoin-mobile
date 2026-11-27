import 'package:bull_ui/testing.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_card_mxn_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_clabe_mxn_form.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/new_recipient_forms/spei_sms_mxn_form.dart';
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

  Future<void> submit(WidgetTester tester, ExchangeLocalizations loc) async {
    await tester.ensureVisible(find.text(loc.recipientsContinue));
    await tester.tap(find.text(loc.recipientsContinue));
    await tester.pump();
  }

  Finder input(int index) => find.byType(TextFormField).at(index);

  testWidgets('a CLABE with a wrong check digit is shown and not sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiClabeMxnForm());

    await tester.enterText(input(0), '002010077777777772');
    await tester.enterText(input(1), 'Ada');
    await submit(tester, loc);

    expect(find.text(loc.recipientsValidationClabeCheckDigit), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('a short CLABE is shown and not sent', (tester) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiClabeMxnForm());

    await tester.enterText(input(0), '0020100777');
    await tester.enterText(input(1), 'Ada');
    await submit(tester, loc);

    expect(find.text(loc.recipientsValidationClabeLength), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('a valid CLABE is sent', (tester) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiClabeMxnForm());

    await tester.enterText(input(0), '002010077777777771');
    await tester.enterText(input(1), 'Ada');
    await submit(tester, loc);

    final event =
        verify(() => bloc.add(captureAny())).captured.single as RecipientsAdded;
    expect(event.recipient.clabe, '002010077777777771');
  });

  testWidgets('an SMS phone that is not 10 digits is shown and not sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiSmsMxnForm());

    await tester.enterText(input(0), '40002');
    await tester.enterText(input(1), '+525512345678');
    await tester.enterText(input(2), 'Ada');
    await submit(tester, loc);

    expect(find.text(loc.recipientsValidationSpeiPhone), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('a card number that is not 16 digits is shown and not sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiCardMxnForm());

    await tester.enterText(input(0), '40002');
    await tester.enterText(input(1), '4111 1111 1111 1111');
    await tester.enterText(input(2), 'Ada');
    await submit(tester, loc);

    expect(find.text(loc.recipientsValidationDebitCard), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });
}
