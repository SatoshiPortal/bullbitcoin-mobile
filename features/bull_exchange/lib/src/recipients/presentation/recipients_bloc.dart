import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_effect.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_event.dart';
import 'package:bull_exchange/src/recipients/domain/recipients_state.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/add_recipient_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/check_sinpe_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_account_owner_name_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_confidential_sepa_availability_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/get_recipients_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/list_cad_billers_usecase.dart';
import 'package:bull_exchange/src/recipients/domain/usecases/run_recipient_selection_usecase.dart';
import 'package:bull_exchange/src/recipients/public/recipient_filter_criteria.dart';
import 'package:bull_exchange/src/recipients/public/recipient_view_model.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Shell of [RecipientsState.next]: runs the machine's effects and feeds
/// their answers back as events. [onRecipientSelectedHook] is the caller's
/// selection hook, run through [RunRecipientSelectionUsecase].
class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc({
    RecipientFilterCriteria? allowedRecipientFilters,
    Future<void>? Function(RecipientViewModel recipient, {required bool isNew})?
    onRecipientSelectedHook,
    required this._getPreferredJurisdictionUsecase,
    required this._getConfidentialSepaAvailabilityUsecase,
    required this._getAccountOwnerNameUsecase,
    required this._addRecipientUsecase,
    required this._getRecipientsUsecase,
    required this._checkSinpeUsecase,
    required this._listCadBillersUsecase,
  }) : _runSelection = RunRecipientSelectionUsecase(onRecipientSelectedHook),
       super(
         RecipientsState(
           allowedRecipientFilters:
               allowedRecipientFilters ?? RecipientFilterCriteria(),
         ),
       ) {
    on<RecipientsEvent>(_onEvent, transformer: sequential());
  }

  /// How long a typed search waits for the next keystroke.
  static const searchPause = Duration(milliseconds: 600);

  final AddRecipientUsecase _addRecipientUsecase;
  final GetRecipientsUsecase _getRecipientsUsecase;
  final CheckSinpeUsecase _checkSinpeUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;
  final GetPreferredJurisdictionUsecase _getPreferredJurisdictionUsecase;
  final GetConfidentialSepaAvailabilityUsecase
  _getConfidentialSepaAvailabilityUsecase;
  final GetAccountOwnerNameUsecase _getAccountOwnerNameUsecase;
  final RunRecipientSelectionUsecase _runSelection;

  void _onEvent(RecipientsEvent event, Emitter<RecipientsState> emit) {
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<RecipientsEffect> effects) {
    for (final effect in effects) {
      final Future<RecipientsEvent> answer = switch (effect) {
        RecipientsReadSepaAvailability() =>
          _getConfidentialSepaAvailabilityUsecase.execute().then(
            RecipientsSepaAvailabilityAnswered.new,
          ),
        RecipientsReadOwnerName() => _getAccountOwnerNameUsecase.execute().then(
          RecipientsOwnerNameAnswered.new,
        ),
        RecipientsReadPreferredJurisdiction() =>
          _getPreferredJurisdictionUsecase.execute().then(
            RecipientsPreferenceAnswered.new,
          ),
        RecipientsFetchPage(
          :final generation,
          :final page,
          :final types,
          :final isOwner,
          :final search,
        ) =>
          _fetch(generation, page, types, isOwner, search),
        RecipientsSearchPause(:final ticket, :final query) => Future.delayed(
          searchPause,
          () => RecipientsSearchSettled(ticket, query),
        ),
        RecipientsSave(:final recipient) => _save(recipient),
        RecipientsRunSelection(:final recipient, isNew: true) =>
          _runSelection
              .execute(recipient, isNew: true)
              .then(RecipientsSavedSelectionAnswered.new),
        RecipientsRunSelection(:final recipient, isNew: false) => _selected(
          recipient,
        ),
        // The phone number and the returned owner name are the user's
        // personal data, so neither is logged.
        RecipientsCheckSinpe(:final phoneNumber) => _logged(
          'Checking SINPE',
          _checkSinpeUsecase
              .execute(CheckSinpeParams(phoneNumber: phoneNumber))
              .then(RecipientsSinpeAnswered.new),
        ),
        RecipientsSearchBillers(:final query) => _logged(
          'Searching CAD billers',
          _listCadBillersUsecase
              .execute(ListCadBillersParams(searchTerm: query))
              .then(RecipientsBillersAnswered.new),
        ),
      };
      unawaited(
        answer.then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  Future<RecipientsEvent> _logged(
    String message,
    Future<RecipientsEvent> answer,
  ) {
    log.info(message);
    return answer;
  }

  Future<RecipientsEvent> _fetch(
    int generation,
    int page,
    List<RecipientType> types,
    bool? isOwner,
    String search,
  ) {
    log.info(
      page == 1
          ? 'Loading first page of recipients with current filters'
          : 'Loading more recipients',
    );
    return _getRecipientsUsecase
        .execute(
          GetRecipientsParams(
            page: page,
            pageSize: recipientsPageSize,
            recipientTypes: types,
            isOwner: isOwner,
            search: search,
          ),
        )
        .then((answer) => RecipientsPageAnswered(generation, answer));
  }

  Future<RecipientsEvent> _save(RecipientDetailsInput recipient) async {
    log.info('Adding a recipient');
    final saved = await _addRecipientUsecase.execute(
      AddRecipientParams(recipientDetails: recipient),
    );
    if (saved case Ok(:final value)) {
      log.fine(
        'Successfully added recipient with ID: '
        '${value.recipient.recipientId}',
      );
    }
    return RecipientsSaveAnswered(saved);
  }

  Future<RecipientsEvent> _selected(RecipientViewModel recipient) {
    // The recipient holds bank details, so only the fact of a selection is
    // logged.
    log.info('Recipient selected');
    return _runSelection
        .execute(recipient, isNew: false)
        .then(RecipientsSelectionAnswered.new);
  }
}
