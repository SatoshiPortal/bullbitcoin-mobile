import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/account_owner_name.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/confidential_sepa_availability.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/presentation/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/public/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/public/recipient_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetRecipients extends Mock implements GetRecipientsUsecase {}

class _MockAddRecipient extends Mock implements AddRecipientUsecase {}

class _MockCheckSinpe extends Mock implements CheckSinpeUsecase {}

class _MockListCadBillers extends Mock implements ListCadBillersUsecase {}

class _MockGetConfidentialSepaAvailability extends Mock
    implements GetConfidentialSepaAvailabilityUsecase {}

class _MockGetAccountOwnerName extends Mock
    implements GetAccountOwnerNameUsecase {}

class _MockGetPreferredJurisdiction extends Mock
    implements GetPreferredJurisdictionUsecase {}

const _recipient = RecipientViewModel(
  id: 'r1',
  type: RecipientType.sinpeMovilCrc,
  phoneNumber: '8888-8888',
);

RecipientFormDataModel _formData() => const SinpeMovilCrcFormDataModel(
  phoneNumber: '8888-8888',
  ownerName: 'Sat Oshi',
);

Recipient _recipientEntity() => Recipient.create(
  recipientId: 'r1',
  userId: 'u1',
  userNbr: 1,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  details: const RecipientDetailsDto(
    recipientType: RecipientType.sinpeMovilCrc,
    phoneNumber: '8888-8888',
  ).toDomain(),
);

void main() {
  late _MockGetRecipients getRecipients;
  late _MockAddRecipient addRecipient;
  late _MockCheckSinpe checkSinpe;
  late _MockListCadBillers listCadBillers;
  late _MockGetPreferredJurisdiction getPreferredJurisdiction;
  late _MockGetConfidentialSepaAvailability getConfidentialSepaAvailability;
  late _MockGetAccountOwnerName getAccountOwnerName;

  setUp(() {
    getRecipients = _MockGetRecipients();
    addRecipient = _MockAddRecipient();
    checkSinpe = _MockCheckSinpe();
    listCadBillers = _MockListCadBillers();
    getPreferredJurisdiction = _MockGetPreferredJurisdiction();
    getConfidentialSepaAvailability = _MockGetConfidentialSepaAvailability();
    getAccountOwnerName = _MockGetAccountOwnerName();
    registerFallbackValue(GetRecipientsParams());
    registerFallbackValue(
      AddRecipientParams(recipientDetails: _formData().toDto()),
    );
    registerFallbackValue(CheckSinpeParams(phoneNumber: '8888-8888'));
    registerFallbackValue(ListCadBillersParams(searchTerm: 'hydro'));

    when(() => getPreferredJurisdiction.execute()).thenAnswer(
      (_) async =>
          const Ok(GetPreferredJurisdictionUsecase.defaultJurisdiction),
    );
    when(
      () => getRecipients.execute(any()),
    ).thenAnswer((_) async => const Err(RecipientsLoadFailure()));
    when(() => getAccountOwnerName.execute()).thenAnswer(
      (_) async =>
          const Ok(AccountOwnerName(firstName: 'Mary Ann', lastName: 'Smith')),
    );
  });

  RecipientsBloc buildBloc({
    Future<void>? Function(RecipientViewModel, {required bool isNew})? hook,
    RecipientFilterCriteria? filters,
  }) => RecipientsBloc(
    allowedRecipientFilters: filters,
    onRecipientSelectedHook: hook,
    getPreferredJurisdictionUsecase: getPreferredJurisdiction,
    getConfidentialSepaAvailabilityUsecase: getConfidentialSepaAvailability,
    getAccountOwnerNameUsecase: getAccountOwnerName,
    addRecipientUsecase: addRecipient,
    getRecipientsUsecase: getRecipients,
    checkSinpeUsecase: checkSinpe,
    listCadBillersUsecase: listCadBillers,
  );

  // The whole point of the migration: the failure the bloc holds is the typed
  // one the use-case returned, not an Exception rebuilt from its text.
  group('Confidential SEPA', () {
    final sepaFilters = RecipientFilterCriteria(
      types: const [RecipientType.sepaEur, RecipientType.confidentialSepaEur],
    );

    Future<RecipientsBloc> startWith(
      ConfidentialSepaAvailability availability,
    ) async {
      when(
        () => getConfidentialSepaAvailability.execute(),
      ).thenAnswer((_) async => Ok(availability));
      final bloc = buildBloc(filters: sepaFilters);
      addTearDown(bloc.close);
      bloc.add(const RecipientsStarted());
      await pumpEventQueue();
      return bloc;
    }

    List<RecipientType>? requestedTypes() =>
        (verify(() => getRecipients.execute(captureAny())).captured.last
                as GetRecipientsParams)
            .recipientTypes;

    test('is hidden from a user who cannot use it', () async {
      final bloc = await startWith(ConfidentialSepaAvailability.unavailable);

      expect(bloc.state.selectableRecipientTypes, {RecipientType.sepaEur});
      expect(requestedTypes(), [RecipientType.sepaEur]);
    });

    test('is offered to an eligible user', () async {
      final bloc = await startWith(
        ConfidentialSepaAvailability.needsVirtualIban,
      );

      expect(
        bloc.state.selectableRecipientTypes,
        contains(RecipientType.confidentialSepaEur),
      );
    });

    test('loads the account owner name for an eligible user', () async {
      final bloc = await startWith(ConfidentialSepaAvailability.ready);

      expect(
        bloc.state.accountOwnerName,
        const AccountOwnerName(firstName: 'Mary Ann', lastName: 'Smith'),
      );
    });

    test('does not load the account owner name for a user who cannot use '
        'it', () async {
      await startWith(ConfidentialSepaAvailability.unavailable);

      verifyNever(() => getAccountOwnerName.execute());
    });

    test('is ready once the virtual IBAN is activated', () async {
      final bloc = await startWith(
        ConfidentialSepaAvailability.needsVirtualIban,
      );

      bloc.add(const RecipientsEvent.virtualIbanActivated());
      await pumpEventQueue();

      expect(
        bloc.state.confidentialSepaAvailability,
        ConfidentialSepaAvailability.ready,
      );
    });

    test('a list that offers both routes shows regular SEPA first', () async {
      final bloc = await startWith(ConfidentialSepaAvailability.ready);

      expect(bloc.state.canChooseSepaType, isTrue);
      expect(requestedTypes(), [RecipientType.sepaEur]);
    });

    test('choosing Confidential SEPA lists its recipients', () async {
      final bloc = await startWith(ConfidentialSepaAvailability.ready);

      bloc.add(
        const RecipientsEvent.sepaTypeChanged(
          RecipientType.confidentialSepaEur,
        ),
      );
      await pumpEventQueue();

      expect(requestedTypes(), [RecipientType.confidentialSepaEur]);
    });

    test('a user who cannot use it is not offered the choice', () async {
      final bloc = await startWith(ConfidentialSepaAvailability.unavailable);

      expect(bloc.state.canChooseSepaType, isFalse);
    });

    test('is not checked when the flow does not allow it', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const RecipientsStarted());
      await pumpEventQueue();

      verifyNever(() => getConfidentialSepaAvailability.execute());
    });
  });

  test('a load failure reaches state as the typed failure', () async {
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const RecipientsStarted());
    await pumpEventQueue();

    expect(bloc.state.failedToLoadRecipients, isA<RecipientsLoadFailure>());
    // Message-free by construction, so nothing can be rendered from it.
    expect(bloc.state.failedToLoadRecipients?.logMessage, isNull);
  });

  test('a connectivity failure survives as its own variant, so the UI can '
      'give advice the generic one cannot', () async {
    when(
      () => getRecipients.execute(any()),
    ).thenAnswer((_) async => const Err(RecipientsNetworkFailure()));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const RecipientsStarted());
    await pumpEventQueue();

    expect(bloc.state.failedToLoadRecipients, isA<RecipientsNetworkFailure>());
  });

  test('a save failure reaches state as the typed failure', () async {
    when(
      () => addRecipient.execute(any()),
    ).thenAnswer((_) async => const Err(RecipientsSaveFailure()));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(RecipientsAdded(_formData()));
    await pumpEventQueue();

    expect(bloc.state.failedToAddRecipient, isA<RecipientsSaveFailure>());
    expect(bloc.state.isAddingRecipient, isFalse);
  });

  // Both of these were set by the bloc but rendered by no widget, so their
  // localized messages were dead code. They are wired up now — the SINPE one
  // under the phone field, the biller one under the search field — and these
  // pin the state they read.
  test('a SINPE lookup failure reaches state', () async {
    when(
      () => checkSinpe.execute(any()),
    ).thenAnswer((_) async => const Err(RecipientsSinpeLookupFailure()));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const RecipientsSinpeChecked('88888888'));
    await pumpEventQueue();

    expect(bloc.state.failedToCheckSinpe, isA<RecipientsSinpeLookupFailure>());
    // The spinner must stop too, or the field looks like it is still working.
    expect(bloc.state.isCheckingSinpe, isFalse);
    expect(bloc.state.sinpeOwnerName, isEmpty);
  });

  test('a biller search failure reaches state', () async {
    when(
      () => listCadBillers.execute(any()),
    ).thenAnswer((_) async => const Err(RecipientsCadBillerSearchFailure()));
    final bloc = buildBloc();
    addTearDown(bloc.close);

    bloc.add(const RecipientsCadBillersSearched('hydro'));
    await pumpEventQueue();

    expect(
      bloc.state.failedToSearchCadBillers,
      isA<RecipientsCadBillerSearchFailure>(),
    );
    expect(bloc.state.isSearchingCadBillers, isFalse);
  });

  // _runSelectionHook is the only catch left in this bloc, and the code it
  // guards belongs to another feature.
  group('the caller-supplied hook is contained', () {
    test('a throwing hook becomes a typed failure instead of escaping the '
        'handler', () async {
      final bloc = buildBloc(
        hook: (_, {required isNew}) async =>
            throw Exception('withdraw blew up'),
      );
      addTearDown(bloc.close);

      bloc.add(const RecipientsSelected(_recipient));
      await pumpEventQueue();

      expect(
        bloc.state.failedToSelectRecipient,
        isA<RecipientsSelectionFailure>(),
      );
      // The other feature's reason is logged, never carried.
      expect(bloc.state.failedToSelectRecipient?.logMessage, isNull);
      expect(bloc.state.toString(), isNot(contains('withdraw blew up')));
    });

    test('a hook that throws AFTER a successful save reports the hook, not a '
        'save failure', () async {
      when(() => addRecipient.execute(any())).thenAnswer(
        (_) async => Ok(AddRecipientResult(recipient: _recipientEntity())),
      );
      final bloc = buildBloc(
        hook: (_, {required isNew}) async => throw Exception('boom'),
      );
      addTearDown(bloc.close);

      bloc.add(RecipientsAdded(_formData()));
      await pumpEventQueue();

      // Not RecipientsSaveFailure: the recipient IS saved, and a message
      // implying otherwise makes the user press Continue again.
      expect(
        bloc.state.failedToAddRecipient,
        isA<RecipientsSavedButNotSelectedFailure>(),
      );
      expect(bloc.state.isAddingRecipient, isFalse);
    });

    test('no hook is not a failure', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const RecipientsSelected(_recipient));
      await pumpEventQueue();

      expect(bloc.state.failedToSelectRecipient, isNull);
    });
  });
}
