import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/domain/update_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/bank_account_cop_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/bill_payment_cad_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/interac_email_cad_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/nequi_cop_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sinpe_iban_form.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/new_recipient_forms/sinpe_movil_crc_form.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetExchangeUserSummaryUsecase extends Mock
    implements GetExchangeUserSummaryUsecase {}

class _MockAddRecipientUsecase extends Mock implements AddRecipientUsecase {}

class _MockUpdateRecipientUsecase extends Mock
    implements UpdateRecipientUsecase {}

class _MockGetRecipientsUsecase extends Mock implements GetRecipientsUsecase {}

class _MockCheckSinpeUsecase extends Mock implements CheckSinpeUsecase {}

class _MockListCadBillersUsecase extends Mock
    implements ListCadBillersUsecase {}

class _FakeUpdateRecipientParams extends Fake
    implements UpdateRecipientParams {}

class _FakeGetRecipientsParams extends Fake implements GetRecipientsParams {}

void main() {
  late _MockUpdateRecipientUsecase updateRecipientUsecase;
  late _MockGetRecipientsUsecase getRecipientsUsecase;
  late _MockGetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase;
  late RecipientsBloc bloc;

  setUpAll(() {
    registerFallbackValue(_FakeUpdateRecipientParams());
    registerFallbackValue(_FakeGetRecipientsParams());
  });

  setUp(() {
    updateRecipientUsecase = _MockUpdateRecipientUsecase();
    getRecipientsUsecase = _MockGetRecipientsUsecase();
    getExchangeUserSummaryUsecase = _MockGetExchangeUserSummaryUsecase();
    when(() => getExchangeUserSummaryUsecase.execute()).thenAnswer(
      (_) async => const UserSummary(
        userNumber: 1,
        groups: [],
        profile: UserProfile(firstName: 'Test', lastName: 'User'),
        email: 'test@example.com',
        balances: [],
        currency: 'CAD',
        dca: UserDca(isActive: false),
        autoBuy: UserAutoBuy(
          isActive: false,
          addresses: UserAutoBuyAddresses(),
        ),
      ),
    );
    bloc = RecipientsBloc(
      getExchangeUserSummaryUsecase: getExchangeUserSummaryUsecase,
      addRecipientUsecase: _MockAddRecipientUsecase(),
      updateRecipientUsecase: updateRecipientUsecase,
      getRecipientsUsecase: getRecipientsUsecase,
      checkSinpeUsecase: _MockCheckSinpeUsecase(),
      listCadBillersUsecase: _MockListCadBillersUsecase(),
    );
    addTearDown(bloc.close);
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    RecipientViewModel? recipient,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: SingleChildScrollView(
              child: InteracEmailCadForm(recipient: recipient),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRecipientForm(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(body: SingleChildScrollView(child: form)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not request security details when creating a recipient', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Security Question'), findsNothing);
    expect(find.text('Security Answer'), findsNothing);
  });

  testWidgets('prefills and submits security details when editing', (
    tester,
  ) async {
    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
    );
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.interacEmailCad,
      email: 'person@example.com',
      name: 'Person',
      securityQuestion: 'Favourite city?',
      securityAnswer: 'Montreal',
      isOwner: false,
    );

    await pumpForm(tester, recipient: recipient);

    expect(find.text('Security Question'), findsOneWidget);
    expect(find.text('Security Answer'), findsOneWidget);
    expect(find.text('Favourite city?'), findsOneWidget);
    expect(find.text('Montreal'), findsOneWidget);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final params =
        verify(
              () => updateRecipientUsecase.execute(captureAny()),
            ).captured.single
            as UpdateRecipientParams;
    expect(params.recipientId, 'recipient-1');
    final details = params.recipientDetails as InteracEmailCadDetails;
    expect(details.securityQuestion, 'Favourite city?');
    expect(details.securityAnswer, 'Montreal');
  });

  testWidgets('shows an error instead of truncating long security details', (
    tester,
  ) async {
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.interacEmailCad,
      email: 'person@example.com',
      name: 'Person',
      isOwner: false,
    );
    await pumpForm(tester, recipient: recipient);

    final longQuestion = 'q' * 41;
    await tester.enterText(find.byType(TextFormField).at(2), longQuestion);
    await tester.enterText(find.byType(TextFormField).at(3), 'answer');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text(longQuestion), findsOneWidget);
    expect(
      find.text('Security question must be 3-40 characters'),
      findsWidgets,
    );
    verifyNever(() => updateRecipientUsecase.execute(any()));
  });

  testWidgets('keeps the biller read-only when editing bill payment', (
    tester,
  ) async {
    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
    );
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.billPaymentCad,
      payeeName: 'Hydro Quebec',
      payeeCode: 'HQ',
      payeeAccountNumber: '123456789',
      label: 'Power',
    );

    await pumpRecipientForm(
      tester,
      const BillPaymentCadForm(recipient: recipient),
    );

    expect(find.byType(Autocomplete<CadBillerViewModel>), findsNothing);
    final billerField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(billerField.enabled, isFalse);

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final params =
        verify(
              () => updateRecipientUsecase.execute(captureAny()),
            ).captured.single
            as UpdateRecipientParams;
    final details = params.recipientDetails as BillPaymentCadDetails;
    expect(details.payeeName, 'Hydro Quebec');
    expect(details.payeeCode, 'HQ');
  });

  testWidgets('allows an unchanged legacy SINPE recipient without owner name', (
    tester,
  ) async {
    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
    );
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.sinpeMovilCrc,
      phoneNumber: '88887777',
      isOwner: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: SinpeMovilCrcForm(recipient: recipient),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final params =
        verify(
              () => updateRecipientUsecase.execute(captureAny()),
            ).captured.single
            as UpdateRecipientParams;
    final details = params.recipientDetails as SinpeMovilCrcDetails;
    expect(details.phoneNumber, '88887777');
    expect(details.ownerName, isNull);
  });

  testWidgets('allows a legacy SINPE IBAN recipient without owner name', (
    tester,
  ) async {
    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
    );
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.sinpeIbanCrc,
      iban: 'CR05015202001026284066',
      isOwner: false,
    );

    await pumpRecipientForm(tester, const SinpeIbanForm(recipient: recipient));

    expect(find.text('Owner Name'), findsNothing);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final params =
        verify(
              () => updateRecipientUsecase.execute(captureAny()),
            ).captured.single
            as UpdateRecipientParams;
    final details = params.recipientDetails as SinpeIbanCrcDetails;
    expect(details.iban, 'CR05015202001026284066');
    expect(details.ownerName, isNull);
  });

  testWidgets(
    'preserves an existing Colombian bank code outside the local list',
    (tester) async {
      when(
        () => updateRecipientUsecase.execute(any()),
      ).thenAnswer((_) async => const Ok(null));
      when(() => getRecipientsUsecase.execute(any())).thenAnswer(
        (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
      );
      const recipient = RecipientViewModel(
        id: 'recipient-1',
        type: RecipientType.pseColombia,
        bankCode: '059',
        bankName: 'Bancolombia Ahorro a la Mano',
        accountType: 'S',
        bankAccount: '1234567890',
        documentType: 'CC',
        documentId: '123456789',
        name: 'Jane',
        lastname: 'Doe',
        email: 'jane@example.com',
        isCorporate: false,
      );

      await pumpRecipientForm(
        tester,
        const BankAccountCopForm(recipient: recipient),
      );

      expect(find.text('Bancolombia Ahorro a la Mano (059)'), findsOneWidget);
      expect(find.text('Doe'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final params =
          verify(
                () => updateRecipientUsecase.execute(captureAny()),
              ).captured.single
              as UpdateRecipientParams;
      final details = params.recipientDetails as PseColombiaDetails;
      expect(details.bankCode, '059');
      expect(details.lastname, 'Doe');
      expect(details.email, 'jane@example.com');
    },
  );

  testWidgets('allows a Colombian Nequi recipient to become corporate', (
    tester,
  ) async {
    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async => GetRecipientsResult(recipients: [], totalRecipients: 0),
    );
    const recipient = RecipientViewModel(
      id: 'recipient-1',
      type: RecipientType.nequiColombia,
      phoneNumber: '3001234567',
      documentType: 'CC',
      documentId: '123456789',
      name: 'Jane',
      lastname: 'Doe',
      email: 'jane@example.com',
      isCorporate: false,
    );

    await pumpRecipientForm(tester, const NequiCopForm(recipient: recipient));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('nequi-corporate-name')),
      'Acme Colombia',
    );
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final params =
        verify(
              () => updateRecipientUsecase.execute(captureAny()),
            ).captured.single
            as UpdateRecipientParams;
    final details = params.recipientDetails as NequiColombiaDetails;
    expect(details.isCorporate, isTrue);
    expect(details.name, isNull);
    expect(details.lastname, isNull);
    expect(details.corporateName, 'Acme Colombia');
    expect(details.email, 'jane@example.com');
  });

  test('clears a failed update before another edit', () async {
    when(() => updateRecipientUsecase.execute(any())).thenAnswer(
      (_) async => const Err(RecipientsInvalidFieldsFailure({'email'})),
    );
    bloc.add(
      RecipientsEvent.updated(
        recipientId: 'recipient-1',
        recipient: InteracEmailCadDetails.create(
          email: 'person@example.com',
          name: 'Person',
        ),
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.failedToUpdateRecipient != null,
    );

    bloc.add(const RecipientsEvent.updateFailureCleared());
    final cleared = await bloc.stream.firstWhere(
      (state) => state.failedToUpdateRecipient == null,
    );

    expect(cleared.failedToUpdateRecipient, isNull);
  });

  test('keeps the confirmed update when the following refresh fails', () async {
    final now = DateTime(2026);
    final original = RecipientDto(
      recipientId: 'recipient-1',
      userId: 'user-1',
      userNbr: 1,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      details: const RecipientDetailsDto(
        recipientType: RecipientType.interacEmailCad,
        email: 'person@example.com',
        name: 'Old name',
      ),
    );
    when(() => getRecipientsUsecase.execute(any())).thenAnswer(
      (_) async =>
          GetRecipientsResult(recipients: [original], totalRecipients: 1),
    );
    bloc.add(const RecipientsEvent.started());
    await bloc.stream.firstWhere((state) => state.recipients?.length == 1);

    when(
      () => updateRecipientUsecase.execute(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => getRecipientsUsecase.execute(any()),
    ).thenThrow(Exception('refresh failed'));

    final completed = bloc.stream.firstWhere(
      (state) =>
          !state.isUpdatingRecipient && state.failedToLoadRecipients != null,
    );
    bloc.add(
      RecipientsEvent.updated(
        recipientId: 'recipient-1',
        recipient: InteracEmailCadDetails.create(
          email: 'person@example.com',
          name: 'New name',
        ),
      ),
    );
    final state = await completed;

    expect(state.recipients!.single.name, 'New name');
  });
}
