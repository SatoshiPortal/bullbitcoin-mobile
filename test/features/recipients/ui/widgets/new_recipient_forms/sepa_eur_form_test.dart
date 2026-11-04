import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/domain/entities/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient_type.dart';
import 'package:bb_mobile/features/recipients/ui/widgets/new_recipient_forms/sepa_eur_form.dart';
import 'package:bb_mobile/features/recipients/presentation/recipients_bloc.dart';
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
        SepaEurFormDataModel(iban: '', isCorporate: false, isOwner: true),
      ),
    ),
  );

  Future<(_MockRecipientsBloc, AppLocalizations)> pumpForm(
    WidgetTester tester, {
    required bool isConfidential,
  }) async {
    final bloc = _MockRecipientsBloc();
    whenListen(
      bloc,
      const Stream<RecipientsState>.empty(),
      initialState: RecipientsState(
        allowedRecipientFilters: RecipientFilterCriteria(),
        accountOwnerName: const AccountOwnerName(
          firstName: 'Mary Ann',
          lastName: 'Smith',
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BlocProvider<RecipientsBloc>.value(
              value: bloc,
              child: SepaEurForm(isConfidential: isConfidential),
            ),
          ),
        ),
      ),
    );
    return (
      bloc,
      AppLocalizations.of(tester.element(find.byType(SepaEurForm))),
    );
  }

  testWidgets('a Confidential SEPA recipient carries the account owner name', (
    tester,
  ) async {
    final (bloc, loc) = await pumpForm(tester, isConfidential: true);

    expect(find.text('Mary Ann Smith'), findsOneWidget);
    expect(find.text(loc.recipientsFieldFirstName), findsNothing);
    expect(find.text(loc.recipientsFieldLastName), findsNothing);
    expect(
      find.text(loc.recipientsConfidentialSepaNameMustMatchHint),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'FR7630006000011234567890189',
    );
    await tester.showKeyboard(find.byType(TextFormField).last);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final event =
        verify(() => bloc.add(captureAny())).captured.last as RecipientsAdded;
    final data = event.recipient as SepaEurFormDataModel;
    expect(data.type, RecipientType.confidentialSepaEur);
    expect(data.isOwner, isTrue);
    expect(data.firstname, 'Mary Ann');
    expect(data.lastname, 'Smith');
  });

  testWidgets('a regular SEPA recipient still asks for the name', (
    tester,
  ) async {
    final (_, loc) = await pumpForm(tester, isConfidential: false);

    expect(find.text(loc.recipientsFieldFirstName), findsOneWidget);
    expect(find.text(loc.recipientsFieldLastName), findsOneWidget);
    expect(find.text('Mary Ann Smith'), findsNothing);
  });
}
