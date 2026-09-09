import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_details_dto.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetRecipients extends Mock implements GetRecipientsUsecase {}

class _MockAddRecipient extends Mock implements AddRecipientUsecase {}

class _MockCheckSinpe extends Mock implements CheckSinpeUsecase {}

class _MockListCadBillers extends Mock implements ListCadBillersUsecase {}

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

RecipientDto _dto() => RecipientDto(
  recipientId: 'r1',
  userId: 'u1',
  userNbr: 1,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  details: const RecipientDetailsDto(
    recipientType: RecipientType.sinpeMovilCrc,
    phoneNumber: '8888-8888',
  ),
);

void main() {
  late _MockGetRecipients getRecipients;
  late _MockAddRecipient addRecipient;
  late _MockCheckSinpe checkSinpe;
  late _MockListCadBillers listCadBillers;
  late _MockGetPreferredJurisdiction getPreferredJurisdiction;

  setUp(() {
    getRecipients = _MockGetRecipients();
    addRecipient = _MockAddRecipient();
    checkSinpe = _MockCheckSinpe();
    listCadBillers = _MockListCadBillers();
    getPreferredJurisdiction = _MockGetPreferredJurisdiction();
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
  });

  RecipientsBloc buildBloc({
    Future<void>? Function(RecipientViewModel, {required bool isNew})? hook,
  }) => RecipientsBloc(
    onRecipientSelectedHook: hook,
    getPreferredJurisdictionUsecase: getPreferredJurisdiction,
    addRecipientUsecase: addRecipient,
    getRecipientsUsecase: getRecipients,
    checkSinpeUsecase: checkSinpe,
    listCadBillersUsecase: listCadBillers,
  );

  // The whole point of the migration: the failure the bloc holds is the typed
  // one the use-case returned, not an Exception rebuilt from its text.
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
      when(
        () => addRecipient.execute(any()),
      ).thenAnswer((_) async => Ok(AddRecipientResult(recipient: _dto())));
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
