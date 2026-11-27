import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/spei_clabe_mxn_form.dart';
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

void main() {
  setUpAll(
    () => registerFallbackValue(
      const RecipientsEvent.added(
        SpeiClabeMxnFormDataModel(clabe: '', name: ''),
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

  testWidgets('a CLABE with a wrong check digit is marked and not sent', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, const SpeiClabeMxnForm());

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '032180000118359718');
    await tester.enterText(fields.at(1), 'Ada Lovelace');
    await tapContinue(tester);

    expect(find.text(loc.recipientsValidationClabeCheckDigit), findsOneWidget);
    verifyNever(() => bloc.add(any(that: isA<RecipientsAdded>())));
  });
}
