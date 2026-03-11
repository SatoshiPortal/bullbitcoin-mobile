import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recipients/application/usecases/add_recipient_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/check_sinpe_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/get_recipients_usecase.dart';
import 'package:bb_mobile/features/recipients/application/usecases/list_cad_billers_usecase.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/recipient_filter_criteria.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipients_event.dart';
part 'recipients_state.dart';
part 'recipients_bloc.freezed.dart';

class RecipientsBloc extends Bloc<RecipientsEvent, RecipientsState> {
  RecipientsBloc({
    RecipientFilterCriteria? allowedRecipientFilters,
    Future<void>? Function(RecipientViewModel recipient, {required bool isNew})?
    onRecipientSelectedHook,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
    required AddRecipientUsecase addRecipientUsecase,
    required GetRecipientsUsecase getRecipientsUsecase,
    required CheckSinpeUsecase checkSinpeUsecase,
    required ListCadBillersUsecase listCadBillersUsecase,
  }) : _onRecipientSelectedHook = onRecipientSelectedHook,
       _addRecipientUsecase = addRecipientUsecase,
       _getRecipientsUsecase = getRecipientsUsecase,
       _checkSinpeUsecase = checkSinpeUsecase,
       _listCadBillersUsecase = listCadBillersUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       super(
         RecipientsState(
           allowedRecipientFilters:
               allowedRecipientFilters ?? const RecipientFilterCriteria(),
         ),
       ) {
    on<RecipientsStarted>(_onStarted);
    on<RecipientsMoreLoaded>(_onMoreLoaded);
    on<RecipientsAdded>(_onAdded);
    on<RecipientsSinpeChecked>(_onSinpeChecked);
    on<RecipientsCadBillersSearched>(_onCadBillersSearched);
    on<RecipientsSelected>(_onSelected);
  }

  static const pageSize = 50;
  final Future<void>? Function(
    RecipientViewModel recipient, {
    required bool isNew,
  })?
  _onRecipientSelectedHook;
  final AddRecipientUsecase _addRecipientUsecase;
  final GetRecipientsUsecase _getRecipientsUsecase;
  final CheckSinpeUsecase _checkSinpeUsecase;
  final ListCadBillersUsecase _listCadBillersUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  Future<void> _onStarted(
    RecipientsStarted event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingRecipients: true,
        recipients: null,
        failedToLoadRecipients: null,
      ),
    );
    try {
      log.info('Loading first recipients');
      final result = await _getRecipientsUsecase.execute(
        GetRecipientsParams(pageSize: pageSize),
      );
      log.fine(
        'Loaded first ${result.recipients.length} recipients of ${result.totalRecipients} total',
      );
      emit(
        state.copyWith(
          totalRecipients: result.totalRecipients,
          recipients: result.recipients
              .map((recipient) {
                // Wrap each transformation in try/catch so a single malformed element
                // doesn't fail the entire list. Nulls are filtered out with the
                // whereType.
                try {
                  return RecipientViewModel.fromDto(recipient);
                } catch (err, stackTrace) {
                  log.severe(
                    message: 'Error transforming recipient to view model',
                    error: err,
                    trace: stackTrace,
                  );
                  return null;
                }
              })
              .whereType<RecipientViewModel>()
              .toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToLoadRecipients: Exception('Failed to load recipients: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isLoadingRecipients: false));
    }

    String preferredJurisdictionCode = 'CA'; // Default to Canada
    try {
      log.info('Loading exchange user summary');
      final summary = await _getExchangeUserSummaryUsecase.execute();
      log.fine('Loaded exchange user summary: $summary');
      final preferredCurrency = summary.currency;

      // Set default jurisdiction based on user summary
      switch (preferredCurrency) {
        case 'EUR':
          preferredJurisdictionCode = 'EU';
        case 'MXN':
          preferredJurisdictionCode = 'MX';
        case 'CRC':
          preferredJurisdictionCode = 'CR';
        case 'ARS':
          preferredJurisdictionCode = 'AR';
        case 'COP':
          preferredJurisdictionCode = 'CO';
        //case 'USD':
        //  preferredJurisdictionCode = 'US';
        default:
          preferredJurisdictionCode = 'CA';
      }
    } catch (e) {
      log.severe(
        message: 'Failed to load exchange user summary',
        error: e,
        trace: StackTrace.current,
      );
      // We don't emit an error state here since we have a default value
    } finally {
      emit(state.copyWith(preferredJurisdiction: preferredJurisdictionCode));
    }
  }

  Future<void> _onMoreLoaded(
    RecipientsMoreLoaded event,
    Emitter<RecipientsState> emit,
  ) async {
    if (state.isLoadingRecipients || !state.hasMoreRecipientsToLoad) {
      return;
    }

    emit(
      state.copyWith(isLoadingRecipients: true, failedToLoadRecipients: null),
    );
    try {
      log.info('Loading more recipients');
      final result = await _getRecipientsUsecase.execute(
        GetRecipientsParams(
          page: (state.recipients!.length ~/ pageSize) + 1,
          pageSize: pageSize,
        ),
      );
      log.fine(
        'Loaded additional ${result.recipients.length} recipients, '
        'total loaded: ${state.recipients!.length + result.recipients.length} '
        'of ${result.totalRecipients} total',
      );
      emit(
        state.copyWith(
          totalRecipients: result.totalRecipients,
          recipients: [
            ...state.recipients!,
            ...result.recipients.map((recipient) {
              // Wrap each transformation in try/catch so a single malformed element
              // doesn't fail the entire list. Nulls are filtered out with the
              // whereType.
              try {
                return RecipientViewModel.fromDto(recipient);
              } catch (err, stackTrace) {
                log.severe(
                  message: 'Error transforming recipient to view model',
                  error: err,
                  trace: stackTrace,
                );
                return null;
              }
            }).whereType<RecipientViewModel>(),
          ],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToLoadRecipients: Exception(
            'Failed to load more recipients: $e',
          ),
        ),
      );
    } finally {
      emit(state.copyWith(isLoadingRecipients: false));
    }
  }

  Future<void> _onAdded(
    RecipientsAdded event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(isAddingRecipient: true, failedToAddRecipient: null));
    try {
      log.info('Trying to add recipient: ${event.recipient}');
      final result = await _addRecipientUsecase.execute(
        AddRecipientParams(recipientDetails: event.recipient.toDto()),
      );
      log.fine(
        'Successfully added recipient with ID: ${result.recipient.recipientId}',
      );
      final addedRecipient = RecipientViewModel.fromDto(result.recipient);

      // Call the selection hook for the newly added recipient
      if (_onRecipientSelectedHook != null) {
        await _onRecipientSelectedHook(addedRecipient, isNew: true);
      }
    } catch (e) {
      emit(
        state.copyWith(
          failedToAddRecipient: Exception('Failed to add recipient: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isAddingRecipient: false));
    }
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
    try {
      log.info('Checking SINPE for phone number: ${event.phoneNumber}');
      final result = await _checkSinpeUsecase.execute(
        CheckSinpeParams(phoneNumber: event.phoneNumber),
      );
      log.fine('SINPE check result: $result');
      emit(state.copyWith(sinpeOwnerName: result.ownerName));
    } catch (e) {
      emit(
        state.copyWith(
          failedToCheckSinpe: Exception('Failed to check SINPE: $e'),
        ),
      );
    } finally {
      emit(state.copyWith(isCheckingSinpe: false));
    }
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
    try {
      log.info('Searching CAD billers with query: ${event.query}');
      final result = await _listCadBillersUsecase.execute(
        ListCadBillersParams(searchTerm: event.query),
      );
      log.fine('Found ${result.billers.length} CAD billers');
      emit(
        state.copyWith(
          cadBillers: result.billers
              .map((biller) {
                // Wrap each transformation in try/catch so a single malformed element
                // doesn't fail the entire list. Nulls are filtered out with the
                // whereType.
                try {
                  return CadBillerViewModel.fromDto(biller);
                } catch (err, stackTrace) {
                  log.severe(
                    message: 'Error transforming biller to view model',
                    error: err,
                    trace: stackTrace,
                  );
                  return null;
                }
              })
              .whereType<CadBillerViewModel>()
              .toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          failedToSearchCadBillers: Exception(
            'Failed to search CAD billers: $e',
          ),
        ),
      );
    } finally {
      emit(state.copyWith(isSearchingCadBillers: false));
    }
  }

  Future<void> _onSelected(
    RecipientsSelected event,
    Emitter<RecipientsState> emit,
  ) async {
    emit(state.copyWith(failedToSelectRecipient: null));
    try {
      log.info('Recipient selected: ${event.recipient}');
      if (_onRecipientSelectedHook != null) {
        await _onRecipientSelectedHook(event.recipient, isNew: false);
      }
    } catch (e) {
      log.severe(
        message: 'Error in recipient selection logging',
        error: e,
        trace: StackTrace.current,
      );
      emit(
        state.copyWith(
          failedToSelectRecipient: Exception(
            'Error when selecting recipient: $e',
          ),
        ),
      );
    }
  }
}
