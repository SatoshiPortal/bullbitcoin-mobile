import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recipients/application/dtos/recipient_dto.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_preferred_jurisdiction_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/recipients_failure.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipients_event.dart';
part 'recipients_state.dart';
part 'recipients_bloc.freezed.dart';

class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc({
    RecipientFilterCriteria? allowedRecipientFilters,
    this._onRecipientSelectedHook,
    required this._getPreferredJurisdictionUsecase,
    required this._addRecipientUsecase,
    required this._getRecipientsUsecase,
    required this._checkSinpeUsecase,
    required this._listCadBillersUsecase,
  }) : super(
         RecipientsState(
           allowedRecipientFilters:
               allowedRecipientFilters ?? const RecipientFilterCriteria(),
         ),
       ) {
    on<RecipientsStarted>(_onStarted);
    on<RecipientsMoreLoaded>(_onMoreLoaded);
    on<RecipientsRefreshed>(_onRefreshed, transformer: restartable());
    on<RecipientsJurisdictionChanged>(
      _onJurisdictionChanged,
      transformer: restartable(),
    );
    on<RecipientsSearchChanged>(_onSearchChanged, transformer: restartable());
    on<RecipientsAdded>(_onAdded);
    on<RecipientsSinpeChecked>(_onSinpeChecked);
    on<RecipientsCadBillersSearched>(_onCadBillersSearched);
    on<RecipientsSelected>(_onSelected);
  }

  static const pageSize = 50;
  // Monotonic token: a first-page load only commits its result if no newer
  // filter/refresh load has started meanwhile. Guards against out-of-order
  // responses racing across event types (e.g. jurisdiction vs search).
  int _loadGeneration = 0;
  final Future<void>? Function(
    RecipientViewModel recipient, {
    required bool isNew,
  })?
  _onRecipientSelectedHook;
  final AddRecipientUsecase _addRecipientUsecase;
  final GetRecipientsUsecase _getRecipientsUsecase;
  final CheckSinpeUsecase _checkSinpeUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;
  final GetPreferredJurisdictionUsecase _getPreferredJurisdictionUsecase;

  Future<void> _onStarted(
    RecipientsStarted event,
    Emitter<RecipientsState> emit,
  ) async {
    final jurisdictions = state.availableJurisdictions;
    if (jurisdictions.length == 1) {
      emit(state.copyWith(jurisdictionFilter: jurisdictions.first));
    }
    await _loadFirstPage(emit, clearList: true);

    // Not surfaced as a failure: a missing preference only changes which
    //  jurisdiction is offered first, and the default covers it. The reason
    //  is logged inside the use-case.
    final preferredJurisdictionCode =
        switch (await _getPreferredJurisdictionUsecase.execute()) {
          Ok(:final value) => value,
          Err() => GetPreferredJurisdictionUsecase.defaultJurisdiction,
        };
    emit(state.copyWith(preferredJurisdiction: preferredJurisdictionCode));
  }

  Future<void> _onMoreLoaded(
    RecipientsMoreLoaded event,
    Emitter<RecipientsState> emit,
  ) async {
    if (state.isLoadingRecipients || !state.hasMoreRecipientsToLoad) {
      return;
    }

    final generation = _loadGeneration;
    emit(
      state.copyWith(isLoadingRecipients: true, failedToLoadRecipients: null),
    );
    try {
      log.info('Loading more recipients');
      final outcome = await _getRecipientsUsecase.execute(
        GetRecipientsParams(
          page: state.loadedPages + 1,
          pageSize: pageSize,
          recipientTypes: _effectiveTypes(state),
          isOwner: state.allowedRecipientFilters.isOwner,
          search: state.searchQuery,
        ),
      );
      if (generation != _loadGeneration || emit.isDone) return;
      switch (outcome) {
        case Ok(:final value):
          log.fine(
            'Loaded additional ${value.recipients.length} recipients, '
            'total loaded: '
            '${state.recipients!.length + value.recipients.length} '
            'of ${value.totalRecipients} total',
          );
          emit(
            state.copyWith(
              totalRecipients: value.totalRecipients,
              loadedPages: state.loadedPages + 1,
              recipients: [
                ...state.recipients!,
                ..._toViewModels(value.recipients),
              ],
            ),
          );
        case Err(:final failure):
          emit(state.copyWith(failedToLoadRecipients: failure));
      }
    } finally {
      if (generation == _loadGeneration && !emit.isDone) {
        emit(state.copyWith(isLoadingRecipients: false));
      }
    }
  }

  Future<void> _onRefreshed(
    RecipientsRefreshed event,
    Emitter<RecipientsState> emit,
  ) async {
    await _loadFirstPage(emit, clearList: false);
  }

  Future<void> _onJurisdictionChanged(
    RecipientsJurisdictionChanged event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(jurisdictionFilter: event.jurisdiction));
    await _loadFirstPage(emit, clearList: true);
  }

  Future<void> _onSearchChanged(
    RecipientsSearchChanged event,
    Emitter<RecipientsState> emit,
  ) async {
    if (event.query.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
    }
    emit(state.copyWith(searchQuery: event.query));
    await _loadFirstPage(emit, clearList: true);
  }

  Future<void> _loadFirstPage(
    Emitter<RecipientsState> emit, {
    required bool clearList,
  }) async {
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        isLoadingRecipients: true,
        failedToLoadRecipients: null,
        recipients: clearList ? null : state.recipients,
      ),
    );
    try {
      log.info('Loading first page of recipients with current filters');
      final outcome = await _getRecipientsUsecase.execute(
        GetRecipientsParams(
          pageSize: pageSize,
          recipientTypes: _effectiveTypes(state),
          isOwner: state.allowedRecipientFilters.isOwner,
          search: state.searchQuery,
        ),
      );
      if (generation != _loadGeneration || emit.isDone) return;
      switch (outcome) {
        case Ok(:final value):
          emit(
            state.copyWith(
              totalRecipients: value.totalRecipients,
              loadedPages: 1,
              recipients: _toViewModels(value.recipients),
            ),
          );
        case Err(:final failure):
          emit(state.copyWith(failedToLoadRecipients: failure));
      }
    } finally {
      if (generation == _loadGeneration && !emit.isDone) {
        emit(state.copyWith(isLoadingRecipients: false));
      }
    }
  }

  /// Runs the caller-supplied selection hook, or null when it succeeded.
  ///
  /// The one place this bloc catches. The hook is a callback owned by
  /// whichever feature opened the recipients screen (`pay`, `withdraw`), so
  /// it sits outside this feature's Result contract and can throw. Catching
  /// it here — at the boundary with that foreign code, in one place rather
  /// than at each call site — keeps the two handlers free of error handling.
  ///
  /// Making the hook return a Result instead would remove this catch, but the
  /// signature belongs to the calling features and changing it is their PR.
  Future<RecipientsFailure?> _runSelectionHook(
    RecipientViewModel recipient, {
    required bool isNew,
  }) async {
    final hook = _onRecipientSelectedHook;
    if (hook == null) return null;
    try {
      await hook(recipient, isNew: isNew);
      return null;
    } on Object catch (e, st) {
      log.warning('Recipient selection hook failed', error: e, trace: st);
      return const RecipientsSelectionFailure();
    }
  }

  List<RecipientType> _effectiveTypes(RecipientsState state) {
    final allowed = state.allowedRecipientFilters.types;
    final jurisdiction = state.jurisdictionFilter;
    if (jurisdiction == null) return allowed;
    return allowed
        .where((type) => type.jurisdictionCode == jurisdiction)
        .toList();
  }

  // No try/catch: RecipientViewModel.fromDto copies nullable fields off a
  //  plain DTO and cannot throw. Tolerance for rows this build cannot read
  //  belongs at the boundary, and already lives in the gateway, which skips
  //  elements that fail to parse from JSON.
  List<RecipientViewModel> _toViewModels(List<RecipientDto> dtos) =>
      dtos.map(RecipientViewModel.fromDto).toList();

  Future<void> _onAdded(
    RecipientsAdded event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(isAddingRecipient: true, failedToAddRecipient: null));
    log.info('Adding a recipient');
    switch (await _addRecipientUsecase.execute(
      AddRecipientParams(recipientDetails: event.recipient.toDto()),
    )) {
      case Ok(:final value):
        log.fine(
          'Successfully added recipient with ID: '
          '${value.recipient.recipientId}',
        );
        final hookFailure = await _runSelectionHook(
          RecipientViewModel.fromDto(value.recipient),
          isNew: true,
        );
        if (hookFailure != null) {
          // The recipient IS saved; only the onward step failed. Reported as
          //  its own failure so the message does not read as "save failed"
          //  under a Continue button the user would then press again.
          emit(
            state.copyWith(
              failedToAddRecipient:
                  const RecipientsSavedButNotSelectedFailure(),
            ),
          );
        }
      case Err(:final failure):
        emit(state.copyWith(failedToAddRecipient: failure));
    }
    emit(state.copyWith(isAddingRecipient: false));
  }

  Future<void> _onSinpeChecked(
    RecipientsSinpeChecked event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isCheckingSinpe: true,
        sinpeOwnerName: '',
        failedToCheckSinpe: null,
      ),
    );
    // The phone number and the returned owner name are the user's personal
    // data, so neither is logged.
    log.info('Checking SINPE');
    switch (await _checkSinpeUsecase.execute(
      CheckSinpeParams(phoneNumber: event.phoneNumber),
    )) {
      case Ok(:final value):
        emit(state.copyWith(sinpeOwnerName: value.ownerName));
      case Err(:final failure):
        emit(state.copyWith(failedToCheckSinpe: failure));
    }
    emit(state.copyWith(isCheckingSinpe: false));
  }

  Future<void> _onCadBillersSearched(
    RecipientsCadBillersSearched event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isSearchingCadBillers: true,
        cadBillers: null,
        failedToSearchCadBillers: null,
      ),
    );
    log.info('Searching CAD billers');
    final outcome = await _listCadBillersUsecase.execute(
      ListCadBillersParams(searchTerm: event.query),
    );
    switch (outcome) {
      case Ok(:final value):
        log.fine('Found ${value.billers.length} CAD billers');
        emit(
          state.copyWith(
            cadBillers: value.billers.map(CadBillerViewModel.fromDto).toList(),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failedToSearchCadBillers: failure));
    }
    emit(state.copyWith(isSearchingCadBillers: false));
  }

  Future<void> _onSelected(
    RecipientsSelected event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(failedToSelectRecipient: null));
    // The recipient holds bank details, so only the fact of a selection is
    // logged.
    log.info('Recipient selected');
    final hookFailure = await _runSelectionHook(event.recipient, isNew: false);
    if (hookFailure != null) {
      emit(state.copyWith(failedToSelectRecipient: hookFailure));
    }
  }
}
